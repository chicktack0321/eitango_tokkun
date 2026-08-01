import XCTest
import SwiftData
@testable import EitangoApp

/// 学習履歴の集計をテストする。
/// 日付の扱いは「グラフが1日ずれる」「連続日数が理由なく途切れる」といった形で表面化しやすく、
/// 目視では気付きにくいため境界を細かく押さえる。
@MainActor
final class StudyHistoryTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    override func setUpWithError() throws {
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

    private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @discardableResult
    private func makeLog(_ date: Date, studied: Int, correct: Int = 0, attempts: Int = 0) -> StudyLog {
        let log = StudyLog(
            date: calendar.startOfDay(for: date),
            studiedWordCount: studied,
            correctCount: correct,
            attemptCount: attempts
        )
        context.insert(log)
        return log
    }

    // MARK: - 日次系列

    func testSeriesFillsMissingDaysWithZero() {
        let logs = [
            makeLog(day(2026, 8, 5), studied: 10),
            makeLog(day(2026, 8, 7), studied: 4)
        ]

        let series = StudyHistory.series(
            logs: logs,
            days: 5,
            endingOn: day(2026, 8, 7, hour: 15),
            calendar: calendar
        )

        // 8/3〜8/7 の5日ぶんが必ず並ぶ
        XCTAssertEqual(series.count, 5)
        XCTAssertEqual(series.map(\.studiedWordCount), [0, 0, 10, 0, 4])
    }

    func testSeriesIsOrderedOldestFirstAndEndsToday() {
        let series = StudyHistory.series(
            logs: [],
            days: 3,
            endingOn: day(2026, 8, 7, hour: 23),
            calendar: calendar
        )

        XCTAssertEqual(series.map(\.date), [
            calendar.startOfDay(for: day(2026, 8, 5)),
            calendar.startOfDay(for: day(2026, 8, 6)),
            calendar.startOfDay(for: day(2026, 8, 7))
        ])
    }

    /// 時刻付きで保存されたログでも、その日のバーに集計されること
    func testSeriesMatchesLogRecordedLateInTheDay() {
        let log = StudyLog(date: day(2026, 8, 7, hour: 23), studiedWordCount: 7)
        context.insert(log)

        let series = StudyHistory.series(
            logs: [log],
            days: 1,
            endingOn: day(2026, 8, 7, hour: 1),
            calendar: calendar
        )

        XCTAssertEqual(series.first?.studiedWordCount, 7)
    }

    func testSeriesWithNonPositiveDaysIsEmpty() {
        XCTAssertTrue(StudyHistory.series(logs: [], days: 0, endingOn: day(2026, 8, 7), calendar: calendar).isEmpty)
        XCTAssertTrue(StudyHistory.series(logs: [], days: -3, endingOn: day(2026, 8, 7), calendar: calendar).isEmpty)
    }

    // MARK: - 連続学習日数

    func testStreakCountsConsecutiveDaysEndingToday() {
        let logs = [
            makeLog(day(2026, 8, 5), studied: 3),
            makeLog(day(2026, 8, 6), studied: 3),
            makeLog(day(2026, 8, 7), studied: 3)
        ]

        let streak = StudyHistory.currentStreak(logs: logs, today: day(2026, 8, 7, hour: 12), calendar: calendar)
        XCTAssertEqual(streak, 3)
    }

    /// 当日まだ解いていなくても、前日までの連続は途切れていないものとして数える。
    /// ここを厳密にすると朝アプリを開いた瞬間に0日と表示され、継続の動機付けにならない。
    func testStreakSurvivesWhenTodayHasNoRecordYet() {
        let logs = [
            makeLog(day(2026, 8, 5), studied: 3),
            makeLog(day(2026, 8, 6), studied: 3)
        ]

        let streak = StudyHistory.currentStreak(logs: logs, today: day(2026, 8, 7, hour: 9), calendar: calendar)
        XCTAssertEqual(streak, 2)
    }

    func testStreakStopsAtAGap() {
        let logs = [
            makeLog(day(2026, 8, 1), studied: 3),
            makeLog(day(2026, 8, 2), studied: 3),
            // 8/3 は学習なし
            makeLog(day(2026, 8, 4), studied: 3),
            makeLog(day(2026, 8, 5), studied: 3)
        ]

        let streak = StudyHistory.currentStreak(logs: logs, today: day(2026, 8, 5), calendar: calendar)
        XCTAssertEqual(streak, 2)
    }

    /// 2日以上空くと、前日も当日も記録が無いので連続は0になる
    func testStreakIsZeroAfterTwoIdleDays() {
        let logs = [makeLog(day(2026, 8, 1), studied: 3)]

        let streak = StudyHistory.currentStreak(logs: logs, today: day(2026, 8, 4), calendar: calendar)
        XCTAssertEqual(streak, 0)
    }

    func testStreakIgnoresDaysWithoutStudiedWords() {
        // 記録行はあるが1語も解いていない日は「学習した日」に数えない
        let logs = [
            makeLog(day(2026, 8, 5), studied: 3),
            makeLog(day(2026, 8, 6), studied: 0),
            makeLog(day(2026, 8, 7), studied: 3)
        ]

        let streak = StudyHistory.currentStreak(logs: logs, today: day(2026, 8, 7), calendar: calendar)
        XCTAssertEqual(streak, 1)
    }

    func testStreakIsZeroWithoutLogs() {
        XCTAssertEqual(StudyHistory.currentStreak(logs: [], today: day(2026, 8, 7), calendar: calendar), 0)
    }

    // MARK: - 期間集計

    /// 日ごとの正答率を単純平均すると、1問だけ解いた日が重く効いてしまう。
    /// 解答数で重み付けされていることを確認する。
    func testOverallAccuracyIsWeightedByAttempts() {
        let series = [
            DailyStudy(date: day(2026, 8, 6), studiedWordCount: 1, correctCount: 1, attemptCount: 1),
            DailyStudy(date: day(2026, 8, 7), studiedWordCount: 99, correctCount: 50, attemptCount: 100)
        ]

        // 単純平均なら (100% + 50%) / 2 = 75%、重み付けなら 51/101 ≒ 50.5%
        XCTAssertEqual(StudyHistory.overallAccuracy(in: series), 51.0 / 101.0, accuracy: 0.0001)
        XCTAssertEqual(StudyHistory.totalAttempts(in: series), 101)
    }

    func testOverallAccuracyIsZeroWithoutAttempts() {
        let series = [DailyStudy(date: day(2026, 8, 7), studiedWordCount: 0, correctCount: 0, attemptCount: 0)]
        XCTAssertEqual(StudyHistory.overallAccuracy(in: series), 0)
    }
}
