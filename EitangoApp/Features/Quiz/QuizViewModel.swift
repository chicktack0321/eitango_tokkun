import Foundation
import SwiftData
import Observation

struct QuizQuestion: Identifiable {
    let id: String // wordId
    let word: WordMaster
    let choices: [String]
    let correctIndex: Int
}

@Observable
@MainActor
final class QuizViewModel {
    static let questionCount = 15
    static let choiceCount = 4
    static let timeLimitPerQuestion: Int = 10 // 秒

    private(set) var phase: StudySessionPhase = .notStarted
    /// 直近に開始したセットの出題対象。画面タイトルと結果の文言を切り替えるのに使う。
    private(set) var scope: QuizScope = .mixed
    private(set) var questions: [QuizQuestion] = []
    private(set) var currentQuestionIndex = 0
    private(set) var selectedChoiceIndex: Int?
    private(set) var remainingSeconds = QuizViewModel.timeLimitPerQuestion
    private(set) var correctAnswerCount = 0

    /// 間違えた語。結果画面でそのまま復習に使えるよう、単語ごと保持する。
    private(set) var missedWords: [WordMaster] = []
    /// 時間切れで落とした数（選び間違いと区別する。対策が「速く解く」か「覚え直す」かで変わるため）
    private(set) var timeoutCount = 0
    /// このセットで新たに「覚えた」に到達した語数
    private(set) var newlyMemorizedCount = 0
    private var startedAt: Date?
    private(set) var elapsedSeconds = 0

    /// 出題できなかったときにスタート画面へ出す案内。
    /// 「復習を解き終えて期限切れの語が無くなった」は正常な結果なので、
    /// エラーではなく状況の説明として見せる。
    private(set) var notice: String?

    private var wordRepository: WordRepository?
    private var progressRepository: ProgressRepository?
    /// deinit（常にnonisolated）から安全にキャンセルできるよう、actor隔離チェックの対象から外す。
    /// `Task.cancel()` はどのスレッドから呼んでも安全なため、この用途では問題ない。
    nonisolated(unsafe) private var timerTask: Task<Void, Never>?

