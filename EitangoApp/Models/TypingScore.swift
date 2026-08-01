import Foundation
import SwiftData

/// タイピングの1プレイ分の記録。自己ベストの比較に使う。
///
/// `UserProgress` と同じくユーザー側のデータなので、
/// 単語マスターを入れ替えても消えない別テーブルに置いている。
@Model
final class TypingScore {
    var score: Int
    var correctWordCount: Int
    var missCount: Int
    var maxCombo: Int
    var accuracy: Double
    var playedAt: Date
    /// スペルを隠すモードで出したスコアか。難易度が違うので後から区別できるようにしておく。
    var isHiddenMode: Bool = false

    init(
        score: Int,
        correctWordCount: Int,
        missCount: Int,
        maxCombo: Int,
        accuracy: Double,
        playedAt: Date = .now,
        isHiddenMode: Bool = false
    ) {
        self.score = score
        self.correctWordCount = correctWordCount
        self.missCount = missCount
        self.maxCombo = maxCombo
        self.accuracy = accuracy
        self.playedAt = playedAt
        self.isHiddenMode = isHiddenMode
    }
}
