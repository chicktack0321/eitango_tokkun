import Foundation

/// 英検3級エディションの定義。**このファイルだけがターゲット別**で、
/// 共通コード（`EitangoApp/`）はここを `Edition.current` 経由でしか見ない。
///
/// **課金なし**（`unlockProductID` が nil）。3級の語彙帯は公開中の2級アプリの基礎帯に
/// 構造的にほぼ全部含まれており、「3級アプリを買う理由になる語」を作れない
/// （docs/vocab-database-spec.md §4「無料エディション」）。上位級への入口として無料で出す。
///
/// 語彙は `vocab/master.json` の `editions.G3` 配置から生成する
/// （basic 297 / bridge 589 / core 626）。
extension EditionSpec {

    static let current = EditionSpec(
        id: "G3",
        appDisplayName: "英単語特訓",
        gradeDisplayName: "英検®3級",
        unlockProductID: nil,
        // 英検は公益財団法人 日本英語検定協会の登録商標。
        // 提携していると誤解させないため、アプリ内とストアの説明文の両方に同じ文言を出す。
        trademarkNotice: """
        英検®は公益財団法人 日本英語検定協会の登録商標です。\
        本アプリは同協会が承認・許諾したものではありません。
        """,
        // プライバシーポリシーはシリーズ共通の1ページ（収集しない・通信しないは全級同じ）。
        // サポートページは語数・級名が違うためアプリ別にする（設計書§8）。
        privacyPolicyURL: URL(string: "https://sites.google.com/view/eitango-tokkun/privacy-policy")!,
        supportURL: URL(string: "https://sites.google.com/view/eitango-tokkun/support-g3")!,
        tierDisplayNames: [
            .basic: "基礎",
            .bridge: "4級帯",
            .core: "3級コア"
        ],
        tierSummaries: [
            .basic: "5級以下。すでに知っている前提の語",
            .bridge: "4級帯。身のまわりの語と基本の動作",
            .core: "3級の得点源。学校生活・社会・気持ちを表す語"
        ],
        coreVocabularyName: "3級コア語彙",
        // 課金が無いので購入画面は出ないが、型としては値が要る
        paywallTitle: "3級コア語彙",
        coreTierDescription: "3級コア語彙（CEFR A1+〜A2）。学校生活・社会・気持ちを表す語など、3級で実際に問われる領域の語です。",
        nowPlayingAlbumTitle: "英検3級 英単語特訓"
    )
}
