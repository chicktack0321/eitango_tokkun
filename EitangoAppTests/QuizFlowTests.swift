import XCTest
import SwiftData
@testable import EitangoApp

/// クイズの開始・終了まわりの状態遷移をテストする。
///
/// 「復習クイズを解き終えたあと、出題対象が無くなった状態で再挑戦する」経路で
/// 0問の結果画面に入り込み、スタート画面へ戻れなくなる不具合があった。
@MainActor
final class QuizFlowTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var previousSoundEnabled = true

    override func setUpWithError() throws {
        previousSoundEnabled = GameAudio.shared.isEnabled
        let schema = Schema([WordMaster.self, UserProgress.self, StudyLog.self, TypingScore.self])
        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        context = container.mainContext
        // 音はテストの対象外。シミュレータでオーディオエンジンを起動させない。
        GameAudio.shared.isEnabled = false
    }

    override func tearDownWithError() throws {
        // 音の設定は端末（シミュレータ）に保存されるため、テストの都合で消したままにしない
        GameAudio.shared.isEnabled = previousSoundEnabled
        context = nil
        container = nil
    }

    @discardableResult
    private func makeWord(_ index: Int) -> WordMaster {
        let word = WordMaster(
            wordId: "W\(index)",
            word: "word\(index)",
            meaning: "意味\(index)",
            example: "example \(index)",
            frequencyCount: index,
            category: .a,
            partOfSpeech: .noun
        )
        context.insert(word)
        return word
    }

    private func makeViewModel() -> QuizViewModel {
        let viewModel = QuizViewModel()
        viewModel.configure(context: context)
        return viewModel
    }

    func testMixedQuizStartsWithQuestions() {
        for index in 0..<20 { makeWord(index) }
        let viewModel = makeViewModel()

        viewModel.startNewQuiz(scope: .mixed)

        XCTAssertEqual(viewModel.phase, .inProgress)
        XCTAssertEqual(viewModel.questions.count, QuizViewModel.questionCount)
        XCTAssertNil(viewModel.notice)
    }

    /// 復習対象が無いときに0問の結果画面へ入らないこと。
    /// 入ってしまうと「0/0問正解・グレードD」が表示され、戻る手段も無くなる。
    func testReviewOnlyQuizWithNothingDueStaysOnStartScreen() {
        // 出題済みだが、次回の復習日はまだ先＝復習対象ではない
        for index in 0..<5 {
            makeWord(index)
            let progress = UserProgress(wordId: "W\(index)")
            progress.record(isCorrect: true, reviewedAt: .now)
            context.insert(progress)
        }
        let viewModel = makeViewModel()

        viewModel.startNewQuiz(scope: .reviewOnly)

        XCTAssertEqual(viewModel.phase, .notStarted)
        XCTAssertTrue(viewModel.questions.isEmpty)
        XCTAssertNotNil(viewModel.notice, "なぜ始まらなかったのかを画面で説明できる必要がある")
    }

    /// 単語が1件も無いときも同様に、結果画面ではなくスタート画面に留まること
    func testMixedQuizWithoutWordsStaysOnStartScreen() {
        let viewModel = makeViewModel()

        viewModel.startNewQuiz(scope: .mixed)

        XCTAssertEqual(viewModel.phase, .notStarted)
        XCTAssertNotNil(viewModel.notice)
    }

    /// 結果画面からスタート画面へ戻れること
    func testReturnToStartClearsTheSession() {
        for index in 0..<20 { makeWord(index) }
        let viewModel = makeViewModel()
        viewModel.startNewQuiz(scope: .mixed)
        viewModel.selectAnswer(0)

        viewModel.returnToStart()

        XCTAssertEqual(viewModel.phase, .notStarted)
        XCTAssertTrue(viewModel.questions.isEmpty)
        XCTAssertNil(viewModel.selectedChoiceIndex)
        XCTAssertNil(viewModel.notice)
    }

    /// 復習で始めたセットを解き終えたあと、同じ条件で再挑戦しても行き止まりにならないこと。
    /// 実際に不具合が起きた経路をそのままなぞる。
    func testRetryAfterFinishingAReviewSessionDoesNotDeadEnd() {
        // 復習期限が来ている語を3つ用意する
        for index in 0..<3 {
            makeWord(index)
            let progress = UserProgress(wordId: "W\(index)")
            progress.record(isCorrect: false, reviewedAt: .now)
            context.insert(progress)
        }
        let viewModel = makeViewModel()

        viewModel.startNewQuiz(scope: .reviewOnly)
        XCTAssertEqual(viewModel.phase, .inProgress)

        // 全問正解して解き切る（正解すると次回の復習日が先に延びるので、対象が無くなる）
        while viewModel.phase == .inProgress {
            guard let question = viewModel.currentQuestion else { break }
            viewModel.selectAnswer(question.correctIndex)
            viewModel.goToNextQuestion()
        }
        XCTAssertEqual(viewModel.phase, .finished)

        // 「もう一度挑戦する」に相当する操作
        viewModel.startNewQuiz(scope: viewModel.scope)

        XCTAssertEqual(viewModel.phase, .notStarted, "0問の結果画面に入ってはいけない")
        XCTAssertNotNil(viewModel.notice)
    }
}
