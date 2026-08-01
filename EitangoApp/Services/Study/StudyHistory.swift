import Foundation

/// グラフ1本分の日次データ。学習していない日も0として含めるため、
/// `StudyLog` をそのまま使わず値型に詰め替える。
struct DailyStudy: Identifiable, Equatable {
    let date: Date
    let studiedWordCount: Int
    let correctCount: Int
    let attemptCount: Int

    var id: Date { date }

    var accuracy: Double {
        attemptCount == 0 ? 0 : Double(correctCount) / Double(attemptCount)
    }

    /// その日に学習したか（連続日数の判定に使う）
    var didStudy: Bool { studiedWordCount > 0 }
}

/// 学習履歴の集計。日付の扱いを間違えると「グラフが1日ずれる」「連続日数が途切れる」といった
/// 見つけにくい不具合になるため、SwiftDataに触れない純粋関数にしてユニットテストしている。
enum StudyHistory {

    /// 直近 `days` 日分の日次データを、古い順・欠損日を0埋めして返す。
    /// 学習していない日を飛ばすとグラフの横軸が詰まって推移が読めなくなるため、必ず埋める。
    static func series(
        logs: [StudyLog],
        days: Int,
        endingOn today: Date = .now,
        calendar: Calendar = .current
    ) -> [DailyStudy] {
        guard days > 0 else { return [] }

        let endDay = calendar.startOfDay(for: today)
        // 同じ日のログが複数あっても最後の1件に寄せる（通常は @Attribute(.unique) で1件）
        let logsByDay = Dictionary(
            logs.map { (calendar.startOfDay(for: $0.date), $0) },
            uniquingKeysWith: { _, latest in latest }
        )

        return (0..<days).reversed().compactMap { offset -> DailyStudy? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: endDay) else { return nil }
            let log = logsByDay[day]
            return DailyStudy(
                date: day,
                studiedWordCount: log?.studiedWordCount ?? 0,
                correctCount: log?.correctCount ?? 0,
                attemptCount: log?.attemptCount ?? 0
            )
        }
    }

    /// 現在の連続学習日数。
    ///
    /// 当日まだ学習していなくても前日までの記録は途切れていないものとして数える。
    /// そうしないと、朝アプリを開いた瞬間に連続日数が0に見えてしまい、
    /// 続ける動機付けという本来の役割を果たさなくなる。
    static func currentStreak(
        logs: [StudyLog],
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let studiedDays = Set(
            logs.filter { $0.studiedWordCount > 0 }
                .map { calendar.startOfDay(for: $0.date) }
        )
        guard !studiedDays.isEmpty else { return 0 }

        let startOfToday = calendar.startOfDay(for: today)
        // 当日の記録が無ければ前日を起点にする
        var cursor = studiedDays.contains(startOfToday)
            ? startOfToday
            : calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday

        var streak = 0
        while studiedDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    /// 期間内の合計解答数（グラフの補足表示用）
    static func totalAttempts(in series: [DailyStudy]) -> Int {
        series.reduce(0) { $0 + $1.attemptCount }
    }

    /// 期間全体をならした正答率。日ごとの正答率を平均すると
    /// 1問しか解かなかった日が重く効いてしまうため、解答数で重み付けする。
    static func overallAccuracy(in series: [DailyStudy]) -> Double {
        let attempts = series.reduce(0) { $0 + $1.attemptCount }
        guard attempts > 0 else { return 0 }
        let correct = series.reduce(0) { $0 + $1.correctCount }
        return Double(correct) / Double(attempts)
    }
}
