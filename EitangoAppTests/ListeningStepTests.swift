import XCTest
@testable import EitangoApp

/// 聞き流しの読み上げ順をテストする。
///
/// 順番が崩れても音は鳴り続けるので画面上は正常に見え、
/// 「例文が1回しか流れない」「訳が先に読まれる」といった形で静かに壊れるため、流れを直接押さえる。
final class ListeningStepTests: XCTestCase {

    private let pauses = ListeningPauses()

    private func item(example: String, translation: String = "", explanation: String = "") -> ListeningItem {
        ListeningItem(
            id: "TEST_ABANDON", word: "abandon", meaning: "捨てる",
            example: example, exampleTranslation: translation, explanation: explanation
        )
    }

    private func fullItem() -> ListeningItem {
        item(
            example: "They abandoned the plan.",
            translation: "彼らはその計画を断念した。",
            explanation: "途中で投げ出す、見捨てるという意味合いです。"
        )
    }

    func testWordModeReadsWordThenMeaning() {
        let steps = ListeningStep.steps(for: fullItem(), mode: .word, pauses: pauses)
        XCTAssertEqual(steps.map(\.kind), [.word, .meaning])
        XCTAssertEqual(steps.map(\.languageCode), ["en-US", "ja-JP"])
    }

    /// 解説は画面に出すだけで読み上げない
    func testExampleModeReadsExampleTwiceThenTranslationWordAndMeaning() {
        let steps = ListeningStep.steps(for: fullItem(), mode: .example, pauses: pauses)
        XCTAssertEqual(steps.map(\.kind), [.example, .example, .exampleTranslation, .word, .meaning])
        XCTAssertEqual(steps.map(\.text), [
            "They abandoned the plan.", "They abandoned the plan.", "彼らはその計画を断念した。",
            "abandon", "捨てる"
        ])
        XCTAssertEqual(steps.map(\.languageCode), ["en-US", "en-US", "ja-JP", "en-US", "ja-JP"])
    }

    func testExampleModePausesBetweenParts() {
        let steps = ListeningStep.steps(for: fullItem(), mode: .example, pauses: pauses)
        XCTAssertEqual(steps.map(\.postDelay), [
            pauses.betweenExamples, pauses.exampleToTranslation, pauses.exampleToWord,
            pauses.wordToMeaning, pauses.betweenItems
        ])
    }

    /// ユーザーが追加した語には和訳が無い。無音の発話を挟まず、その部分だけ飛ばす
    func testExampleModeSkipsMissingTranslation() {
        let steps = ListeningStep.steps(for: item(example: "They abandoned the plan.", translation: " ", explanation: ""), mode: .example, pauses: pauses)
        XCTAssertEqual(steps.map(\.kind), [.example, .example, .word, .meaning])
        XCTAssertEqual(steps.map(\.postDelay), [
            pauses.betweenExamples, pauses.exampleToWord, pauses.wordToMeaning, pauses.betweenItems
        ])
    }

    /// 例文の無い語で無音の発話を作ると、その間だけ止まったように聞こえる
    func testExampleModeFallsBackToWordWhenExampleIsBlank() {
        for blank in ["", "   ", "\n"] {
            let steps = ListeningStep.steps(
                for: item(example: blank, translation: "訳", explanation: "解説"), mode: .example, pauses: pauses
            )
            XCTAssertEqual(steps.map(\.kind), [.word, .meaning], "例文 \(blank.debugDescription)")
        }
    }
}
