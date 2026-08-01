import Foundation
import AVFoundation
import MediaPlayer
import Observation
import os

/// 聞き流し機能の再生単位（英単語 → 日本語訳の順で読み上げる1セット）
struct ListeningItem: Identifiable {
    let id: String // wordId をそのまま使う
    let word: String
    let meaning: String
}

/// `AVSpeechSynthesizer` のみで完結する聞き流しプレイヤー。
/// 外部音声ファイルを一切持たないため、単語データがどれだけ増えてもアプリ本体の容量は増えない。
///
/// バックグラウンド/画面オフでの連続再生には Info.plist の `UIBackgroundModes: audio` が必要（設定済み）。
///
/// - Important: 画面ごとにインスタンスを作るとオーディオセッションの奪い合いになるため、
///   アプリ全体で `AudioPlaybackManager.shared` を共有する。
@Observable
@MainActor
final class AudioPlaybackManager: NSObject {
    static let shared = AudioPlaybackManager()

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
    /// 読み上げ速度の倍率。1.0が標準の聞き取りやすさ。
    /// `AVSpeechUtteranceDefaultSpeechRate` を1.0とみなして換算する。
    var speedMultiplier: Double = 1.0

    /// 実際に `AVSpeechUtterance.rate` へ渡す値。
    /// AVSpeechSynthesizerのrateは倍率ではなく0〜1の独自スケールで、
    /// 単純に掛けると上限を超えて頭打ちになるため、既定値を基準に上下へ配分する。
    private var speechRate: Float {
        let base = AVSpeechUtteranceDefaultSpeechRate
        if speedMultiplier >= 1 {
            let upperRange = AVSpeechUtteranceMaximumSpeechRate - base
            // 2.0倍で上限に届くよう線形に割り当てる
            let ratio = Float(min(speedMultiplier - 1, 1)) / 1.0
            return base + upperRange * ratio
        } else {
            let lowerRange = base - AVSpeechUtteranceMinimumSpeechRate
            let ratio = Float(1 - speedMultiplier) / 0.5
            return base - lowerRange * min(ratio, 1)
        }
    }

    private let logger = Logger(subsystem: "com.eitango.app", category: "AudioPlayback")
    private let synthesizer = AVSpeechSynthesizer()
    private var playlist: [ListeningItem] = []

    /// synthesizer は1つのUtteranceずつしか話せないため、キューを自前で管理し
    /// didFinish のたびに「次の1文（英語 or 日本語）」を発話させて連続再生を実現する
    private enum QueuedUtterance {
        case word(ListeningItem)
        case meaning(ListeningItem)
    }
    private var utteranceQueue: [QueuedUtterance] = []

    /// 発話と発話の間の無音待ち。一時停止したら破棄し、再開時に改めて張り直す
    private var pendingAdvanceTask: Task<Void, Never>?
    /// 次の発話までの待ち時間。一時停止をまたいで再開できるよう保持する
    private var pendingPostDelay: TimeInterval = 0
    /// ポーズ中に一時停止された場合、再開時は「待ちの続き」から再生を再開する必要がある
    private var isWaitingBetweenUtterances = false

    private var isSessionActive = false

    private override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
        registerRemoteCommands()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    // MARK: - オーディオセッション

