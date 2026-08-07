import Foundation
import AVFoundation
import os

/// 出題された単語を1語だけ読み上げる。
///
/// 聞き流し（`AudioPlaybackManager`）とは役割が違うので分けている。あちらは
/// 連続再生・バックグラウンド継続・Now Playing を担うため、オーディオセッションを
/// 占有して有効化・解放を管理する。ここで同じ仕組みを使うと、1語読み上げるたびに
/// セッションの奪い合いが起き、タイピングのBGMが止まってしまう。
///
/// こちらは `.mixWithOthers` で控えめに割り込むだけにして、BGMや効果音と共存させる。
@MainActor
final class WordPronouncer {
    static let shared = WordPronouncer()

    private let logger = Logger(subsystem: "com.eitango.app", category: "WordPronouncer")
    private let synthesizer = AVSpeechSynthesizer()
    private var hasConfiguredSession = false

    /// 音声の取得は内部で一覧を引くため安くない。出題のたびに作らず1回だけ用意する
    private lazy var englishVoice = AVSpeechSynthesisVoice(language: "en-US")

    private init() {}

    /// 出題された語を読み上げる。
    /// 読み上げを切っている場合と、音そのものを消している場合は何もしない。
    func speak(_ word: String) {
        guard StudySettings.pronouncesWords, GameAudio.shared.isEnabled else { return }
        guard !word.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        configureSessionIfNeeded()

        // 次の問題へ素早く進んだときに前の語が重ならないようにする
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = englishVoice
        // 出題の邪魔にならないよう、聞き流しよりわずかに速くする
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    func stop() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// カテゴリの設定は一度だけでよい。毎回呼ぶとBGMが途切れることがある。
    private func configureSessionIfNeeded() {
        guard !hasConfiguredSession else { return }
        do {
            // .mixWithOthers を付けないと、読み上げのたびにタイピングのBGMが止まる
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.mixWithOthers]
            )
            hasConfiguredSession = true
        } catch {
            logger.notice("読み上げ用のオーディオ設定に失敗しました: \(error.localizedDescription, privacy: .public)")
        }
    }
}
