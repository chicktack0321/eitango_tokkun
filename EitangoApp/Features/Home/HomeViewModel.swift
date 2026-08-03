import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class HomeViewModel {
    /// 習熟度の集計対象になっている語数（絞り込みを反映する）
    private(set) var totalWordCount = 0
    private(set) var summary: ProgressSummary = .empty
    /// 自分で追加した単語があるか（集計範囲で「自分の単語のみ」を選べるかの判断に使う）
    private(set) var hasUserWords = false
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
    private var userWordRepository: UserWordRepository?

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
        userWordRepository = UserWordRepository(context: context)
        reload()
    }

    /// 習熟度を集計する範囲。3,955語をまとめて見るとバーがほとんど動かず、
    /// 進んでいる実感が得られないため、階層・頻出度・分野で切って見られるようにする。
    var masteryScope = StudySettings.masteryScope {
        didSet {
            guard masteryScope != oldValue else { return }
            StudySettings.masteryScope = masteryScope
            reloadMastery()
        }
    }

    /// 習熟度だけを集計し直す。絞り込みを変えたときは全体を読み直す必要がない。
    func reloadMastery() {
        guard let wordRepository, let progressRepository else { return }

        // 権利に関わらず、持っている語彙全体から絞り込む。
        // 未購入でも「2級コアの習熟度」を見られるほうが、何を買うのかが分かりやすい。
        let words = wordRepository.fetchStudyPool(
            scope: masteryScope,
            availableTiers: Set(VocabularyTier.allCases)
        )
        totalWordCount = words.count
        summary = progressRepository.summarize(words: words)
        hasUserWords = words.contains { $0.source == .user }
            || !(userWordRepository?.all().isEmpty ?? true)
    }

    func reload() {
        guard let wordRepository, let progressRepository else { return }
        reloadMastery()
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
