import XCTest
import SwiftData
@testable import EitangoApp

/// ホームの習熟度の内訳をテストする。
///
/// 一度も解いていない語には進捗の行を作らない方針にしたため、
/// 「未学習」は行を数えても出てこない。全語数から差し引く計算が必要になる。
@MainActor
final class HomeSummaryTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([WordMaster.self, UserProgress.self, StudyLog.self, TypingScore.self, UserWord.self])
        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
    }

    private func makeWord(_ index: Int) {
        context.insert(
            WordMaster(
                wordId: "W\(index)",
                word: "word\(index)",
                meaning: "意味\(index)",
                example: "",
                frequencyCount: 0,
                category: .a,
                partOfSpeech: .noun
            )
        )
    }

    private func makeViewModel() -> HomeViewModel {
        let viewModel = HomeViewModel()
        viewModel.configure(context: context)
        return viewModel
    }

    /// 進捗の行が1件も無くても、全語が「未学習」として数えられること
    func testAllWordsCountAsNotStudiedWithoutProgressRows() {
        for index in 0..<10 { makeWord(index) }

        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.totalWordCount, 10)
        XCTAssertEqual(viewModel.notStudiedCount, 10)
        XCTAssertEqual(viewModel.memorizedCount, 0)
    }

    /// 解答した語のぶんだけ「未学習」が減ること
    func testStudiedWordsAreSubtractedFromNotStudied() {
        for index in 0..<10 { makeWord(index) }
        let repository = ProgressRepository(context: context)
        repository.recordAnswer(wordId: "W0", isCorrect: true)
        repository.recordAnswer(wordId: "W1", isCorrect: false)

        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.notStudiedCount, 8)
        // 内訳の合計は必ず全語数に一致する（バーの幅が合わなくなるため）
        let total = LearningStatus.allCases.reduce(0) { $0 + (viewModel.statusCounts[$1] ?? 0) }
        XCTAssertEqual(total, viewModel.totalWordCount)
    }

    /// 単語が消えた後の孤立した進捗行があっても、未学習が負の数にならないこと
    func testNotStudiedNeverGoesNegative() {
        makeWord(0)
        let repository = ProgressRepository(context: context)
        repository.recordAnswer(wordId: "W0", isCorrect: true)
        repository.recordAnswer(wordId: "GHOST", isCorrect: true)

        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.totalWordCount, 1)
        XCTAssertGreaterThanOrEqual(viewModel.notStudiedCount, 0)
    }
}
