import Foundation
import AVFoundation
import Observation

/// 聞き流し機能の再生単位（英単語 → 日本語訳の順で読み上げる1セット）
struct ListeningItem: Identifiable {
    let id: String // wordId をそのまま使う
    let word: String
    let meaning: String
}

/// `AVSpeechSynthesizer` のみで完結する聞き流しプレイヤー。
/// 外部音声ファイルを一切持たないため、単語データがどれだけ増えてもアプリ本体の容量は増えない。
///
/// バックグラウンド/画面オフでの連続再生には、Xcode側で以下の設定が別途必要:
///  - Signing & Capabilities → Background Modes → "Audio, AirPlay, and Picture in Picture" をON
///  - AVAudioSession のカテゴリを `.playback` にし、アプリ起動中に一度アクティブ化しておく
@Observable
@MainActor
final class AudioPlaybackManager: NSObject {
    enum PlaybackState {
        case stopped, playing, paused
    }

    private(set) var state: PlaybackState = .stopped
    private(set) var currentIndex: Int = 0
    private(set) var currentItem: ListeningItem?

    /// 単語→訳の間に挟む無音のポーズ（秒）。短すぎると聞き取りにくく、長すぎるとテンポが悪くなる
    var pauseBetweenWordAndMeaning: TimeInterval = 0.4
    /// 1語読み終えてから次の語に移るまでのポーズ（秒）
    var pauseBetweenWords: TimeInterval = 0.8
    /// 読み上げ速度。AVSpeechUtteranceDefaultSpeechRate を基準に調整
    var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate

    private let synthesizer = AVSpeechSynthesizer()
    private var playlist: [ListeningItem] = []
    /// synthesizer は1つのUtteranceずつしか話せないため、キューを自前で管理し
    /// didFinish のたびに「次の1文（英語 or 日本語）」を発話させて連続再生を実現する
    private enum QueuedUtterance {
        case word(ListeningItem)
        case meaning(ListeningItem)
    }
    private var utteranceQueue: [QueuedUtterance] = []

    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // .playback にすることでサイレントスイッチON・画面ロック中でも再生を継続できる
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true)
        } catch {
            print("AudioSessionの設定に失敗: \(error)")
        }
    }

    func play(items: [ListeningItem], startAt index: Int = 0) {
        guard !items.isEmpty else { return }
        playlist = items
        currentIndex = min(index, items.count - 1)
        rebuildQueue(from: currentIndex)
        state = .playing
        speakNext()
    }

    func pause() {
        guard state == .playing else { return }
        synthesizer.pauseSpeaking(at: .word)
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        synthesizer.continueSpeaking()
        state = .playing
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        utteranceQueue.removeAll()
        state = .stopped
        currentItem = nil
    }

    func skipToNext() {
        guard currentIndex + 1 < playlist.count else {
            stop()
            return
        }
        currentIndex += 1
        synthesizer.stopSpeaking(at: .immediate)
        rebuildQueue(from: currentIndex)
        state = .playing
        speakNext()
    }

    private func rebuildQueue(from index: Int) {
        utteranceQueue = playlist[index...].flatMap { item in
            [QueuedUtterance.word(item), .meaning(item)]
        }
    }

    private func speakNext() {
        guard state == .playing, let next = utteranceQueue.first else {
            if utteranceQueue.isEmpty { stop() }
            return
        }
        utteranceQueue.removeFirst()

        switch next {
        case .word(let item):
            currentItem = item
            speak(text: item.word, languageCode: "en-US", postDelay: pauseBetweenWordAndMeaning)
        case .meaning(let item):
            speak(text: item.meaning, languageCode: "ja-JP", postDelay: pauseBetweenWords)
            if let idx = playlist.firstIndex(where: { $0.id == item.id }) {
                currentIndex = idx
            }
        }
    }

    private var pendingPostDelay: TimeInterval = 0

    private func speak(text: String, languageCode: String, postDelay: TimeInterval) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        utterance.rate = speechRate
        pendingPostDelay = postDelay
        synthesizer.speak(utterance)
    }
}

extension AudioPlaybackManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard state == .playing else { return }
            let delay = pendingPostDelay
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard state == .playing else { return }
            speakNext()
        }
    }

    @objc nonisolated private func handleInterruption(_ notification: Notification) {
        Task { @MainActor in
            guard
                let info = notification.userInfo,
                let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                let type = AVAudioSession.InterruptionType(rawValue: typeValue)
            else { return }

            switch type {
            case .began:
                pause()
            case .ended:
                if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt,
                   AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
                    resume()
                }
            @unknown default:
                break
            }
        }
    }
}
