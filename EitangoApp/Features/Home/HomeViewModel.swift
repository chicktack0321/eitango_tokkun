import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class HomeViewModel {
    private(set) var totalWordCount = 0
    private(set) var summary: ProgressSummary = .empty
    private(set) var todayStudiedCount = 0
    private(set) var todayAccuracy: Double = 0
    /// 復習期限が来ている語の数。学習を再開する動機付けとしてホームに出す。
    private(set) var dueCount = 0
    /// ホームのミニグラフ用（直近1週間）
    private(set) var weeklySeries: [DailyStudy] = []
    /// 連続学習日数
    private(set) var streak = 0

    private var wordRepository: WordRepository?
    private var progressRepository: ProgressRepository?

    var memorizedCount: Int { summary.count(of: .memorized) }
    var needsReviewCount: Int { summary.count(of: .needsReview) }
    var notStudiedCount: Int { summary.count(of: .notStudied) }
    var overallAccuracy: Double { summary.accuracy }

    var masteredFraction: Double {
        totalWordCount == 0 ? 0 : Double(memorizedCount) / Double(totalWordCount)
    }

    func configure(context: ModelContext) {
        guard wordRepository == nil else { return }
        wordRepository = WordRepository(context: context)
        progressRepository = ProgressRepository(context: context)
        reload()
    }

    func reload() {
        guard let wordRepository, let progressRepository else { return }
        totalWordCount = wordRepository.fetchCount()
        summary = progressRepository.summarize()
        dueCount = StudyQueue.dueCount(
            words: wordRepository.fetchStudyPool(),
            progress: progressRepository.allProgress()
        )

        let log = progressRepository.todayLog()
        todayStudiedCount = log?.studiedWordCount ?? 0
        todayAccuracy = log?.accuracy ?? 0

        weeklySeries = StudyHistory.series(logs: progressRepository.recentLogs(days: 7), days: 7)
        streak = StudyHistory.currentStreak(logs: progressRepository.logsForStreak())
    }
}
