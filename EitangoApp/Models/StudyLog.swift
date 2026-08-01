import Foundation
import SwiftData

/// 日次の学習サマリー（学習単語数・正答率のローカル保存）。UserProgressとは別テーブルとし、
/// 「その日いくつ・何%正解したか」を集計コストなしで即座にグラフ表示できるようにする。
@Model
final class StudyLog {
    /// 日付キー（時刻を切り捨てた日単位、"yyyy-MM-dd" 相当をDateで保持）
    @Attribute(.unique) var date: Date

    var studiedWordCount: Int
    var correctCount: Int
    var attemptCount: Int

    /// その日の最後の解答時点で「覚えた」だった語数。
    /// 習熟度の推移グラフは過去に遡って再計算できない（現在の状態しか残らない）ため、
    /// 解答のたびにその日のスナップショットを上書きして残しておく。
    var masteredWordCount: Int = 0

    init(
        date: Date,
        studiedWordCount: Int = 0,
        correctCount: Int = 0,
        attemptCount: Int = 0,
        masteredWordCount: Int = 0
    ) {
        self.date = date
        self.studiedWordCount = studiedWordCount
        self.correctCount = correctCount
        self.attemptCount = attemptCount
        self.masteredWordCount = masteredWordCount
    }

    var accuracy: Double {
        attemptCount == 0 ? 0 : Double(correctCount) / Double(attemptCount)
    }
}
