import XCTest
import SwiftData
@testable import EitangoApp

/// 間隔反復の間隔計算と、正誤による段階の上下をテストする。
/// ここが壊れると「復習すべき語が出てこない／覚えた語ばかり出る」という
/// 気付きにくい形で学習効果が損なわれるため、重点的に押さえておく。
@MainActor
final class SpacedRepetitionTests: XCTestCase {

    /// 日付計算のブレを避けるため、テスト内では固定のカレンダーと基準日を使う
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    // MARK: - 間隔テーブル

    func testIntervalsGrowWithEachBox() {
        let intervals = (0...UserProgress.maxReviewBox).map { UserProgress.intervalDays(forBox: $0) }
        XCTAssertEqual(intervals, [0, 1, 3, 7, 14, 30])

        // 単調増加でないと「上の段階なのに早く出てくる」ことになる
        XCTAssertEqual(intervals, intervals.sorted())
    }

    func testIntervalClampsOutOfRangeBox() {
        XCTAssertEqual(UserProgress.intervalDays(forBox: -5), 0)
        XCTAssertEqual(UserProgress.intervalDays(forBox: 999), 30)
    }

    // MARK: - 正誤による段階遷移

    func testCorrectAnswerAdvancesBoxAndPushesReviewDate() {
        let progress = UserProgress(wordId: "W1")
        let reviewedAt = date(2026, 8, 1)

        progress.record(isCorrect: true, reviewedAt: reviewedAt, calendar: calendar)

        XCTAssertEqual(progress.reviewBox, 1)
        XCTAssertEqual(progress.correctCount, 1)
        XCTAssertEqual(progress.attemptCount, 1)
        // box1 = 1日後
        XCTAssertEqual(progress.nextReviewAt, calendar.startOfDay(for: date(2026, 8, 2)))
        // 1回正解しただけでは「覚えた」にしない
        XCTAssertEqual(progress.status(at: date(2026, 8, 2)), .learning)
    }

    func testWrongAnswerResetsToShortestInterval() {
        let progress = UserProgress(wordId: "W1")
        let day1 = date(2026, 8, 1)

        // 3回正解して間隔を伸ばす
        progress.record(isCorrect: true, reviewedAt: day1, calendar: calendar)
        progress.record(isCorrect: true, reviewedAt: day1, calendar: calendar)
        progress.record(isCorrect: true, reviewedAt: day1, calendar: calendar)
        XCTAssertEqual(progress.reviewBox, 3)

        // 1回間違えたら最短に戻る
        progress.record(isCorrect: false, reviewedAt: day1, calendar: calendar)

        XCTAssertEqual(progress.reviewBox, 0)
        XCTAssertEqual(progress.status(at: day1), .needsReview)
        // box0 = 当日中に再出題される
        XCTAssertEqual(progress.nextReviewAt, calendar.startOfDay(for: day1))
        XCTAssertTrue(progress.isDue(at: day1))
    }

    // MARK: - 習熟段階の判定

    /// 「覚えた」は7日間隔に到達してから。直前に正解しただけでは学習中に留める。
    func testMasteredOnlyAfterReachingTheWeekLongInterval() {
        let progress = UserProgress(wordId: "W1")
        var day = date(2026, 8, 1)

        // box1（1日後）
        progress.record(isCorrect: true, reviewedAt: day, calendar: calendar)
        XCTAssertEqual(progress.status(at: date(2026, 8, 2)), .learning)

        // box2（3日後）
        day = date(2026, 8, 2)
        progress.record(isCorrect: true, reviewedAt: day, calendar: calendar)
        XCTAssertEqual(progress.status(at: date(2026, 8, 5)), .learning)

        // box3（7日後）＝ここで「覚えた」
        day = date(2026, 8, 5)
        progress.record(isCorrect: true, reviewedAt: day, calendar: calendar)
        XCTAssertEqual(progress.reviewBox, UserProgress.masteredBox)
        XCTAssertEqual(progress.status(at: date(2026, 8, 6)), .memorized)
    }

    func testStatusIsNotStudiedUntilFirstAnswer() {
        let progress = UserProgress(wordId: "W1")
        XCTAssertEqual(progress.status(at: date(2026, 8, 1)), .notStudied)
    }

    /// 期限が来たら、どれだけ習得が進んでいても「要復習」に戻す。
    /// 覚えた表示のまま放置されると、実際には忘れている語が残り続けるため。
    func testDueWordFallsBackToNeedsReviewEvenIfMastered() {
        let progress = UserProgress(wordId: "W1")
        for _ in 0..<5 {
            progress.record(isCorrect: true, reviewedAt: date(2026, 8, 1), calendar: calendar)
        }
        XCTAssertEqual(progress.status(at: date(2026, 8, 2)), .memorized)

        // 30日後、期限を過ぎた時点
        XCTAssertEqual(progress.status(at: date(2026, 9, 30)), .needsReview)
    }

    func testManualActionsMoveTheInterval() {
        let progress = UserProgress(wordId: "W1")

        progress.markAsMemorized(at: date(2026, 8, 1), calendar: calendar)
        XCTAssertEqual(progress.status(at: date(2026, 8, 2)), .memorized)

        progress.markForReview(at: date(2026, 8, 2), calendar: calendar)
        XCTAssertEqual(progress.reviewBox, 0)
        XCTAssertEqual(progress.status(at: date(2026, 8, 2)), .needsReview)
    }

    func testBoxDoesNotExceedMaximum() {
        let progress = UserProgress(wordId: "W1")
        for _ in 0..<20 {
            progress.record(isCorrect: true, reviewedAt: date(2026, 8, 1), calendar: calendar)
        }
        XCTAssertEqual(progress.reviewBox, UserProgress.maxReviewBox)
    }

    // MARK: - 出題対象の判定

    func testUnstudiedWordIsAlwaysDue() {
        let progress = UserProgress(wordId: "W1")
        XCTAssertNil(progress.nextReviewAt)
        XCTAssertTrue(progress.isDue(at: date(2020, 1, 1)))
    }

    func testWordIsNotDueBeforeItsScheduledDate() {
        let progress = UserProgress(wordId: "W1")
        progress.record(isCorrect: true, reviewedAt: date(2026, 8, 1), calendar: calendar)

        XCTAssertFalse(progress.isDue(at: date(2026, 8, 1, hour: 23)))
        XCTAssertTrue(progress.isDue(at: date(2026, 8, 2, hour: 0)))
        XCTAssertTrue(progress.isDue(at: date(2026, 8, 5)))
    }

    /// 同じ日の朝に解いても夜に解いても、次回の期限は同じ日付に揃うこと
    func testReviewDateIsIndependentOfTimeOfDay() {
        let morning = UserProgress(wordId: "W1")
        let night = UserProgress(wordId: "W2")

        morning.record(isCorrect: true, reviewedAt: date(2026, 8, 1, hour: 7), calendar: calendar)
        night.record(isCorrect: true, reviewedAt: date(2026, 8, 1, hour: 23), calendar: calendar)

        XCTAssertEqual(morning.nextReviewAt, night.nextReviewAt)
    }
}
