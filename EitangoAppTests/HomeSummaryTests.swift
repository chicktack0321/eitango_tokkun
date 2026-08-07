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
    private var previousMasteryScope = StudyScope.default

    override func setUpWithError() throws {
        // 集計範囲は端末に保存されるため、前回の実行に引きずられないよう既定に戻す
        previousMasteryScope = StudySettings.masteryScope
        StudySettings.masteryScope = .default

        let schema = Schema([WordMaster.self, UserProgress.self, StudyLog.self, TypingScore.self, UserWord.self])
        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        StudySettings.masteryScope = previousMasteryScope
        context = nil
        container = nil
    }

    @discardableResult
    private func makeWord(_ index: Int) -> WordMaster {
        let word = WordMaster(
            wordId: "W\(index)",
            word: "word\(index)",
            meaning: "意味\(index)",
            example: "",
            frequencyCount: 0,
            category: .a,
            partOfSpeech: .noun
        )
        context.insert(word)
        return word
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

    /// 絞り込みが既定（すべて）のときは、基礎語彙も語数に入ること。
    /// 出題では基礎を外すが、習熟度で「すべて」を選んだのに数から抜けていては、
    /// 何を見ている数字なのか分からない。
    func testMasteryCountsBasicTierWhenScopeIsDefault() {
        for index in 0..<3 { makeWord(index) }
        context.insert(
            WordMaster(
                wordId: "basic-1", word: "apple", meaning: "りんご", example: "",
                frequencyCount: 0, category: .a, partOfSpeech: .noun, tier: .basic
            )
        )

        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.totalWordCount, 4, "基礎語彙も含めて数えるべき")
    }

    /// 階層を選べばその階層だけになること
    func testMasteryNarrowsToSelectedTier() {
        for index in 0..<3 { makeWord(index) }
        context.insert(
            WordMaster(
                wordId: "basic-1", word: "apple", meaning: "りんご", example: "",
                frequencyCount: 0, category: .a, partOfSpeech: .noun, tier: .basic
            )
        )
        let viewModel = makeViewModel()

        viewModel.masteryScope.tier = .basic

        XCTAssertEqual(viewModel.totalWordCount, 1)
    }

    /// 解答した語のぶんだけ「未学習」が減ること
    func testStudiedWordsAreSubtractedFromNotStudied() {
        let words = (0..<10).map { makeWord($0) }
        let repository = ProgressRepository(context: context)
        repository.recordAnswer(word: words[0], isCorrect: true)
        repository.recordAnswer(word: words[1], isCorrect: false)

        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.notStudiedCount, 8)
        // 内訳の合計は必ず全語数に一致する（バーの幅が合わなくなるため）
        let total = LearningStatus.allCases.reduce(0) { $0 + (viewModel.statusCounts[$1] ?? 0) }
        XCTAssertEqual(total, viewModel.totalWordCount)
    }

    /// 単語が消えた後の孤立した進捗行があっても、未学習が負の数にならないこと
    func testNotStudiedNeverGoesNegative() {
        let word = makeWord(0)
        let repository = ProgressRepository(context: context)
        repository.recordAnswer(word: word, isCorrect: true)

        // 単語マスターには入れない。単語データの更新で語が消え、進捗行だけ残った状態を作る
        let ghost = WordMaster(
            wordId: "GHOST", word: "ghost", meaning: "亡霊", example: "",
            frequencyCount: 0, category: .a, partOfSpeech: .noun
        )
        repository.recordAnswer(word: ghost, isCorrect: true)

        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.totalWordCount, 1)
        XCTAssertGreaterThanOrEqual(viewModel.notStudiedCount, 0)
    }
}
