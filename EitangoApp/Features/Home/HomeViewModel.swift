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
    var notStudiedCount: Int { statusCounts[.notStudied] ?? 0 }
    var overallAccuracy: Double { summary.accuracy }

    /// 習熟度の内訳。
    ///
    /// 一度も解いていない語には進捗の行が無い（語彙が数千あるため、使わない行を
    /// 同じ数だけ作らない方針）。そのぶんの「未学習」は行を数えても出てこないので、
    /// 全語数から学習済みの語数を引いて求める。
    var statusCounts: [LearningStatus: Int] {
        var counts = summary.statusCounts
        let studied = LearningStatus.allCases
            .filter { $0 != .notStudied }
            .reduce(0) { $0 + (counts[$1] ?? 0) }
        counts[.notStudied] = max(0, totalWordCount - studied)
        return counts
    }

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
