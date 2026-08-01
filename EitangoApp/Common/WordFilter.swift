import Foundation

/// 単語の絞り込み条件。単語帳と聞き流しで同じ軸を使えるよう共通化している。
///
/// 頻出度・品詞は `WordMaster`、学習ステータスは `UserProgress` と参照先が分かれるため、
/// DB側の述語だけでは完結せず、ここでまとめて適用する。
struct WordFilter: Equatable {
    var category: FrequencyRank?
    var partOfSpeech: PartOfSpeech?
    var status: LearningStatus?
    var keyword: String = ""

    var isEmpty: Bool {
        category == nil && partOfSpeech == nil && status == nil
            && keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 頻出度・品詞で取得済みの配列に、ステータスと検索語を適用する
    func apply(
        to words: [WordMaster],
        progress: [String: UserProgress],
        now: Date = .now
    ) -> [WordMaster] {
        var result = words

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
