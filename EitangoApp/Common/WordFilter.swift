import Foundation

/// 単語の絞り込み条件。単語帳と聞き流しで同じ軸を使えるよう共通化している。
///
/// 頻出度・品詞は `WordMaster`、学習ステータスは `UserProgress` と参照先が分かれるため、
/// DB側の述語だけでは完結せず、ここでまとめて適用する。
struct WordFilter: Equatable {
    var category: FrequencyRank?
    var partOfSpeech: PartOfSpeech?
    var status: LearningStatus?
    /// 語彙階層。5,000語を一列に並べても目的の層に辿り着けないため、絞り込みの主軸になる。
    var tier: VocabularyTier?
    /// 出題トピック。苦手な分野だけを回すのに使う。
    var domain: VocabularyDomain?
    var keyword: String = ""

    var isEmpty: Bool {
        category == nil && partOfSpeech == nil && status == nil && tier == nil && domain == nil
            && keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 頻出度・品詞で取得済みの配列に、ステータスと検索語を適用する
    func apply(
        to words: [WordMaster],
        progress: [String: UserProgress],
        now: Date = .now
    ) -> [WordMaster] {
        var result = words

        if let tier {
            result = result.filter { $0.tier == tier }
        }
        if let domain {
            result = result.filter { $0.domain == domain }
        }
        if let status {
            result = result.filter { word in
                let current = progress[word.wordId]?.status(at: now) ?? .notStudied
                return current == status
            }
        }

        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            result = result.filter {
                $0.word.localizedCaseInsensitiveContains(trimmed) || $0.meaning.contains(trimmed)
            }
        }

        return result
    }
}
