import Foundation
import UIKit

/// 追加する単語の綴りを確認する。
///
/// OS標準の `UITextChecker` を使う。辞書は端末に入っているものをそのまま使うため、
/// 通信も追加データも要らず、「完全オフライン・超軽量」という方針を崩さない。
///
/// 綴りの誤りは**警告であって禁止ではない**。固有名詞や辞書に無い専門語もあるので、
/// 最終的にユーザーがそのまま登録できる余地を残す（判断材料だけ渡す）。
enum SpellChecker {

    enum Result: Equatable {
        /// 辞書に載っている、または判定できる材料がない
        case ok
        /// 空欄
        case empty
        /// 英字以外が混ざっている（日本語入力のまま打ったケースを想定）
        case invalidCharacters
        /// 綴りが辞書に無い。`suggestions` は近い綴りの候補（0件のこともある）
        case misspelled(suggestions: [String])

        var isBlocking: Bool {
            switch self {
            case .empty, .invalidCharacters: return true
            case .ok, .misspelled: return false
            }
        }
    }

    /// 英単語として許す文字。複合語（"take off"）やハイフン・アポストロフィ入りの語を通す。
    private static let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz-' ")

    static func check(_ raw: String) -> Result {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .empty }

        guard text.lowercased().unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return .invalidCharacters
        }

        guard let language = englishLanguage() else {
            // 英語の辞書が入っていない端末では判定できない。
            // ここで弾くと単語を追加できなくなるので、確認は諦めて通す。
            return .ok
        }

        let checker = UITextChecker()
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        let misspelled = checker.rangeOfMisspelledWord(
            in: text,
            range: range,
            startingAt: 0,
            wrap: false,
            language: language
        )
        guard misspelled.location != NSNotFound else { return .ok }

        let guesses = checker.guesses(forWordRange: misspelled, in: text, language: language) ?? []
        // 候補が多すぎると選ぶ手間になるので、上位だけ見せる
        return .misspelled(suggestions: Array(guesses.prefix(5)))
    }

    /// 端末で使える英語の辞書を選ぶ。地域によって en_US / en_GB などが入っている。
    private static func englishLanguage() -> String? {
        let available = UITextChecker.availableLanguages
        if available.contains("en_US") { return "en_US" }
        return available.first { $0.hasPrefix("en") }
    }
}