    var currentQuestion: QuizQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }

    var progressFraction: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentQuestionIndex) / Double(questions.count)
    }

    func configure(context: ModelContext) {
        guard wordRepository == nil else { return }
        wordRepository = WordRepository(context: context)
        progressRepository = ProgressRepository(context: context)
    }

    func startNewQuiz(scope: QuizScope = .mixed) {
        guard let wordRepository, let progressRepository else { return }
        self.scope = scope

        // 単語一覧の取得は1回だけ。問題ごとにフェッチすると出題数に比例して
        // 全件スキャンが走り、語彙数が増えたときに開始が目に見えて遅くなる。
        let pool = wordRepository.fetchAll()
        let progress = progressRepository.allProgress()

        // 復習期限が来た語を優先して出題する（ランダム出題では忘れかけた語に当たらない）
        let ordered: [WordMaster]
        switch scope {
        case .mixed:
            ordered = StudyQueue.prioritize(words: pool, progress: progress)
        case .reviewOnly:
            // ホームの「復習する単語がN語あります」から来た場合は、
            // 未学習の語を混ぜずに期限が来た語だけを出す
            ordered = StudyQueue.dueWords(words: pool, progress: progress)
        }
        let sampled = ordered.prefix(Self.questionCount)

        questions = sampled.map { buildQuestion(for: $0, pool: pool) }
        currentQuestionIndex = 0
        correctAnswerCount = 0
        selectedChoiceIndex = nil
        missedWords = []
        timeoutCount = 0
        newlyMemorizedCount = 0
        elapsedSeconds = 0
        startedAt = .now
        notice = nil

        // 復習を解き終えた直後は期限切れの語が無くなるため、0問になるのは正常な状態。
        // これを結果画面（.finished）で表示すると「0/0問正解・グレードD」という
        // 意味のない結果が出るうえ、スタート画面へ戻る手段が無くなってクイズを始められなくなる。
        guard !questions.isEmpty else {
            notice = scope == .reviewOnly
                ? "復習の期限が来ている単語はありません。おつかれさまでした。"
                : "出題できる単語がありません。"
            phase = .notStarted
            GameAudio.shared.stopBGM()
            return
        }

        phase = .inProgress
        GameAudio.shared.play(.start)
        GameAudio.shared.startBGM()
        startTimer()
    }

    /// 結果画面に渡す集計
    var resultSummary: QuizResultSummary {
        QuizResultSummary(
            scope: scope,
            correctCount: correctAnswerCount,
            totalCount: questions.count,
            timeoutCount: timeoutCount,
            newlyMemorizedCount: newlyMemorizedCount,
            elapsedSeconds: elapsedSeconds,
            missedWords: missedWords.map {
                QuizResultSummary.MissedWord(id: $0.wordId, word: $0.word, meaning: $0.meaning)
            }
        )
    }

    private func buildQuestion(for word: WordMaster, pool: [WordMaster]) -> QuizQuestion {
        // 別々の単語が同じ和訳を持つことは珍しくない（「改善する」など）。
        // 正解と同じ文字列がダミーに紛れると、正しい選択肢を選んでも不正解になりうるため、
        // 意味の重複を除外したうえでダミーを集める。
        var usedMeanings: Set<String> = [word.meaning]
        var distractors: [String] = []

        // 全体をシャッフルすると1問ごとに語彙数分のコストがかかるので、
        // ランダムに引いて必要な数だけ集める。重複だらけで終わらない場合に備えて試行回数を制限する。
        let maxAttempts = max(pool.count * 2, Self.choiceCount * 8)
        var attempts = 0
        while distractors.count < Self.choiceCount - 1, attempts < maxAttempts {
            attempts += 1
            guard let candidate = pool.randomElement() else { break }
            guard candidate.wordId != word.wordId,
                  !usedMeanings.contains(candidate.meaning) else { continue }
            usedMeanings.insert(candidate.meaning)
            distractors.append(candidate.meaning)
        }

        // 正解の位置は挿入時に決めて保持する。文字列検索で探すと、
        // 同じ文字列が複数あった場合に誤った位置を正解と見なしてしまう。
        let correctIndex = Int.random(in: 0...distractors.count)
        var choices = distractors
        choices.insert(word.meaning, at: correctIndex)

        return QuizQuestion(id: word.wordId, word: word, choices: choices, correctIndex: correctIndex)
    }

    func selectAnswer(_ index: Int) {
        guard phase == .inProgress, selectedChoiceIndex == nil, let question = currentQuestion else { return }
        timerTask?.cancel()
        selectedChoiceIndex = index

        let isCorrect = index == question.correctIndex
        if isCorrect { correctAnswerCount += 1 }
        // タイピングと同じ音で揃える（正解＝上昇音、ミス＝下降音）
        GameAudio.shared.play(isCorrect ? .wordComplete : .miss)
        record(question: question, isCorrect: isCorrect)
    }

    /// 制限時間切れ（未回答）は不正解として記録する
    private func handleTimeout() {
        guard phase == .inProgress, let question = currentQuestion, selectedChoiceIndex == nil else { return }
        selectedChoiceIndex = -1 // 「未選択のまま時間切れ」を表す番兵
        timeoutCount += 1
        GameAudio.shared.play(.miss)
        record(question: question, isCorrect: false)
    }

    private func record(question: QuizQuestion, isCorrect: Bool) {
        guard let progressRepository else { return }

        // 「覚えた」に到達したかは記録の前後で比べる必要があるので、先に段階を控えておく
        let before = progressRepository.progress(for: question.word.wordId).status
        progressRepository.recordAnswer(wordId: question.word.wordId, isCorrect: isCorrect)
        let after = progressRepository.progress(for: question.word.wordId).status

        if before != .memorized, after == .memorized {
            newlyMemorizedCount += 1
        }
        if !isCorrect {
            missedWords.append(question.word)
        }
    }

    func goToNextQuestion() {
        timerTask?.cancel()
        guard currentQuestionIndex + 1 < questions.count else {
            if let startedAt {
                elapsedSeconds = max(0, Int(Date.now.timeIntervalSince(startedAt)))
            }
            phase = .finished
            GameAudio.shared.stopBGM()
            // 結果画面のグレードと揃える。A以上（75%以上）なら祝う音にする。
            GameAudio.shared.play(resultSummary.accuracyPercent >= 75 ? .fanfare : .gameOver)
            return
        }
        currentQuestionIndex += 1
        selectedChoiceIndex = nil
        startTimer()
    }

    /// 進行中のセットを破棄してスタート画面に戻す。
    /// これが無いと、始めてしまったら最後まで解くか時間切れを待つしか抜ける手段がない。
    func abortSession() {
        returnToStart()
    }

    /// 結果画面からスタート画面へ戻す。
    /// 結果を見たあと別の出題で解き直せるよう、必ず戻り道を用意しておく。
    func returnToStart() {
        timerTask?.cancel()
        timerTask = nil
        GameAudio.shared.stopBGM()
        questions = []
        currentQuestionIndex = 0
        selectedChoiceIndex = nil
        correctAnswerCount = 0
        notice = nil
        phase = .notStarted
    }

    /// 別タブへ移動した・アプリが背面に回ったときに制限時間の消費を止める。
    /// 止めないと画面を見ていない間に時間切れになり、戻ったら勝手に不正解が記録されている。
    func suspendTimer() {
        timerTask?.cancel()
        timerTask = nil
        // 別タブや別アプリに移ったあともBGMが鳴り続けないようにする
        GameAudio.shared.stopBGM()
    }

    /// 画面に戻ったときに、残り時間を引き継いで計測を再開する
    func resumeTimer() {
        guard phase == .inProgress else { return }
        GameAudio.shared.startBGM()
        guard selectedChoiceIndex == nil, timerTask == nil else { return }
        runTimer()
    }

    private func startTimer() {
        remainingSeconds = Self.timeLimitPerQuestion
        runTimer()
    }

    private func runTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            guard let self else { return }
            while remainingSeconds > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                remainingSeconds -= 1
            }
            handleTimeout()
        }
    }

    deinit {
        timerTask?.cancel()
    }
}
