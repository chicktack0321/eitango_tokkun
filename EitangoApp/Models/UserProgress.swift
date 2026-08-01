import Foundation
import SwiftData

/// ユーザーの学習履歴。マスターデータの更新（Upsert/総入れ替え）を跨いで必ず保持される Read-Write テーブル。
@Model
final class UserProgress {
    /// `WordMaster.wordId` と対応する外部キー相当（正式なリレーションは張らない。理由は WordMaster 側コメント参照）
    @Attribute(.unique) var wordId: String

    var statusRaw: String
    var lastReviewedAt: Date?

    /// 4択・タイピング問わず正解した累計回数
    var correctCount: Int
    /// 出題された累計回数（正答率 = correctCount / attemptCount）
    var attemptCount: Int

    init(
        wordId: String,
        status: LearningStatus = .notStudied,
        lastReviewedAt: Date? = nil,
        correctCount: Int = 0,
        attemptCount: Int = 0
    ) {
        self.wordId = wordId
        self.statusRaw = status.rawValue
        self.lastReviewedAt = lastReviewedAt
        self.correctCount = correctCount
        self.attemptCount = attemptCount
    }

    var status: LearningStatus {
        get { LearningStatus(rawValue: statusRaw) ?? .notStudied }
        set { statusRaw = newValue.rawValue }
    }

    var accuracy: Double {
        attemptCount == 0 ? 0 : Double(correctCount) / Double(attemptCount)
    }

    /// クイズ/タイピングの正誤結果を記録し、ステータスを自動遷移させる
    func record(isCorrect: Bool, reviewedAt: Date = .now) {
        attemptCount += 1
        lastReviewedAt = reviewedAt
        if isCorrect {
            correctCount += 1
            status = .memorized
        } else {
            status = .needsReview
        }
    }
}
