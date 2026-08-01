import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class StudyHistoryViewModel {
    /// グラフの表示期間
    enum Period: String, CaseIterable, Identifiable {
        case twoWeeks
        case month
        case threeMonths
        case sixMonths
        case year

        var id: String { rawValue }

        var days: Int {
            switch self {
            case .twoWeeks: return 14
            case .month: return 30
            case .threeMonths: return 90
            case .sixMonths: return 180
            case .year: return 365
            }
        }

        var displayName: String {
            switch self {
            case .twoWeeks: return "2週間"
            case .month: return "1か月"
            case .threeMonths: return "3か月"
            case .sixMonths: return "6か月"
            case .year: return "1年"
            }
        }

        /// 横軸の日付ラベルを何日おきに出すか。長期間で毎日出すと潰れて読めなくなる。
        var axisStrideDays: Int {
            switch self {
            case .twoWeeks: return 3
            case .month: return 7
            case .threeMonths: return 21
            case .sixMonths: return 45
            case .year: return 90
            }
        }

        /// 長期間では棒が細くなりすぎるので、日次ではなく週ごとにまとめる
        var aggregatesByWeek: Bool {
            switch self {
            case .twoWeeks, .month: return false
            case .threeMonths, .sixMonths, .year: return true
            }
        }
    }

    var selectedPeriod: Period = .twoWeeks {
        didSet { reload() }
    }

    /// グラフに描く系列。長期間では週ごとにまとめてある。
    private(set) var series: [DailyStudy] = []
    /// 日次のままの系列。「学習した日数」は週にまとめると数えられなくなるため別に持つ。
    private(set) var dailySeries: [DailyStudy] = []
    private(set) var streak = 0

    private var progressRepository: ProgressRepository?

    var totalAttempts: Int { StudyHistory.totalAttempts(in: dailySeries) }
    var overallAccuracy: Double { StudyHistory.overallAccuracy(in: dailySeries) }
    var studiedDayCount: Int { dailySeries.filter(\.didStudy).count }
    var hasAnyRecord: Bool { totalAttempts > 0 }
    /// 期間の終わりの時点で「覚えた」だった語数
    var masteredWordCount: Int { series.last?.masteredWordCount ?? 0 }
    /// 期間中の増加分。伸びが見えると継続の動機になる。
    var masteredGain: Int {
        guard let first = series.first, let last = series.last else { return 0 }
        return max(0, last.masteredWordCount - first.masteredWordCount)
    }

    func configure(context: ModelContext) {
        guard progressRepository == nil else { return }
        progressRepository = ProgressRepository(context: context)
        reload()
    }

    func reload() {
        guard let progressRepository else { return }
        // 折れ線の開始値を引き継ぐため、期間より少し前のログも読む
        let logs = progressRepository.recentLogs(days: selectedPeriod.days + 7)
        let daily = StudyHistory.series(logs: logs, days: selectedPeriod.days)

        // 集計後の系列（グラフ描画用）と、日次の系列（合計値の算出用）を分けて持つ
        dailySeries = daily
        series = selectedPeriod.aggregatesByWeek ? StudyHistory.weekly(from: daily) : daily

        streak = StudyHistory.currentStreak(logs: progressRepository.logsForStreak())
    }
}
