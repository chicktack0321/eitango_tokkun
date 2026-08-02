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

/// 語彙階層。
///
/// 2級の語彙は単一の頻度分布ではなく、既習の基礎層と、試験で直接問われる発展層という
/// 二重構造になっている。同じ土俵で出題すると、既に知っている基礎語ばかりが並んで
/// 学習時間が薄まるため、階層を属性として持ち、出題の主対象を発展層に寄せる。
enum VocabularyTier: Int, Codable, CaseIterable, Identifiable {
    /// 中学〜高校基礎（CEFR A1–A2）。文脈理解の前提となる既習語彙
    case basic = 1
    /// 準2級・2級の架け橋（CEFR A2+）。抽象概念の初歩と基本句動詞
    case bridge = 2
    /// 2級コア発展語彙（CEFR B1）。筆記大問1の直接的な得点源
    case core = 3

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .basic: return "基礎"
        case .bridge: return "架け橋"
        case .core: return "2級コア"
        }
    }

    var summary: String {
        switch self {
        case .basic: return "中学〜高校基礎。すでに知っている前提の語"
        case .bridge: return "準2級〜2級の橋渡し。抽象語の初歩と句動詞"
        case .core: return "2級の得点源。環境・技術・医療・経済・社会の語"
        }
    }
}

/// 語彙のドメイン（使用文脈）。
/// 2級では出題トピックが日常会話から社会的・アカデミックな領域へ移るため、
/// 苦手な話題だけを集中的に回せるようにする。
enum VocabularyDomain: String, Codable, CaseIterable, Identifiable {
    case daily
    case environment
    case technology
    case health
    case business
    case society
    case education
    case general

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily: return "日常生活"
        case .environment: return "環境"
        case .technology: return "科学技術"
        case .health: return "医療・健康"
        case .business: return "経済・ビジネス"
        case .society: return "社会"
        case .education: return "教育・学術"
        case .general: return "一般"
        }
    }
}

/// 単語の出どころ。
///
/// 同梱JSONの単語は改訂のたびに総入れ替えされるが、ユーザーが自分で追加した単語は
/// そこで消えてはいけない。両者を区別できないと、アプリ更新で自作の単語が失われる。
enum WordSource: String, Codable {
    case bundled
    case user
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
