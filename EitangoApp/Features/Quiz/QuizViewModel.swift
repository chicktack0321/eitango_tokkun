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
    private(set) var questions: [QuizQuestion] = []
    private(set) var currentQuestionIndex = 0
    private(set) var selectedChoiceIndex: Int?
    private(set) var remainingSeconds = QuizViewModel.timeLimitPerQuestion
    private(set) var correctAnswerCount = 0

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

    func startNewQuiz() {
        guard let wordRepository else { return }
        // 単語一覧の取得は1回だけ。問題ごとにフェッチすると出題数に比例して
        // 全件スキャンが走り、語彙数が増えたときに開始が目に見えて遅くなる。
        let pool = wordRepository.fetchAll()
        let sampled = pool.shuffled().prefix(Self.questionCount)

        questions = sampled.map { buildQuestion(for: $0, pool: pool) }
        currentQuestionIndex = 0
        correctAnswerCount = 0
        selectedChoiceIndex = nil
        phase = questions.isEmpty ? .finished : .inProgress
        startTimer()
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
        progressRepository?.recordAnswer(wordId: question.word.wordId, isCorrect: isCorrect)
    }

    /// 制限時間切れ（未回答）は不正解として記録する
    private func handleTimeout() {
        guard phase == .inProgress, let question = currentQuestion, selectedChoiceIndex == nil else { return }
        selectedChoiceIndex = -1 // 「未選択のまま時間切れ」を表す番兵
        progressRepository?.recordAnswer(wordId: question.word.wordId, isCorrect: false)
    }

    func goToNextQuestion() {
        timerTask?.cancel()
        guard currentQuestionIndex + 1 < questions.count else {
            phase = .finished
            return
        }
        currentQuestionIndex += 1
        selectedChoiceIndex = nil
        startTimer()
    }

    private func startTimer() {
        timerTask?.cancel()
        remainingSeconds = Self.timeLimitPerQuestion
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
