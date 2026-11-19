import Foundation

/// 英検準1級エディションの定義。**このファイルだけがターゲット別**で、
/// 共通コード（`EitangoApp/`）はここを `Edition.current` 経由でしか見ない。
///
/// 語彙は `vocab/master.json` の `editions.GP1` 配置から生成する
/// （basic 2,681 / bridge 697 / core 1,491。docs/vocab-database-spec.md §3〜§4）。
/// core は2級コアの非選抜745語（実質B2帯の語）と、準1級専用の新規746語でできている。
extension EditionSpec {

    static let current = EditionSpec(
        id: "GP1",
        appDisplayName: "英単語特訓",
        gradeDisplayName: "英検®準1級",
        // 級ごとに別アプリなので、プロダクトIDにも級を入れる（設計書§6）
        unlockProductID: "com.eitango.gp1.unlock.core",
        // 英検は公益財団法人 日本英語検定協会の登録商標。
        // 提携していると誤解させないため、アプリ内とストアの説明文の両方に同じ文言を出す。
        trademarkNotice: """
        英検®は公益財団法人 日本英語検定協会の登録商標です。\
        本アプリは同協会が承認・許諾したものではありません。
        """,
        // プライバシーポリシーはシリーズ共通の1ページ（収集しない・通信しないは全級同じ）。
        // サポートページは語数・級名・課金内容が違うためアプリ別にする（設計書§8）。
        privacyPolicyURL: URL(string: "https://sites.google.com/view/eitango-tokkun/privacy-policy")!,
        supportURL: URL(string: "https://sites.google.com/view/eitango-tokkun/support-gp1")!,
        tierDisplayNames: [
            .basic: "基礎",
            .bridge: "2級帯",
            .core: "準1級コア"
        ],
        tierSummaries: [
            .basic: "3級〜2級の基礎。すでに知っている前提の語",
            .bridge: "2級の得点源の復習。取りこぼしを埋める",
            .core: "準1級の得点源。社会・科学・経済・心理の抽象語"
        ],
        coreVocabularyName: "準1級コア発展語彙",
        paywallTitle: "準1級コア語彙の解放",
        coreTierDescription: "準1級コア発展語彙（CEFR B2）。社会・政治・科学技術・経済・医療など、準1級で実際に問われる領域の語です。",
        nowPlayingAlbumTitle: "英検準1級 英単語特訓"
    )
}
