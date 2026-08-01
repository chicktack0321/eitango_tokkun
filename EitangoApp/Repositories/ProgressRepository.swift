import Foundation
import SwiftData

/// UserProgress / StudyLog への読み書きを集約する層
@MainActor
struct ProgressRepository {
    let context: ModelContext

    func progress(for wordId: String) -> UserProgress {
        let descriptor = FetchDescriptor<UserProgress>(predicate: #Predicate { $0.wordId == wordId })
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = UserProgress(wordId: wordId)
        context.insert(created)
        return created
    }

    func allProgress() -> [String: UserProgress] {
        let all = (try? context.fetch(FetchDescriptor<UserProgress>())) ?? []
        return Dictionary(uniqueKeysWithValues: all.map { ($0.wordId, $0) })
    }

    /// 1問分の採点結果を UserProgress と当日の StudyLog の両方に反映する
    func recordAnswer(wordId: String, isCorrect: Bool, at date: Date = .now) {
        let p = progress(for: wordId)
        p.record(isCorrect: isCorrect, reviewedAt: date)

        // studiedWordCount は延べ数（同じ単語を複数回復習した場合もその都度カウント）とする。
        // 「今日新しく覚えた語だけ数える」のような厳密な集計は将来ここを拡張して対応する。
        let log = studyLog(for: date)
        log.attemptCount += 1
        log.studiedWordCount += 1
        if isCorrect { log.correctCount += 1 }

        try? context.save()
    }

    private func studyLog(for date: Date) -> StudyLog {
        let day = Calendar.current.startOfDay(for: date)
        let descriptor = FetchDescriptor<StudyLog>(predicate: #Predicate { $0.date == day })
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = StudyLog(date: day)
        context.insert(created)
        return created
    }

    /// ホーム画面のステータス内訳表示用。存在しないステータスも0件として返す。
    func statusBreakdown() -> [LearningStatus: Int] {
        var counts: [LearningStatus: Int] = [.notStudied: 0, .memorized: 0, .needsReview: 0]
        for progress in allProgress().values {
            counts[progress.status, default: 0] += 1
        }
        return counts
    }

    /// 当日分の StudyLog を取得する（未学習日は nil。record時のように新規作成はしない）
    func todayLog(date: Date = .now) -> StudyLog? {
        let day = Calendar.current.startOfDay(for: date)
        let descriptor = FetchDescriptor<StudyLog>(predicate: #Predicate { $0.date == day })
        return try? context.fetch(descriptor).first
    }

    /// これまでに一度でも出題された語の累計正答率
    func overallAccuracy() -> Double {
        let attempted = allProgress().values.filter { $0.attemptCount > 0 }
        guard !attempted.isEmpty else { return 0 }
        let totalCorrect = attempted.reduce(0) { $0 + $1.correctCount }
        let totalAttempts = attempted.reduce(0) { $0 + $1.attemptCount }
        return totalAttempts == 0 ? 0 : Double(totalCorrect) / Double(totalAttempts)
    }
}
