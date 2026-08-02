import Foundation

/// 出題範囲の設定。
///
/// 2級の語彙5,000語のうち大半は中学〜高校基礎の既習語で、そのまま同じ確率で出すと
/// 知っている語ばかりが並んで、試験で問われる発展語彙に時間を割けなくなる。
/// そこで基礎層は既定で出題対象から外し、必要な人だけが戻せるようにする。
///
/// 画面（View）だけでなく ViewModel からも読むため、@AppStorage ではなく
/// UserDefaults を直接扱うこの型に集約している。
enum StudySettings {
    private static let includesBasicTierKey = "includesBasicTier"

    /// 基礎語彙（Tier 1）も出題するか。既定は false。
    static var includesBasicTier: Bool {
        get { UserDefaults.standard.object(forKey: includesBasicTierKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: includesBasicTierKey) }
    }

    /// 出題対象に含める語彙階層
    static var studyTiers: Set<VocabularyTier> {
        includesBasicTier ? Set(VocabularyTier.allCases) : [.bridge, .core]
    }
}
