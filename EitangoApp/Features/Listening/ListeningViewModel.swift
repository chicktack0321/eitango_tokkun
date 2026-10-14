import Foundation
import SwiftData
import Observation

/// 聞き流し対象の単語リストを組み立てる。再生そのものの状態管理は AudioPlaybackManager が持つため、
/// ここでは「どの単語を再生対象にするか」だけを扱う。
@Observable
@MainActor
final class ListeningViewModel {
    private(set) var words: [WordMaster] = []

    var mode: ListeningMode = .word

    /// 実際に流す語。例文モードでは例文のある語だけにする。
    /// 例文の無い語を混ぜると、その語だけ単語モードと同じ流れになり、聞いていてリズムが崩れるため。
    var playbackWords: [WordMaster] {
        switch mode {
        case .word: return words
        case .example: return words.filter { !$0.example.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
    }

    /// 絞り込み条件は単語帳と同じ軸（頻出度・品詞・学習ステータス）を使う。
    /// 「要復習の語だけ流し続ける」ができないと、聞き流しが復習の役に立たないため。
    var filter = WordFilter() {
        didSet { if filter != oldValue { reload() } }
    }

    private var wordRepository: WordRepository?
    private var progressRepository: ProgressRepository?

    /// 再生を始めるたびに並べ替えた一覧を作る。
    ///
    /// 単語帳と同じアルファベット順で流すと、毎回 a から始まって前半ばかり聞くことになり、
    /// 後ろの語にいつまでも触れられない。停止して掛け直すたびに順番を変える。
    /// 一時停止からの再開では作り直さないので、聞いている途中で並びが変わることはない。
    func makePlaybackItems() -> [ListeningItem] {
        playbackWords.shuffled().map {
            ListeningItem(id: $0.wordId, word: $0.word, meaning: $0.meaning, example: $0.example)
        }
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
