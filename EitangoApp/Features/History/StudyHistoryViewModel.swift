import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class StudyHistoryViewModel {
    /// グラフの表示期間。端末の幅で無理なく読める粒度として2週間/1か月を用意する。
    enum Period: String, CaseIterable, Identifiable {
        case twoWeeks
        case month

        var id: String { rawValue }

        var days: Int {
            switch self {
            case .twoWeeks: return 14
            case .month: return 30
            }
        }

        var displayName: String {
            switch self {
            case .twoWeeks: return "2週間"
            case .month: return "1か月"
            }
        }
    }

    var selectedPeriod: Period = .twoWeeks {
        didSet { reload() }
    }

    private(set) var series: [DailyStudy] = []
    private(set) var streak = 0

    private var progressRepository: ProgressRepository?

    var totalAttempts: Int { StudyHistory.totalAttempts(in: series) }
    var overallAccuracy: Double { StudyHistory.overallAccuracy(in: series) }
    var studiedDayCount: Int { series.filter(\.didStudy).count }
    var hasAnyRecord: Bool { totalAttempts > 0 }

    func configure(context: ModelContext) {
        guard progressRepository == nil else { return }
        progressRepository = ProgressRepository(context: context)
        reload()
    }

    func reload() {
        guard let progressRepository else { return }
        series = StudyHistory.series(
            logs: progressRepository.recentLogs(days: selectedPeriod.days),
            days: selectedPeriod.days
        )
        streak = StudyHistory.currentStreak(logs: progressRepository.logsForStreak())
    }
}
