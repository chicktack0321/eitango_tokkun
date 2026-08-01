import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class WordListViewModel {
    private(set) var words: [WordMaster] = []
    private(set) var progressByWordId: [String: UserProgress] = [:]

    /// 絞り込み条件。聞き流し画面と同じ型を共有している。
    var filter = WordFilter()

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
        progressByWordId = progressRepository.allProgress()

        // 頻出度・品詞はDB側の述語で、ステータスと検索語はメモリ上で絞る。
        // ステータスは別テーブル(UserProgress)にあり、検索は大文字小文字と部分一致を扱うため。
        let fetched = wordRepository.fetch(
            category: filter.category,
            partOfSpeech: filter.partOfSpeech
        )
        words = filter.apply(to: fetched, progress: progressByWordId)
    }

    func status(for word: WordMaster) -> LearningStatus {
        progressByWordId[word.wordId]?.status ?? .notStudied
    }
}
