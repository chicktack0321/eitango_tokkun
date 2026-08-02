import XCTest
import AVFoundation
@testable import EitangoApp

/// BGMのループ素材を検証する。
///
/// 音は目で見て確認できず、CIのスクリーンショットにも写らない。
/// 実際に「フレーズの継ぎ目でリズムが崩れる」不具合が出たことがあるので、
/// 波形そのものから拍が揃っているかを確かめる。
@MainActor
final class GameAudioTests: XCTestCase {

    /// 4小節 × 8分音符 = 32ステップ
    private let totalSteps = 32

    /// ループの長さが8分音符で割り切れること。
    /// 以前は末尾に0.2秒の余白を足していたため、1周ごとに空白が入って拍がずれていた。
    func testBGMLoopLengthIsAWholeNumberOfSteps() throws {
        let buffer = try XCTUnwrap(GameAudio.makeBGMLoop())
        let frames = Int(buffer.frameLength)

        XCTAssertGreaterThan(frames, 0)
        XCTAssertEqual(
            frames % totalSteps, 0,
            "ループ長が8分音符で割り切れないと、周回するたびに拍が少しずつずれる"
        )
    }

    /// 2周ぶん並べても、すべての8分音符の頭で音が立ち上がること。
    /// 継ぎ目に空白や余りがあると、そこから先の音が後ろにずれてこの条件が崩れる。
    func testBGMLoopKeepsTheBeatAcrossTheSeam() throws {
        let buffer = try XCTUnwrap(GameAudio.makeBGMLoop())
        let frames = Int(buffer.frameLength)
        let channel = try XCTUnwrap(buffer.floatChannelData?[0])

        let stepFrames = frames / totalSteps
        // 継ぎ目をまたいで判定したいので、同じ波形を2周ぶん連結する
        var samples = [Float](repeating: 0, count: frames * 2)
        for index in 0..<frames {
            samples[index] = channel[index]
            samples[index + frames] = channel[index]
        }

        for step in 0..<(totalSteps * 2) {
            let start = step * stepFrames
            var peakOffset = 0
            var peak: Float = 0
            for offset in 0..<stepFrames {
                let value = abs(samples[start + offset])
                if value > peak {
                    peak = value
                    peakOffset = offset
                }
            }

            XCTAssertGreaterThan(peak, 0.01, "\(step)個目の8分音符で音が鳴っていない")
            // 各ステップの頭に打鍵（アルペジオ・ハイハット）があるので、
            // 最大振幅は必ずステップ冒頭に来る。ずれていれば拍が動いている。
            XCTAssertLessThan(
                peakOffset, stepFrames / 4,
                "\(step)個目の8分音符で音の立ち上がりが拍からずれている"
            )
        }
    }

    /// ループの終わりと始まりが不連続だと「プツッ」というノイズになる。
    /// 継ぎ目の段差が、曲中に現れる普通のサンプル間の変化より大きくないことを確かめる。
    func testBGMLoopHasNoClickAtTheSeam() throws {
        let buffer = try XCTUnwrap(GameAudio.makeBGMLoop())
        let frames = Int(buffer.frameLength)
        let channel = try XCTUnwrap(buffer.floatChannelData?[0])

        var maxStepWithinLoop: Float = 0
        for index in 1..<frames {
            maxStepWithinLoop = max(maxStepWithinLoop, abs(channel[index] - channel[index - 1]))
        }
        let seamStep = abs(channel[0] - channel[frames - 1])

        XCTAssertLessThanOrEqual(
            seamStep, maxStepWithinLoop,
            "ループの継ぎ目に、曲中には現れない大きな段差がある"
        )
    }
}
