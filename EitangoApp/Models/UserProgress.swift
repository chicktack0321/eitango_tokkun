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

    /// Leitnerボックス方式の段階（0が最短間隔）。正解でひとつ上へ、不正解で0に戻る。
    /// 既存データにこの列が無い状態からのアップデートでも軽量マイグレーションで既定値が入るよう、
    /// 省略可能な初期値を持たせている。
    var reviewBox: Int = 0

    /// 次に出題すべき日時。nil は「まだ一度も解いていない＝いつでも出題してよい」を表す
    var nextReviewAt: Date?

    init(
        wordId: String,
        status: LearningStatus = .notStudied,
        lastReviewedAt: Date? = nil,
        correctCount: Int = 0,
        attemptCount: Int = 0,
        reviewBox: Int = 0,
        nextReviewAt: Date? = nil
    ) {
        self.wordId = wordId
        self.statusRaw = status.rawValue
        self.lastReviewedAt = lastReviewedAt
        self.correctCount = correctCount
        self.attemptCount = attemptCount
        self.reviewBox = reviewBox
        self.nextReviewAt = nextReviewAt
    }

    var status: LearningStatus {
        get { LearningStatus(rawValue: statusRaw) ?? .notStudied }
        set { statusRaw = newValue.rawValue }
    }

    var accuracy: Double {
        attemptCount == 0 ? 0 : Double(correctCount) / Double(attemptCount)
    }

    /// クイズ/タイピングの正誤結果を記録し、ステータスと次回の復習日を更新する
    func record(isCorrect: Bool, reviewedAt: Date = .now, calendar: Calendar = .current) {
        attemptCount += 1
        lastReviewedAt = reviewedAt
        if isCorrect {
            correctCount += 1
            status = .memorized
            reviewBox = min(reviewBox + 1, Self.maxReviewBox)
        } else {
            // 間違えた語は最短間隔に戻し、その日のうちにまた出題されるようにする
            status = .needsReview
            reviewBox = 0
        }
        nextReviewAt = Self.nextReviewDate(box: reviewBox, from: reviewedAt, calendar: calendar)
    }

    /// 指定時点で復習期限が来ているか。未出題（nextReviewAtがnil）の語も対象に含める。
    func isDue(at date: Date = .now) -> Bool {
        guard let nextReviewAt else { return true }
        return nextReviewAt <= date
    }
}

// MARK: - 間隔反復（Leitnerボックス）

extension UserProgress {
    /// 段階ごとの復習間隔（日数）。正解を重ねるほど間隔が伸び、忘れかけたタイミングで再出題される。
    /// SM-2のような可変難易度は持たせず、動作が予測しやすい固定テーブルにしている。
    static let reviewIntervalDays = [0, 1, 3, 7, 14, 30]

    static var maxReviewBox: Int { reviewIntervalDays.count - 1 }

    static func intervalDays(forBox box: Int) -> Int {
        let index = min(max(box, 0), maxReviewBox)
        return reviewIntervalDays[index]
    }

    /// 次回復習日を求める。時刻ではなく「日」単位で揃えることで、
    /// 朝に解いても夜に解いても同じ日に復習期限が来るようにしている。
    static func nextReviewDate(box: Int, from date: Date, calendar: Calendar = .current) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let days = intervalDays(forBox: box)
        return calendar.date(byAdding: .day, value: days, to: startOfDay) ?? date
    }
}
