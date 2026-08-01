import Foundation
import SwiftData
import Observation

/// 聞き流し対象の単語リストを組み立てる。再生そのものの状態管理は AudioPlaybackManager が持つため、
/// ここでは「どの単語を再生対象にするか（頻出度フィルタ）」だけを扱う。
@Observable
@MainActor
final class ListeningViewModel {
    private(set) var words: [WordMaster] = []
    var selectedCategory: FrequencyRank?

    private var wordRepository: WordRepository?

    var listeningItems: [ListeningItem] {
        words.map { ListeningItem(id: $0.wordId, word: $0.word, meaning: $0.meaning) }
    }

    func configure(context: ModelContext) {
        guard wordRepository == nil else { return }
        wordRepository = WordRepository(context: context)
        reload()
    }

    func reload() {
        guard let wordRepository else { return }
        words = wordRepository.fetch(category: selectedCategory, partOfSpeech: nil)
    }
}
