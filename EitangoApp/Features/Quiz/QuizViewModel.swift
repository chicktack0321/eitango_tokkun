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
        let pool = wordRepository.fetchAll().shuffled()
        let sampled = Array(pool.prefix(Self.questionCount))

        questions = sampled.map { word in
            buildQuestion(for: word, wordRepository: wordRepository)
        }
        currentQuestionIndex = 0
        correctAnswerCount = 0
        selectedChoiceIndex = nil
        phase = questions.isEmpty ? .finished : .inProgress
        startTimer()
    }

    private func buildQuestion(for word: WordMaster, wordRepository: WordRepository) -> QuizQuestion {
        let distractors = wordRepository.randomDistractorMeanings(
            excluding: word.wordId,
            count: Self.choiceCount - 1
        )
        var choices = distractors + [word.meaning]
        choices.shuffle()
        let correctIndex = choices.firstIndex(of: word.meaning) ?? 0
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
