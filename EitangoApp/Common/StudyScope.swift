import Foundation

/// 出題・集計の対象範囲。
///
/// 4択クイズとタイピングの出題範囲、およびホームの習熟度の内訳で共有する。
/// 3,955語をひとまとめに扱うと、習熟度のバーはほとんど動かず、
/// 出題も分野が散らばって「いま何を潰しているのか」が分からなくなる。
/// 範囲を狭められることが、進んでいる実感と苦手分野の攻略の両方に効く。
struct StudyScope: Equatable, Codable {
    /// nil は「おまかせ」。基礎（既習）を除いた範囲になる
    var tier: VocabularyTier?
    var category: FrequencyRank?
    var domain: VocabularyDomain?
    /// 自分で追加した単語だけを対象にする。指定すると他の条件は無視する
    var onlyUserWords: Bool = false

    static let `default` = StudyScope()

    /// 階層を指定していないときに出題する範囲。基礎語彙は既習の前提で外す
    static let studyDefaultTiers: Set<VocabularyTier> = [.bridge, .core]
    /// 階層を指定していないときに集計する範囲。習熟度は持っている語彙全体で見る
    static let allTiers: Set<VocabularyTier> = Set(VocabularyTier.allCases)

    var isDefault: Bool { self == .default }

    /// 実際に対象とする階層。購入・試用で使える範囲と掛け合わせる。
    ///
    /// - Parameter unspecified: 階層を選んでいないときに何を対象とするか。
    ///   出題では既習の基礎を外すのが既定だが、習熟度の集計では全体を見たい。
    ///   同じ「未指定」でも意味が違うので、呼び出し側に決めさせる。
    func tiers(
        availableTiers: Set<VocabularyTier>,
        unspecified: Set<VocabularyTier>
    ) -> Set<VocabularyTier> {
        let selected: Set<VocabularyTier> = tier.map { [$0] } ?? unspecified
        return selected.intersection(availableTiers)
    }

    /// 画面に出す1行の説明。指定した条件だけを並べる
    var summary: String {
        if onlyUserWords { return "自分で追加した単語のみ" }
        var parts: [String] = []
        if let tier { parts.append(tier.displayName) }
        if let category { parts.append(category.displayName) }
        if let domain { parts.append(domain.displayName) }
        return parts.isEmpty ? "すべて" : parts.joined(separator: " / ")
    }

    /// この語が範囲に入るか。
    /// 自分で追加した単語は、階層や分野の指定に関わらず常に対象にする
    /// （自分で入れた語が出てこないのは、どんな理由であれ意図に反する）。
    func contains(
        _ word: WordMaster,
        availableTiers: Set<VocabularyTier>,
        unspecified: Set<VocabularyTier>
    ) -> Bool {
        if onlyUserWords { return word.source == .user }
        if word.source == .user { return true }
        guard tiers(availableTiers: availableTiers, unspecified: unspecified).contains(word.tier) else {
            return false
        }
        if let category, word.category != category { return false }
        if let domain, word.domain != domain { return false }
        return true
    }
}
