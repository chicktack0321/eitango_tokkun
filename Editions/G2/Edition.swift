import Foundation

/// 英検2級エディションの定義。**このファイルだけがターゲット別**で、
/// 共通コード（`EitangoApp/`）はここを `Edition.current` 経由でしか見ない。
///
/// 値は公開中の 1.0 の文言をそのまま転記してある。表示文言を変えると
/// UIテストのスクリーンショットが変わるため、変更は意図的に行うこと。
extension EditionSpec {

    static let current = EditionSpec(
        id: "G2",
        appDisplayName: "英単語特訓",
        gradeDisplayName: "英検®2級",
        // 公開済みのプロダクトID。変えると購入の復元が壊れる
        unlockProductID: "com.eitango.app.unlock.grade2",
        // 英検は公益財団法人 日本英語検定協会の登録商標。
        // 提携していると誤解させないため、アプリ内とストアの説明文の両方に同じ文言を出す。
        trademarkNotice: """
        英検®は公益財団法人 日本英語検定協会の登録商標です。\
        本アプリは同協会が承認・許諾したものではありません。
        """,
        // App Store Connect にも同じURLを登録する（プライバシーポリシーは全アプリで必須）
        privacyPolicyURL: URL(string: "https://sites.google.com/view/eitango-tokkun/privacy-policy")!,
        supportURL: URL(string: "https://sites.google.com/view/eitango-tokkun/support")!,
        tierDisplayNames: [
            .basic: "基礎",
            .bridge: "架け橋",
            .core: "2級コア"
        ],
        tierSummaries: [
            .basic: "中学〜高校基礎。すでに知っている前提の語",
            .bridge: "準2級〜2級の橋渡し。抽象語の初歩と句動詞",
            .core: "2級の得点源。環境・技術・医療・経済・社会の語"
        ],
        coreVocabularyName: "2級コア発展語彙",
        paywallTitle: "2級コア語彙の解放",
        coreTierDescription: "2級コア発展語彙（CEFR B1）。環境・科学技術・医療・経済・社会など、2級で実際に問われる領域の語です。",
        nowPlayingAlbumTitle: "英検2級 英単語特訓"
    )
}
