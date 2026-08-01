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
    /// 学習ステータスでの絞り込み。「要復習だけ見たい」が単語帳で一番したい操作なので用意する。
    var selectedStatus: LearningStatus?
    /// 英単語・日本語訳のどちらにも当たる検索文字列
    var searchText: String = ""

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
        var result = wordRepository.fetch(category: selectedCategory, partOfSpeech: selectedPartOfSpeech)

        if let selectedStatus {
            result = result.filter { status(for: $0) == selectedStatus }
        }

        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !keyword.isEmpty {
            result = result.filter {
                $0.word.localizedCaseInsensitiveContains(keyword) || $0.meaning.contains(keyword)
            }
        }

        words = result
    }

    func status(for word: WordMaster) -> LearningStatus {
        progressByWordId[word.wordId]?.status ?? .notStudied
    }
}
