import XCTest
import SwiftData
@testable import EitangoApp

/// 出題順の優先度をテストする。
/// 「復習期限が来た語が最初に出る」ことがこのアプリの学習効果の要なので、
/// 並び順が崩れていないかをここで担保する。
@MainActor
final class StudyQueueTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        // @Model はコンテキストに紐づけて使うのが正しいため、インメモリのストアを用意する
        let schema = Schema([WordMaster.self, UserProgress.self, StudyLog.self])
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

    @discardableResult
    private func makeWord(_ id: String) -> WordMaster {
        let word = WordMaster(
            wordId: id,
            word: "word-\(id)",
            meaning: "意味-\(id)",
            example: "example",
            frequencyCount: 1,
            category: .a,
            partOfSpeech: .noun
        )
        context.insert(word)
        return word
    }

    private func makeProgress(
        _ id: String,
        attemptCount: Int,
        nextReviewAt: Date?
    ) -> UserProgress {
        let progress = UserProgress(
            wordId: id,
            attemptCount: attemptCount,
            nextReviewAt: nextReviewAt
        )
        context.insert(progress)
        return progress
    }

    func testDueWordsComeBeforeUnstudiedAndScheduled() {
        let due = makeWord("due")
        let unstudied = makeWord("unstudied")
        let future = makeWord("future")

        let progress = [
            "due": makeProgress("due", attemptCount: 3, nextReviewAt: now.addingTimeInterval(-86_400)),
            "future": makeProgress("future", attemptCount: 3, nextReviewAt: now.addingTimeInterval(86_400))
        ]

        let ordered = StudyQueue.prioritize(
            words: [future, unstudied, due],
            progress: progress,
            now: now
        )

        XCTAssertEqual(ordered.map(\.wordId), ["due", "unstudied", "future"])
    }

    func testScheduledWordsAreOrderedBySoonestDueDate() {
        let later = makeWord("later")
        let sooner = makeWord("sooner")

        let progress = [
            "later": makeProgress("later", attemptCount: 1, nextReviewAt: now.addingTimeInterval(7 * 86_400)),
            "sooner": makeProgress("sooner", attemptCount: 1, nextReviewAt: now.addingTimeInterval(86_400))
        ]

        let ordered = StudyQueue.prioritize(words: [later, sooner], progress: progress, now: now)

        XCTAssertEqual(ordered.map(\.wordId), ["sooner", "later"])
    }

    /// 進捗レコードはあるが一度も解いていない語は「未学習」として扱う。
    /// シード時に全単語へ空のUserProgressを作るため、この分岐は常に通る。
    func testProgressRowWithNoAttemptsCountsAsUnstudied() {
        let due = makeWord("due")
        let neverAnswered = makeWord("never")

        let progress = [
            "due": makeProgress("due", attemptCount: 2, nextReviewAt: now.addingTimeInterval(-1)),
            "never": makeProgress("never", attemptCount: 0, nextReviewAt: nil)
        ]

        let ordered = StudyQueue.prioritize(words: [neverAnswered, due], progress: progress, now: now)

        XCTAssertEqual(ordered.map(\.wordId), ["due", "never"])
    }

    func testPrioritizeKeepsEveryWord() {
        let words = (0..<20).map { makeWord("W\($0)") }
        var progress: [String: UserProgress] = [:]
        for (index, word) in words.enumerated() where index % 3 == 0 {
            progress[word.wordId] = makeProgress(
                word.wordId,
                attemptCount: 1,
                nextReviewAt: now.addingTimeInterval(Double(index) * 3_600)
            )
        }

        let ordered = StudyQueue.prioritize(words: words, progress: progress, now: now)

        XCTAssertEqual(ordered.count, words.count)
        XCTAssertEqual(Set(ordered.map(\.wordId)), Set(words.map(\.wordId)))
    }

    func testDueCountOnlyCountsAnsweredAndExpiredWords() {
        let due = makeWord("due")
        let future = makeWord("future")
        let unstudied = makeWord("unstudied")

        let progress = [
            "due": makeProgress("due", attemptCount: 1, nextReviewAt: now.addingTimeInterval(-60)),
            "future": makeProgress("future", attemptCount: 1, nextReviewAt: now.addingTimeInterval(60)),
            "unstudied": makeProgress("unstudied", attemptCount: 0, nextReviewAt: nil)
        ]

        let count = StudyQueue.dueCount(
            words: [due, future, unstudied],
            progress: progress,
            now: now
        )

        // 未学習の語は「復習」ではないので数に入れない
        XCTAssertEqual(count, 1)
    }

    func testEmptyInputProducesEmptyQueue() {
        XCTAssertTrue(StudyQueue.prioritize(words: [], progress: [:], now: now).isEmpty)
        XCTAssertEqual(StudyQueue.dueCount(words: [], progress: [:], now: now), 0)
    }
}
