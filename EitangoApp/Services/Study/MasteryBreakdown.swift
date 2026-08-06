import Foundation

/// 「覚えた」語数を集計範囲で絞れるようにするための内訳。
///
/// 習熟の推移は日ごとのスナップショットでしか残せない（`UserProgress` は現在の状態しか持たず、
/// 過去に遡って再計算できない）。合計値だけを焼いていると後から階層や分野で分けられないため、
/// 「階層×頻出度×分野」のセルごとに数えて保存する。
/// 単一軸の合計を持つ方式では「基礎かつA」のような組み合わせを復元できない。
enum MasteryBreakdown {
    /// 自分で追加した語のキー。階層や分野の指定に関わらず常に対象になるため、
    /// セルに混ぜず独立させる（`StudyScope.contains` の扱いと揃えている）。
    static let userWordsKey = "user"

    static func key(for word: WordMaster) -> String {
        guard word.source != .user else { return userWordsKey }
        return "\(word.tier.rawValue)|\(word.category.rawValue)|\(word.domain.rawValue)"
    }

    /// 内訳から、指定した範囲に入る語数を合計する
    static func count(in breakdown: [String: Int], scope: StudyScope) -> Int {
        breakdown.reduce(into: 0) { total, entry in
            if matches(key: entry.key, scope: scope) { total += entry.value }
        }
    }

    private static func matches(key: String, scope: StudyScope) -> Bool {
        // 自分で追加した語は、範囲をどう指定していても対象に含める
        if key == userWordsKey { return true }
        if scope.onlyUserWords { return false }

        let parts = key.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count == 3, let tierRaw = Int(parts[0]), let tier = VocabularyTier(rawValue: tierRaw) else {
            return false
        }
        if let selected = scope.tier, selected != tier { return false }
        if let category = scope.category, category.rawValue != String(parts[1]) { return false }
        if let domain = scope.domain, domain.rawValue != String(parts[2]) { return false }
        return true
    }
}

/// ある時点で「覚えた」段階にある語の数と、その内訳
struct MasterySnapshot: Equatable {
    var total: Int
    var breakdown: [String: Int]

    static let empty = MasterySnapshot(total: 0, breakdown: [:])

    func count(scope: StudyScope) -> Int {
        scope.isDefault ? total : MasteryBreakdown.count(in: breakdown, scope: scope)
    }
}