    /// カテゴリ設定のみを行う。`setActive(true)` は実際に再生を始めるまで呼ばない。
    /// 起動時や画面表示時にアクティブ化すると、ユーザーが聴いていた音楽を
    /// 再生ボタンを押す前に止めてしまうため。
    private func configureAudioSession() {
        do {
            // .playback にすることでサイレントスイッチON・画面ロック中でも再生を継続できる
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [])
        } catch {
            logger.error("AudioSessionのカテゴリ設定に失敗: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func activateSessionIfNeeded() {
        guard !isSessionActive else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            isSessionActive = true
        } catch {
            logger.error("AudioSessionのアクティブ化に失敗: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 再生を終えたらセッションを手放し、他アプリの音楽が復帰できるようにする
    private func deactivateSession() {
        guard isSessionActive else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            isSessionActive = false
        } catch {
            logger.error("AudioSessionの解放に失敗: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - 再生制御

    func play(items: [ListeningItem], startAt index: Int = 0) {
        guard !items.isEmpty else { return }
        activateSessionIfNeeded()
        playlist = items
        currentIndex = min(max(index, 0), items.count - 1)
        rebuildQueue(from: currentIndex)
        state = .playing
        speakNext()
    }

    func pause() {
        guard state == .playing else { return }
        state = .paused
        // 発話中ならsynthesizer側を一時停止。発話と発話の合間（無音待ち）なら
        // 待機タスクを畳んでおき、再開時に張り直す。
        pendingAdvanceTask?.cancel()
        pendingAdvanceTask = nil
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .word)
        }
        updateNowPlayingInfo()
    }

    func resume() {
        guard state == .paused else { return }
        state = .playing
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        } else {
            // 無音待ちの最中に停止していた場合、再開すべき発話が残っていないので自分で次へ進める。
            // ここを忘れると「再生ボタンを押しても無音のまま止まる」状態になる。
            scheduleNextUtterance(after: isWaitingBetweenUtterances ? pendingPostDelay : 0)
        }
        updateNowPlayingInfo()
    }

    func stop() {
        pendingAdvanceTask?.cancel()
        pendingAdvanceTask = nil
        isWaitingBetweenUtterances = false
        synthesizer.stopSpeaking(at: .immediate)
        utteranceQueue.removeAll()
        state = .stopped
        currentItem = nil
        clearNowPlayingInfo()
        deactivateSession()
    }

    func skipToNext() {
        guard currentIndex + 1 < playlist.count else {
            stop()
            return
        }
        pendingAdvanceTask?.cancel()
        pendingAdvanceTask = nil
        isWaitingBetweenUtterances = false
        currentIndex += 1
        synthesizer.stopSpeaking(at: .immediate)
        rebuildQueue(from: currentIndex)
        state = .playing
        activateSessionIfNeeded()
        speakNext()
    }

    func skipToPrevious() {
        guard currentIndex > 0 else { return }
        pendingAdvanceTask?.cancel()
        pendingAdvanceTask = nil
        isWaitingBetweenUtterances = false
        currentIndex -= 1
        synthesizer.stopSpeaking(at: .immediate)
        rebuildQueue(from: currentIndex)
        state = .playing
        activateSessionIfNeeded()
        speakNext()
    }

    private func rebuildQueue(from index: Int) {
        utteranceQueue = playlist[index...].flatMap { item in
            [QueuedUtterance.word(item), .meaning(item)]
        }
    }

    private func speakNext() {
        isWaitingBetweenUtterances = false
        guard state == .playing else { return }
        guard let next = utteranceQueue.first else {
            stop()
            return
        }
        utteranceQueue.removeFirst()

        switch next {
        case .word(let item):
            currentItem = item
            if let index = playlist.firstIndex(where: { $0.id == item.id }) {
                currentIndex = index
            }
            updateNowPlayingInfo()
            speak(text: item.word, languageCode: "en-US", postDelay: pauseBetweenWordAndMeaning)
        case .meaning(let item):
            speak(text: item.meaning, languageCode: "ja-JP", postDelay: pauseBetweenWords)
        }
    }

    private func speak(text: String, languageCode: String, postDelay: TimeInterval) {
        let utterance = AVSpeechUtterance(string: text)
        // 指定言語の音声が端末に無い場合 voice は nil になり、既定の言語で読まれてしまう。
        // 少なくとも記録は残しておく（英単語が日本語読みされる等の切り分けのため）。
        if let voice = AVSpeechSynthesisVoice(language: languageCode) {
            utterance.voice = voice
        } else {
            logger.notice("音声が見つかりません: \(languageCode, privacy: .public)")
        }
        utterance.rate = speechRate
        pendingPostDelay = postDelay
        synthesizer.speak(utterance)
    }

    /// 指定秒だけ待ってから次の発話へ進む。待機中に一時停止されたら破棄される。
    private func scheduleNextUtterance(after delay: TimeInterval) {
        pendingAdvanceTask?.cancel()
        isWaitingBetweenUtterances = true
        pendingAdvanceTask = Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            guard let self, self.state == .playing else { return }
            self.speakNext()
        }
    }

    // MARK: - ロック画面 / コントロールセンター

    /// 画面を消したまま使う機能なので、ロック画面とコントロールセンターから
    /// 曲名の確認と再生操作ができるようにする（イヤホンのボタンもここ経由で効く）。
    private func registerRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            guard self.state == .paused else { return .commandFailed }
            self.resume()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            guard self.state == .playing else { return .commandFailed }
            self.pause()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            switch self.state {
            case .playing: self.pause()
            case .paused: self.resume()
            case .stopped: return .commandFailed
            }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            guard let self, self.state != .stopped else { return .commandFailed }
            self.skipToNext()
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            guard let self, self.state != .stopped else { return .commandFailed }
            self.skipToPrevious()
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let item = currentItem else {
            clearNowPlayingInfo()
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: item.word,
            MPMediaItemPropertyArtist: item.meaning,
            MPMediaItemPropertyAlbumTitle: "英検2級 英単語特訓",
            MPNowPlayingInfoPropertyPlaybackRate: state == .playing ? 1.0 : 0.0
        ]
        if !playlist.isEmpty {
            info[MPNowPlayingInfoPropertyPlaybackQueueIndex] = currentIndex
            info[MPNowPlayingInfoPropertyPlaybackQueueCount] = playlist.count
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}

extension AudioPlaybackManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, self.state == .playing else { return }
            self.scheduleNextUtterance(after: self.pendingPostDelay)
        }
    }

    @objc nonisolated private func handleInterruption(_ notification: Notification) {
        Task { @MainActor [weak self] in
            guard
                let self,
                let info = notification.userInfo,
                let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                let type = AVAudioSession.InterruptionType(rawValue: typeValue)
            else { return }

            switch type {
            case .began:
                self.pause()
            case .ended:
                if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt,
                   AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
                    self.resume()
                }
            @unknown default:
                break
            }
        }
    }
}
