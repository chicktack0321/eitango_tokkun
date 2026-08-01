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
        XCTAssertEqual(progress.status, .memorized)
        XCTAssertEqual(progress.correctCount, 1)
        XCTAssertEqual(progress.attemptCount, 1)
        // box1 = 1日後
        XCTAssertEqual(progress.nextReviewAt, calendar.startOfDay(for: date(2026, 8, 2)))
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
        XCTAssertEqual(progress.status, .needsReview)
        // box0 = 当日中に再出題される
        XCTAssertEqual(progress.nextReviewAt, calendar.startOfDay(for: day1))
        XCTAssertTrue(progress.isDue(at: day1))
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
