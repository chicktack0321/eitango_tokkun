import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class HomeViewModel {
    private(set) var totalWordCount = 0
    private(set) var statusCounts: [LearningStatus: Int] = [:]
    private(set) var todayStudiedCount = 0
    private(set) var todayAccuracy: Double = 0
    private(set) var overallAccuracy: Double = 0

    private var wordRepository: WordRepository?
    private var progressRepository: ProgressRepository?

    var memorizedCount: Int { statusCounts[.memorized] ?? 0 }
    var needsReviewCount: Int { statusCounts[.needsReview] ?? 0 }
    var notStudiedCount: Int { statusCounts[.notStudied] ?? 0 }

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
        statusCounts = progressRepository.statusBreakdown()
        overallAccuracy = progressRepository.overallAccuracy()

        let log = progressRepository.todayLog()
        todayStudiedCount = log?.studiedWordCount ?? 0
        todayAccuracy = log?.accuracy ?? 0
    }
}
