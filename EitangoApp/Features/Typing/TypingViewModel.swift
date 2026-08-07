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

    /// 出題の見せ方。
    enum Mode: String, CaseIterable, Identifiable {
        /// スペルを見ながら打つ
        case normal
        /// スペルを伏せて打つ。打った文字だけが現れる。
        /// 保存済みのスコアと結び付いているため、表示名を変えても rawValue は変えない。
        case hidden

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .normal: return "ノーマル"
            case .hidden: return "ブラインド"
            }
        }

        var summary: String {
            switch self {
            case .normal: return "スペルを見ながら打ちます"
            case .hidden: return "スペルを伏せて打ちます。日本語訳だけを頼りに綴りを思い出す練習になります"
            }
        }

        /// ブラインドは難易度が高いぶんスコアを上乗せする
        var scoreMultiplier: Double {
            switch self {
            case .normal: return 1.0
            case .hidden: return 1.5
            }
        }
    }

    private(set) var phase: StudySessionPhase = .notStarted
    private(set) var mode: Mode = .normal
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

    /// 自己ベスト上位。結果画面に出す。
    private(set) var bestScores: [TypingScore] = []
    /// 直近の結果がベスト入り／自己ベスト更新だったか
    private(set) var achievement = TypingScoreRepository.Achievement.none

    /// いま選んでいる出題範囲に何語入るか
    private(set) var scopeWordCount = 0
    /// 自分で追加した単語があるか
    private(set) var hasUserWords = false

    private var currentWordMissed = false
    private var wordRepository: WordRepository?
    private var progressRepository: ProgressRepository?
    private var scoreRepository: TypingScoreRepository?
    private var userWordRepository: UserWordRepository?
    /// deinit（常にnonisolated）から安全にキャンセルできるよう、actor隔離チェックの対象から外す。
    /// `Task.cancel()` はどのスレッドから呼んでも安全なため、この用途では問題ない。
    nonisolated(unsafe) private var timerTask: Task<Void, Never>?
    nonisolated(unsafe) private var flashResetTask: Task<Void, Never>?

    var currentWord: WordMaster? {
        guard wordIndex < words.count else { return nil }
        return words[wordIndex]
    }

    /// いま打っている語を小文字の文字配列にしたもの。
    /// 照合は1打鍵ごとに走るので、そのつど作り直さず語が変わったときだけ更新する。
    private var currentWordLetters: [Character] = []

    private func refreshCurrentWordLetters() {
        currentWordLetters = Array(currentWord?.word.lowercased() ?? "")
    }

    var accuracy: Double {
        let total = correctCharCount + missCount
        return total == 0 ? 1 : Double(correctCharCount) / Double(total)
    }

    func configure(context: ModelContext) {
        guard wordRepository == nil else { return }
        wordRepository = WordRepository(context: context)
        progressRepository = ProgressRepository(context: context)
        scoreRepository = TypingScoreRepository(context: context)
        userWordRepository = UserWordRepository(context: context)
        bestScores = scoreRepository?.best() ?? []
        refreshScopeCount()
    }

    /// 出題範囲を変えたときに、スタート画面の語数表示を合わせる
    func refreshScopeCount() {
        guard let wordRepository else { return }
        scopeWordCount = wordRepository.countStudyPool(scope: StudySettings.studyScope)
        hasUserWords = !(userWordRepository?.all().isEmpty ?? true)
    }

    func start(mode: Mode = .normal) {
        guard let wordRepository, let progressRepository else { return }
        self.mode = mode

        // クイズと同じく、復習期限が来た語から先に出題する
        let pool = StudyQueue.prioritize(
            words: wordRepository.fetchStudyPool(),
            progress: progressRepository.allProgress()
        )
        guard !pool.isEmpty else {
            words = []
            phase = .finished
            return
        }

        // 当日の「覚えた」語数の基準をここで作る。打鍵中は増減ぶんしか足し引きしないため。
        // 全語の走査になるが、すぐ上で出題プールと進捗を読んでいるので追加の負担は小さい。
        progressRepository.refreshMasterySnapshot()

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
        achievement = .none
        refreshCurrentWordLetters()
        phase = .inProgress
        GameAudio.shared.play(.start)
        GameAudio.shared.startBGM()
        startTimer()
    }

    /// 時間切れ。スコアを保存し、ベスト入りしたかを確定させる。
    private func finish() {
        guard phase == .inProgress else { return }
        phase = .finished
        GameAudio.shared.stopBGM()

        let record = TypingScore(
            score: score,
            correctWordCount: correctWordCount,
            missCount: missCount,
            maxCombo: maxCombo,
            accuracy: accuracy,
            isHiddenMode: mode == .hidden
        )
        achievement = scoreRepository?.record(record) ?? .none
        bestScores = scoreRepository?.best() ?? []
        // 1語ごとの保存は打鍵の待ち時間になるのでやめ、区切りでまとめて書き出す
        progressRepository?.save()

        GameAudio.shared.play(achievement.isNewBest ? .fanfare : .gameOver)
    }

    /// 1文字分の入力を受け取り、現在の単語の現在位置の文字と照合する
    func inputCharacter(_ character: Character) {
        guard phase == .inProgress, let word = currentWord else { return }
        // 打鍵のたびに小文字化と配列確保をやり直さない。単語が変わるときだけ作る
        let letters = currentWordLetters
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
            GameAudio.shared.play(.hit)
            return
        }

        // 単語完成
        combo += 1
        maxCombo = max(maxCombo, combo)
        // 5コンボごとは音を変えて、続いていることが分かるようにする
        GameAudio.shared.play(combo.isMultiple(of: 5) ? .combo : .wordComplete)
        let bonus = Self.timeBonus(for: word.word)
        score += Int(Double(Self.wordScore(word: word, combo: combo)) * mode.scoreMultiplier)
        remainingSeconds = min(remainingSeconds + bonus, Self.maxTimer)
        lastTimeBonus = bonus
        correctWordCount += 1

        progressRepository?.recordAnswer(word: word, isCorrect: !currentWordMissed)
        currentWordMissed = false

        charIndex = 0
        wordIndex = (wordIndex + 1) % words.count
        refreshCurrentWordLetters()
        wordToken += 1
    }

    private func handleMiss() {
        combo = 0
        missCount += 1
        currentWordMissed = true
        missFlash = true
        GameAudio.shared.play(.miss)

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
        GameAudio.shared.stopBGM()
        progressRepository?.save()
    }

    /// 別タブへ移動した・アプリが背面に回ったときに計測を止める。
    /// 止めないと画面を見ていない間にタイムアップし、戻ると結果画面になっている。
    /// BGMも一緒に止める（他の画面に移ってからも鳴り続けると邪魔になるため）。
    func suspendTimer() {
        timerTask?.cancel()
        timerTask = nil
        GameAudio.shared.stopBGM()
        // 背面に回されたまま終了されても記録が消えないよう、ここで書き出しておく
        progressRepository?.save()
    }

    /// 画面に戻ったときに、残り時間を引き継いで計測を再開する
    func resumeTimer() {
        guard phase == .inProgress, timerTask == nil else { return }
        GameAudio.shared.startBGM()
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
                    self.finish()
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
