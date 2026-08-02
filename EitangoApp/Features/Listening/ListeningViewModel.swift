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
        // 聞き流しも出題範囲の設定に従う（基礎語彙は既定で流さない）。
        // ただし階層を明示的に選んだときは、その指定を優先する。
        let pool = filter.tier == nil ? wordRepository.fetchStudyPool() : wordRepository.fetchAll()
        let fetched = pool.filter { word in
            (filter.category == nil || word.category == filter.category)
                && (filter.partOfSpeech == nil || word.partOfSpeech == filter.partOfSpeech)
        }
        words = filter.apply(to: fetched, progress: progressRepository.allProgress())
    }
}
