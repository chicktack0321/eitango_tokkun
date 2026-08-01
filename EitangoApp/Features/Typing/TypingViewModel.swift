import Foundation
import SwiftData
import Observation

/// 寿司打風のタイムアタック・タイピング。
/// 制限時間内に1文字ずつ判定しながら何語正しく打てるかを競う（従来の「1問ずつ全文字入力して解答ボタン」方式ではない）。
/// ミスした場合はコンボが0に戻り、同じ文字を打ち直すまで先に進めない。
/// 単語を打ち切ると自動的に次の単語へ進み、単語の長さに応じた秒数が残り時間に加算される。
@Observable
@MainActor
final class TypingViewModel {
    static let sessionDuration = 60 // 秒
    private static let maxTimer = 99 // 時間ボーナスでの上限（寿司打と同様）

    private(set) var phase: StudySessionPhase = .notStarted
    private(set) var words: [WordMaster] = []
    private(set) var wordIndex = 0
    private(set) var charIndex = 0
    private(set) var remainingSeconds = TypingViewModel.sessionDuration

    private(set) var score = 0
    private(set) var combo = 0
    private(set) var maxCombo = 0
    private(set) var correctWordCount = 0
    private(set) var missCount = 0
    private(set) var correctCharCount = 0

    /// 直近のミスによる赤フラッシュ表示のトリガー（短時間だけtrueになる）
    private(set) var missFlash = false
    /// 直前に単語を完成させて得た時間ボーナス（演出用。0なら非表示）
    private(set) var lastTimeBonus = 0
    /// 単語が切り替わるたびに変化するキー。Viewの完成演出の再生トリガーに使う
    private(set) var wordToken = 0

    private var currentWordMissed = false
    private var wordRepository: WordRepository?
    private var progressRepository: ProgressRepository?
    /// deinit（常にnonisolated）から安全にキャンセルできるよう、actor隔離チェックの対象から外す。
    /// `Task.cancel()` はどのスレッドから呼んでも安全なため、この用途では問題ない。
    nonisolated(unsafe) private var timerTask: Task<Void, Never>?
    nonisolated(unsafe) private var flashResetTask: Task<Void, Never>?

    var currentWord: WordMaster? {
        guard wordIndex < words.count else { return nil }
        return words[wordIndex]
    }

    var accuracy: Double {
        let total = correctCharCount + missCount
        return total == 0 ? 1 : Double(correctCharCount) / Double(total)
    }

    func configure(context: ModelContext) {
        guard wordRepository == nil else { return }
        wordRepository = WordRepository(context: context)
        progressRepository = ProgressRepository(context: context)
    }

    func start() {
        guard let wordRepository else { return }
        let pool = wordRepository.fetchAll().shuffled()
        guard !pool.isEmpty else {
            words = []
            phase = .finished
            return
        }

        words = pool
        wordIndex = 0
        charIndex = 0
        remainingSeconds = Self.sessionDuration
        score = 0
        combo = 0
        maxCombo = 0
        correctWordCount = 0
        missCount = 0
        correctCharCount = 0
        missFlash = false
        lastTimeBonus = 0
        currentWordMissed = false
        wordToken = 0
        phase = .inProgress
        startTimer()
    }

    /// 1文字分の入力を受け取り、現在の単語の現在位置の文字と照合する
    func inputCharacter(_ character: Character) {
        guard phase == .inProgress, let word = currentWord else { return }
        let letters = Array(word.word.lowercased())
        guard charIndex < letters.count else { return }

        if character.lowercased() == String(letters[charIndex]) {
            handleCorrectChar(word: word, totalLetters: letters.count)
        } else {
            handleMiss()
        }
    }

    private func handleCorrectChar(word: WordMaster, totalLetters: Int) {
        correctCharCount += 1
        let nextIndex = charIndex + 1
        guard nextIndex >= totalLetters else {
            charIndex = nextIndex
            return
        }

        // 単語完成
        combo += 1
        maxCombo = max(maxCombo, combo)
        let bonus = Self.timeBonus(for: word.word)
        score += Self.wordScore(word: word, combo: combo)
        remainingSeconds = min(remainingSeconds + bonus, Self.maxTimer)
        lastTimeBonus = bonus
        correctWordCount += 1

        progressRepository?.recordAnswer(wordId: word.wordId, isCorrect: !currentWordMissed)
        currentWordMissed = false

        charIndex = 0
        wordIndex = (wordIndex + 1) % words.count
        wordToken += 1
    }

    private func handleMiss() {
        combo = 0
        missCount += 1
        currentWordMissed = true
        missFlash = true

        flashResetTask?.cancel()
        flashResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            self?.missFlash = false
        }
    }

    /// 進行中のセッションを破棄してスタート画面に戻す。
    /// これが無いと、始めてしまったら60秒経つのを待つしか抜ける手段がない。
    func abortSession() {
        timerTask?.cancel()
        timerTask = nil
        flashResetTask?.cancel()
        flashResetTask = nil
        missFlash = false
        phase = .notStarted
    }

    /// 別タブへ移動した・アプリが背面に回ったときに計測を止める。
    /// 止めないと画面を見ていない間にタイムアップし、戻ると結果画面になっている。
    func suspendTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    /// 画面に戻ったときに、残り時間を引き継いで計測を再開する
    func resumeTimer() {
        guard phase == .inProgress, timerTask == nil else { return }
        startTimer()
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while true {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, !Task.isCancelled else { return }
                guard self.phase == .inProgress else { return }
                self.remainingSeconds -= 1
                if self.remainingSeconds <= 0 {
                    self.remainingSeconds = 0
                    self.phase = .finished
                    return
                }
            }
        }
    }

    /// 単語の長さに応じた時間ボーナス（短い語1秒／中程度2秒／長い語3秒）
    private static func timeBonus(for word: String) -> Int {
        switch word.count {
        case ...4: return 1
        case ...7: return 2
        default: return 3
        }
    }

    /// スコア = 文字数×10 × コンボ倍率(5コンボごとに+0.5) × 頻出度倍率（Aが最も高難度扱い）
    private static func wordScore(word: WordMaster, combo: Int) -> Int {
        let base = word.word.count * 10
        let comboMultiplier = 1.0 + Double(combo / 5) * 0.5
        let categoryMultiplier: Double
        switch word.category {
        case .a: categoryMultiplier = 1.5
        case .b: categoryMultiplier = 1.2
        case .c: categoryMultiplier = 1.0
        }
        return Int(Double(base) * comboMultiplier * categoryMultiplier)
    }

    deinit {
        timerTask?.cancel()
        flashResetTask?.cancel()
    }
}
