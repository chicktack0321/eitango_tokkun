import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class WordListViewModel {
    private(set) var words: [WordMaster] = []
    private(set) var progressByWordId: [String: UserProgress] = [:]

    var selectedCategory: FrequencyRank?
    var selectedPartOfSpeech: PartOfSpeech?

    private var wordRepository: WordRepository?
    private var progressRepository: ProgressRepository?

    /// SwiftDataの ModelContext は Viewの `.task` から渡す（init時点ではまだ利用できないため）
    func configure(context: ModelContext) {
        guard wordRepository == nil else { return }
        wordRepository = WordRepository(context: context)
        progressRepository = ProgressRepository(context: context)
        reload()
    }

    func reload() {
        guard let wordRepository, let progressRepository else { return }
        words = wordRepository.fetch(category: selectedCategory, partOfSpeech: selectedPartOfSpeech)
        progressByWordId = progressRepository.allProgress()
    }

    func status(for word: WordMaster) -> LearningStatus {
        progressByWordId[word.wordId]?.status ?? .notStudied
    }
}
