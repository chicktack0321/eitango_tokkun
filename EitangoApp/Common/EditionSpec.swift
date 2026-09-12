import Foundation

/// 級（エディション）ごとに変わる値の定義。
///
/// 級別は別アプリとして出す方針のため、「2級」といった級固有の文言が共通コードに
/// 残っていると、横展開のたびに置き換え漏れが起きる。共通コードは級を知らず、
/// `Edition.current` だけを見る。実体は `Editions/<ID>/Edition.swift` にあり、
/// ターゲットごとにそのファイルだけを差し替える。
///
/// 実行時にJSONを読む方式にしていないのは、値の欠落やタイプミスをビルドで捕まえるため
/// （起動時のコストも増やさない）。
struct EditionSpec: Sendable {

    /// エディション識別子（"G2" / "GP2" など）。wordId のプレフィクスにも対応する
    let id: String

    /// アプリ名。ホーム画面のアイコン下は Info.plist の CFBundleDisplayName が担う
    let appDisplayName: String

    /// 画面に出す級の表記。商標なので®を付ける
    let gradeDisplayName: String

    /// App内課金のプロダクトID
    let unlockProductID: String

    /// 商標の帰属表示。アプリ内とストアの説明文に同じ文言を出す
    let trademarkNotice: String

    let privacyPolicyURL: URL
    let supportURL: URL

    /// 階層の表示名。全 `VocabularyTier` を埋めること（`EditionSpecTests` が検証する）
    let tierDisplayNames: [VocabularyTier: String]

    /// 階層の説明文。同上
    let tierSummaries: [VocabularyTier: String]

    /// 課金対象の語彙帯の呼び名。ホームとクイズのロック案内を組み立てるのに使う
    let coreVocabularyName: String

    /// 購入画面のタイトル
    let paywallTitle: String

    /// 購入画面で「何が解放されるか」を説明する文
    let coreTierDescription: String

    /// ロック画面・コントロールセンターに出るアルバム名
    let nowPlayingAlbumTitle: String

    /// 同梱する語彙データ（拡張子を除いたファイル名）。
    /// ターゲットごとに別のファイルを同梱するため、名前は全エディション共通でよい。
    static let seedResourceName = "word_master_seed"
}

/// 共通コードからの参照を短く書くための別名。
typealias Edition = EditionSpec

extension EditionSpec {

    /// 階層の表示名。エディション定義に無い階層は共通の既定名で埋める
    func displayName(for tier: VocabularyTier) -> String {
        tierDisplayNames[tier] ?? Self.defaultTierDisplayNames[tier] ?? ""
    }

    /// 階層の説明文。定義が無ければ空文字（説明は省いても画面が壊れない位置にしか出さない）
    func summary(for tier: VocabularyTier) -> String {
        tierSummaries[tier] ?? ""
    }

    /// 級名を含まない中立的な既定値。エディション定義の取りこぼしで画面が空欄になるのを防ぐ
    private static let defaultTierDisplayNames: [VocabularyTier: String] = [
        .basic: "基礎",
        .bridge: "架け橋",
        .core: "コア"
    ]
}
