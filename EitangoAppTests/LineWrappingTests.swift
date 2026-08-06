import XCTest
@testable import EitangoApp

/// タイピングの単語表示の折り返しをテストする。
///
/// 出題語はランダムなので、長い語が画面に出るかどうかは実行のたびに変わる。
/// 文字が重なって読めなくなる不具合は目視でしか気付けなかったため、
/// 折り返しの判断だけを純粋関数にしてここで押さえる。
final class LineWrappingTests: XCTestCase {

    /// 40ptのモノスペースでの1文字ぶんの実測に近い値
    private let charWidth: CGFloat = 24
    private let spacing: CGFloat = 1

    private func rows(_ count: Int, maxWidth: CGFloat) -> [[Int]] {
        LineWrapping.rows(
            widths: Array(repeating: charWidth, count: count),
            maxWidth: maxWidth,
            spacing: spacing
        )
    }

    func testEmptyInputProducesNoRows() {
        XCTAssertTrue(LineWrapping.rows(widths: [], maxWidth: 300, spacing: spacing).isEmpty)
    }

    func testShortWordStaysOnOneLine() {
        XCTAssertEqual(rows(8, maxWidth: 311), [Array(0..<8)])
    }

    /// 収録語の最長は23文字（artificial intelligence）。
    /// iPhone SE の単語カードの内寸（約311pt）では1行に入らない。
    func testLongestWordWrapsIntoTwoLines() {
        let result = rows(23, maxWidth: 311)
        XCTAssertEqual(result.count, 2)
        // 添字が抜けたり重複したりしていないこと
        XCTAssertEqual(result.flatMap { $0 }, Array(0..<23))
    }

    func testSpacingIsCountedTowardTheLimit() {
        // 幅24が4つで96、間隔1が3つで99。ちょうど99なら1行、98なら入らない
        XCTAssertEqual(rows(4, maxWidth: 99), [[0, 1, 2, 3]])
        XCTAssertEqual(rows(4, maxWidth: 98), [[0, 1, 2], [3]])
    }

    /// 1つで幅を超える要素があっても、空の行を作り続けて止まらなくならないこと
    func testItemWiderThanTheLimitIsPlacedAlone() {
        let result = LineWrapping.rows(widths: [500, 20, 20], maxWidth: 100, spacing: spacing)
        XCTAssertEqual(result, [[0], [1, 2]])
    }

    func testEveryItemAppearsExactlyOnce() {
        let widths: [CGFloat] = [10, 80, 30, 55, 5, 120, 40]
        let result = LineWrapping.rows(widths: widths, maxWidth: 100, spacing: spacing)
        XCTAssertEqual(result.flatMap { $0 }.sorted(), Array(widths.indices))
        XCTAssertEqual(result.flatMap { $0 }, Array(widths.indices), "順番が入れ替わってはいけない")
    }
}
