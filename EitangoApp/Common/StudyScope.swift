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

    /// 既定で出題する階層。基礎語彙は既習の前提で外す
    static let defaultTiers: Set<VocabularyTier> = [.bridge, .core]

    var isDefault: Bool { self == .default }

    /// 実際に出題する階層。購入・試用で使える範囲と掛け合わせる
    func tiers(availableTiers: Set<VocabularyTier>) -> Set<VocabularyTier> {
        let selected: Set<VocabularyTier> = tier.map { [$0] } ?? Self.defaultTiers
        return selected.intersection(availableTiers)
    }

    /// 画面に出す1行の説明
    var summary: String {
        if onlyUserWords { return "自分で追加した単語のみ" }
        var parts: [String] = [tier?.displayName ?? "おまかせ"]
        if let category { parts.append(category.displayName) }
        if let domain { parts.append(domain.displayName) }
        return parts.joined(separator: " / ")
    }

    /// この語が範囲に入るか。
    /// 自分で追加した単語は、階層や分野の指定に関わらず常に対象にする
    /// （自分で入れた語が出てこないのは、どんな理由であれ意図に反する）。
    func contains(_ word: WordMaster, availableTiers: Set<VocabularyTier>) -> Bool {
        if onlyUserWords { return word.source == .user }
        if word.source == .user { return true }
        guard tiers(availableTiers: availableTiers).contains(word.tier) else { return false }
        if let category, word.category != category { return false }
        if let domain, word.domain != domain { return false }
        return true
    }
}
