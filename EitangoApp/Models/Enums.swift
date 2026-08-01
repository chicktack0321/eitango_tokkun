import Foundation

/// 頻出度ランク（過去問での出題頻度グループ）
enum FrequencyRank: String, Codable, CaseIterable, Identifiable {
    case a = "A"
    case b = "B"
    case c = "C"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .a: return "頻出A"
        case .b: return "頻出B"
        case .c: return "頻出C"
        }
    }
}

enum PartOfSpeech: String, Codable, CaseIterable, Identifiable {
    case noun
    case verb
    case adjective
    case adverb
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .noun: return "名詞"
        case .verb: return "動詞"
        case .adjective: return "形容詞"
        case .adverb: return "副詞"
        case .other: return "その他"
        }
    }
}

/// 単語ごとの習熟段階。
///
/// 直近の正誤で反転させるのではなく、間隔反復の習得段階（`UserProgress.reviewBox`）から導く。
/// 1回正解しただけで「覚えた」にしてしまうと、実際には翌日忘れている語まで覚えた扱いになり、
/// 習熟度の表示が学習の実態と乖離して意味を失うため。
enum LearningStatus: String, Codable, CaseIterable, Identifiable {
    /// 一度も出題していない
    case notStudied
    /// 直近で間違えた、または復習期限が過ぎている
    case needsReview
    /// 正解を重ねている途中（復習間隔は1〜3日）
    case learning
    /// 1週間以上の間隔を空けても正解できた
    case memorized

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notStudied: return "未学習"
        case .needsReview: return "要復習"
        case .learning: return "学習中"
        case .memorized: return "覚えた"
        }
    }

    /// この段階に到達する条件。画面上の「iマーク」でそのまま見せる。
    var criteria: String {
        switch self {
        case .notStudied: return "まだ一度も出題されていない単語です。"
        case .needsReview: return "直近で間違えたか、復習の期限が来ている単語です。優先して出題されます。"
        case .learning: return "正解を重ねている途中の単語です。1〜3日の間隔で再出題されます。"
        case .memorized: return "1週間以上あけても正解できた単語です。以後は間隔を広げて確認します。"
        }
    }

    /// 単語帳・習熟度バー・凡例で同じ見た目にするため、記号と色は段階自身に持たせる
    var symbolName: String {
        switch self {
        case .notStudied: return "circle"
        case .needsReview: return "exclamationmark.circle.fill"
        case .learning: return "arrow.triangle.2.circlepath.circle.fill"
        case .memorized: return "checkmark.circle.fill"
        }
    }
}
