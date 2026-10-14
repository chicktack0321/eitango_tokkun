import XCTest
@testable import EitangoApp

/// 聞き流しの読み上げ順をテストする。
///
/// 順番が崩れても音は鳴り続けるので画面上は正常に見え、
/// 「例文が1回しか流れない」「訳が先に読まれる」といった形で静かに壊れるため、流れを直接押さえる。
final class ListeningStepTests: XCTestCase {

    private let pauses = ListeningPauses()

    private func item(example: String) -> ListeningItem {
        ListeningItem(id: "TEST_ABANDON", word: "abandon", meaning: "捨てる", example: example)
    }

    func testWordModeReadsWordThenMeaning() {
        let steps = ListeningStep.steps(for: item(example: "They abandoned the plan."), mode: .word, pauses: pauses)
        XCTAssertEqual(steps.map(\.kind), [.word, .meaning])
        XCTAssertEqual(steps.map(\.languageCode), ["en-US", "ja-JP"])
    }

    func testExampleModeReadsExampleTwiceThenWordAndMeaning() {
        let steps = ListeningStep.steps(for: item(example: "They abandoned the plan."), mode: .example, pauses: pauses)
        XCTAssertEqual(steps.map(\.kind), [.example, .example, .word, .meaning])
        XCTAssertEqual(steps.map(\.text), ["They abandoned the plan.", "They abandoned the plan.", "abandon", "捨てる"])
        XCTAssertEqual(steps.map(\.languageCode), ["en-US", "en-US", "en-US", "ja-JP"])
    }

    func testExampleModePausesBetweenParts() {
        let steps = ListeningStep.steps(for: item(example: "They abandoned the plan."), mode: .example, pauses: pauses)
        XCTAssertEqual(steps.map(\.postDelay), [
            pauses.betweenExamples, pauses.exampleToWord, pauses.wordToMeaning, pauses.betweenItems
        ])
    }

    /// 例文の無い語で無音の発話を作ると、その間だけ止まったように聞こえる
    func testExampleModeFallsBackToWordWhenExampleIsBlank() {
        for blank in ["", "   ", "\n"] {
            let steps = ListeningStep.steps(for: item(example: blank), mode: .example, pauses: pauses)
            XCTAssertEqual(steps.map(\.kind), [.word, .meaning], "例文 \(blank.debugDescription)")
        }
    }
}
