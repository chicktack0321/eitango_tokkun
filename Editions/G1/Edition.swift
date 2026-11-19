import Foundation

/// 英検1級エディションの定義。**このファイルだけがターゲット別**で、
/// 共通コード（`EitangoApp/`）はここを `Edition.current` 経由でしか見ない。
///
/// 語彙は `vocab/master.json` の `editions.G1` 配置から生成する
/// （docs/vocab-database-spec.md §3〜§4）。bridge は準1級コアの新規語からの選抜、
/// core は1級専用に書き起こした C1 帯の語でできている。
extension EditionSpec {

    static let current = EditionSpec(
        id: "G1",
        appDisplayName: "英単語特訓",
        gradeDisplayName: "英検®1級",
        // 級ごとに別アプリなので、プロダクトIDにも級を入れる（設計書§6）
        unlockProductID: "com.eitango.g1.unlock.core",
        // 英検は公益財団法人 日本英語検定協会の登録商標。
        // 提携していると誤解させないため、アプリ内とストアの説明文の両方に同じ文言を出す。
        trademarkNotice: """
        英検®は公益財団法人 日本英語検定協会の登録商標です。\
        本アプリは同協会が承認・許諾したものではありません。
        """,
        // プライバシーポリシーはシリーズ共通の1ページ（収集しない・通信しないは全級同じ）。
        // サポートページは語数・級名・課金内容が違うためアプリ別にする（設計書§8）。
        privacyPolicyURL: URL(string: "https://sites.google.com/view/eitango-tokkun/privacy-policy")!,
        supportURL: URL(string: "https://sites.google.com/view/eitango-tokkun/support-g1")!,
        tierDisplayNames: [
            .basic: "基礎",
            .bridge: "準1級帯",
            .core: "1級コア"
        ],
        tierSummaries: [
            .basic: "2級までの既習語。すでに知っている前提の語",
            .bridge: "準1級の得点源の復習。抽象語の土台を固める",
            .core: "1級の得点源。評論・討論で使う高度な語"
        ],
        coreVocabularyName: "1級コア発展語彙",
        paywallTitle: "1級コア語彙の解放",
        coreTierDescription: "1級コア発展語彙（CEFR C1）。評論・討論で使う抽象語や格式語など、1級で実際に問われる領域の語です。",
        nowPlayingAlbumTitle: "英検1級 英単語特訓"
    )
}
