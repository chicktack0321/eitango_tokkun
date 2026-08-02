import Foundation

/// 出題できる語彙の範囲を決める権利。
///
/// StoreKit にも UserDefaults にも触れない値型にしてある。
/// 「試用中は全語彙、期間後は基礎と架け橋まで」という線引きは収益に直結し、
/// 間違えても画面上は正常に見えてしまうため、ここだけを取り出してテストできるようにする。
struct AccessRights: Equatable {
    /// 買い切りのアンロックを購入済みか
    var isPurchased: Bool
    /// 初回起動から14日間の試用期間中か
    var isTrialActive: Bool

    static let locked = AccessRights(isPurchased: false, isTrialActive: false)

    var hasFullAccess: Bool { isPurchased || isTrialActive }

    /// 出題（クイズ・タイピング・聞き流し）の対象にできる語彙階層。
    ///
    /// 権利が無くても機能そのものは止めない。止まるのは 2級コア発展語彙（Tier 3）が
    /// 出題対象から外れることだけで、単語帳での閲覧・検索・発音は常に全語できる。
    var availableTiers: Set<VocabularyTier> {
        hasFullAccess ? Set(VocabularyTier.allCases) : [.basic, .bridge]
    }

    /// 画面に出す現在の状態
    var summary: String {
        if isPurchased { return "すべての語彙（購入済み）" }
        if isTrialActive { return "すべての語彙（お試し期間中）" }
        return "基礎・架け橋の語彙"
    }
}
