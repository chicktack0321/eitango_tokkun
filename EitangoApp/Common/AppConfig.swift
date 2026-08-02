import Foundation

/// 級に依存する値と、外部に公開しているURLの置き場所。
///
/// 準2級・準1級は別アプリとして出す方針のため、級ごとに変わる値が
/// コードのあちこちに散っていると横展開のたびに取りこぼす。ここ1か所と
/// `data/` の語彙ファイルを差し替えれば別の級を出せる状態にしておく。
enum AppConfig {

    // MARK: - 級

    /// 画面に出す級の表記。商標なので®を付ける
    static let gradeDisplayName = "英検®2級"

    /// アプリ名（ホーム画面のアイコン下は Info.plist の CFBundleDisplayName が担う）
    static let appDisplayName = "英単語特訓"

    /// 同梱する語彙データ（拡張子を除いたファイル名）
    static let seedResourceName = "word_master_seed"

    /// App内課金のプロダクトID。級ごとに別アプリなので級名を含める
    static let unlockProductID = "com.eitango.app.unlock.grade2"

    // MARK: - 商標

    /// 英検は公益財団法人 日本英語検定協会の登録商標。
    /// 提携していると誤解させないため、アプリ内とストアの説明文の両方に同じ文言を出す。
    static let trademarkNotice = """
    英検®は公益財団法人 日本英語検定協会の登録商標です。\
    本アプリは同協会が承認・許諾したものではありません。
    """

    // MARK: - 公開ページ

    /// App Store Connect にも同じURLを登録する（プライバシーポリシーは全アプリで必須）
    static let privacyPolicyURL = URL(string: "https://chicktack0321.github.io/eitango_tokkun/privacy.html")!
    static let supportURL = URL(string: "https://chicktack0321.github.io/eitango_tokkun/support.html")!
}
