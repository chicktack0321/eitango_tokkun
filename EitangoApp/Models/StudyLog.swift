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

    init(date: Date, studiedWordCount: Int = 0, correctCount: Int = 0, attemptCount: Int = 0) {
        self.date = date
        self.studiedWordCount = studiedWordCount
        self.correctCount = correctCount
        self.attemptCount = attemptCount
    }

    var accuracy: Double {
        attemptCount == 0 ? 0 : Double(correctCount) / Double(attemptCount)
    }
}
