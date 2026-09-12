import Foundation

/// 英検準2級エディションの定義。**このファイルだけがターゲット別**で、
/// 共通コード（`EitangoApp/`）はここを `Edition.current` 経由でしか見ない。
///
/// 語彙は `vocab/master.json` の `editions.GP2` 配置から生成する
/// （basic 886 / bridge 1,257 / core 1,182。docs/vocab-database-spec.md §3）。
extension EditionSpec {

    static let current = EditionSpec(
        id: "GP2",
        appDisplayName: "英単語特訓",
        gradeDisplayName: "英検®準2級",
        // 級ごとに別アプリなので、プロダクトIDにも級を入れる（設計書§6）
        unlockProductID: "com.eitango.gp2.unlock.core",
        // 英検は公益財団法人 日本英語検定協会の登録商標。
        // 提携していると誤解させないため、アプリ内とストアの説明文の両方に同じ文言を出す。
        trademarkNotice: """
        英検®は公益財団法人 日本英語検定協会の登録商標です。\
        本アプリは同協会が承認・許諾したものではありません。
        """,
        // プライバシーポリシーはシリーズ共通の1ページ（収集しない・通信しないは全級同じ）。
        // サポートページは語数・級名・課金内容が違うためアプリ別にする（設計書§8）。
        privacyPolicyURL: URL(string: "https://sites.google.com/view/eitango-tokkun/privacy-policy")!,
        supportURL: URL(string: "https://sites.google.com/view/eitango-tokkun/support-gp2")!,
        tierDisplayNames: [
            .basic: "基礎",
            .bridge: "架け橋",
            .core: "準2級コア"
        ],
        tierSummaries: [
            .basic: "中学基礎〜4級帯。すでに知っている前提の語",
            .bridge: "3級〜準2級の橋渡し。基本の抽象語と句動詞",
            .core: "準2級の得点源。日常・学校・仕事・社会の語"
        ],
        coreVocabularyName: "準2級コア発展語彙",
        paywallTitle: "準2級コア語彙の解放",
        coreTierDescription: "準2級コア発展語彙（CEFR A2）。日常生活・教育・仕事・社会など、準2級で実際に問われる領域の語です。",
        nowPlayingAlbumTitle: "英検準2級 英単語特訓"
    )
}
