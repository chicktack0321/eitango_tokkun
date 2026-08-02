import XCTest
@testable import EitangoApp

/// 単語追加時の綴りチェックをテストする。
///
/// 判定に使うのはOS標準の辞書なので、収録語そのものを細かく期待するとOSの版で壊れる。
/// ここでは「正しい綴りを弾かない」「明らかな誤りを見逃さない」「入力ミスの種類を
/// 見分けられる」という、UIの分岐に必要な性質だけを確かめる。
final class SpellCheckerTests: XCTestCase {

    func testCommonWordPasses() {
        XCTAssertEqual(SpellChecker.check("opportunity"), .ok)
        XCTAssertEqual(SpellChecker.check("achieve"), .ok)
    }

    func testSurroundingSpacesAreIgnored() {
        XCTAssertEqual(SpellChecker.check("  achieve  "), .ok)
    }

    /// 大文字で入力された語も弾かない
    func testCapitalizedWordPasses() {
        XCTAssertEqual(SpellChecker.check("Achieve"), .ok)
    }

    /// 複合語やハイフン入りの語も追加できる
    func testPhrasesAndHyphenatedWordsPass() {
        XCTAssertEqual(SpellChecker.check("take off"), .ok)
        XCTAssertEqual(SpellChecker.check("well-known"), .ok)
    }

    func testEmptyInputIsReported() {
        XCTAssertEqual(SpellChecker.check(""), .empty)
        XCTAssertEqual(SpellChecker.check("   "), .empty)
    }

    /// 日本語入力のまま打ってしまったケースを、綴り違いとは別に扱う。
    /// 直し方（入力を英字に切り替える）が違うため。
    func testNonAlphabeticInputIsReported() {
        XCTAssertEqual(SpellChecker.check("りんご"), .invalidCharacters)
        XCTAssertEqual(SpellChecker.check("apple2"), .invalidCharacters)
    }

    func testMisspelledWordIsReported() {
        guard case .misspelled = SpellChecker.check("oportunity") else {
            return XCTFail("綴り違いを見逃している")
        }
    }

    /// 綴り違いのときは直す手がかり（候補）を出せること。
    /// どの候補が返るかはOSの辞書次第なので、中身ではなく「候補を提示できる」ことを確かめる。
    func testMisspelledWordOffersSuggestions() {
        guard case .misspelled(let suggestions) = SpellChecker.check("recieve") else {
            return XCTFail("綴り違いを見逃している")
        }
        XCTAssertFalse(suggestions.isEmpty, "直す手がかりが無いと、ユーザーは打ち直すしかない")
    }

    /// UIの分岐（入力し直しを求めるか、警告にとどめるか）が意図通りであること
    func testOnlyInputMistakesBlockSaving() {
        XCTAssertTrue(SpellChecker.Result.empty.isBlocking)
        XCTAssertTrue(SpellChecker.Result.invalidCharacters.isBlocking)
        XCTAssertFalse(SpellChecker.Result.ok.isBlocking)
        XCTAssertFalse(SpellChecker.Result.misspelled(suggestions: []).isBlocking)
    }
}
