import Foundation
import SwiftData
import Observation

/// 聞き流し対象の単語リストを組み立てる。再生そのものの状態管理は AudioPlaybackManager が持つため、
/// ここでは「どの単語を再生対象にするか」だけを扱う。
@Observable
@MainActor
final class ListeningViewModel {
    private(set) var words: [WordMaster] = []

    /// 絞り込み条件は単語帳と同じ軸（頻出度・品詞・学習ステータス）を使う。
    /// 「要復習の語だけ流し続ける」ができないと、聞き流しが復習の役に立たないため。
    var filter = WordFilter() {
        didSet { if filter != oldValue { reload() } }
    }

    private var wordRepository: WordRepository?
    private var progressRepository: ProgressRepository?

    var listeningItems: [ListeningItem] {
        words.map { ListeningItem(id: $0.wordId, word: $0.word, meaning: $0.meaning) }
    }

    func configure(context: ModelContext) {
        guard wordRepository == nil else { return }
        wordRepository = WordRepository(context: context)
        progressRepository = ProgressRepository(context: context)
        reload()
    }

    func reload() {
        guard let wordRepository, let progressRepository else { return }
        let fetched = wordRepository.fetch(
            category: filter.category,
            partOfSpeech: filter.partOfSpeech
        )
        words = filter.apply(to: fetched, progress: progressRepository.allProgress())
    }
}
