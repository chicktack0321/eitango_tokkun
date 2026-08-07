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

    /// 1問の採点結果。呼び出し側が「覚えた」への到達を数えるのに使う
    struct AnswerOutcome {
        let wasMemorized: Bool
        let isMemorized: Bool

        var reachedMemorized: Bool { !wasMemorized && isMemorized }
    }

    /// 1問分の採点結果を UserProgress と当日の StudyLog の両方に反映する。
    ///
    /// ここは解答のたびに通る道なので、語彙数ぶんの走査を持ち込まないこと。
    /// 以前は習熟度のスナップショットをここで焼き直していて、正解のたびに
    /// 全単語（数千語）を読み込んでいた。判定が目に見えて遅れる原因になる。
    /// 当日の基準値はセッション開始時に `refreshMasterySnapshot` で作り、
    /// ここでは増減ぶんだけを足し引きする。
    ///
    /// - Parameter word: 呼び出し側が持っているものをそのまま渡す。
    ///   内訳のセルを決めるのに階層・頻出度・分野が要るが、ここで引き直すと
    ///   1解答につき単語の取得が1回増える。
    @discardableResult
    func recordAnswer(word: WordMaster, isCorrect: Bool, at date: Date = .now) -> AnswerOutcome {
        let p = progress(for: word.wordId)
        let wasMemorized = p.status(at: date) == .memorized
        p.record(isCorrect: isCorrect, reviewedAt: date)
        let isMemorized = p.status(at: date) == .memorized

        // studiedWordCount は延べ数（同じ単語を複数回復習した場合もその都度カウント）とする。
        // 「今日新しく覚えた語だけ数える」のような厳密な集計は将来ここを拡張して対応する。
        let log = studyLog(for: date)
        log.attemptCount += 1
        log.studiedWordCount += 1
        if isCorrect { log.correctCount += 1 }

        // 習熟度は現在の状態しか残らないので、その日の最新値を残しておく。
        // でないと推移グラフを後から描けない。増減はこの語が境目をまたいだときだけ起きる。
        if wasMemorized != isMemorized {
            let delta = isMemorized ? 1 : -1
            log.masteredWordCount = max(0, log.masteredWordCount + delta)
            let key = MasteryBreakdown.key(for: word)
            let updated = (log.masteredBreakdown[key] ?? 0) + delta
            if updated > 0 {
                log.masteredBreakdown[key] = updated
            } else {
                log.masteredBreakdown.removeValue(forKey: key)
            }
        }

        // ここでは保存しない。1問ごとの save はそれ自体が待ち時間になる。
        // mainContext の自動保存に任せ、区切りで `save()` を呼ぶ。
        return AnswerOutcome(wasMemorized: wasMemorized, isMemorized: isMemorized)
    }

    /// 当日の「覚えた」語数を数え直して焼き直す。
    ///
    /// 全単語を走査するので、解答中には呼ばないこと。想定している呼び出し元は
    /// セッションの開始時、単語詳細で「覚えた」「やり直す」を押したとき、学習の記録を開いたとき。
    /// 日付をまたいで復習期限が来た語や、解答を経ない状態変更はここで拾う。
    func refreshMasterySnapshot(at date: Date = .now) {
        let snapshot = masteredSnapshot(at: date)
        let log = studyLog(for: date)
        log.masteredWordCount = snapshot.total
        log.masteredBreakdown = snapshot.breakdown
    }

    /// 区切りでの保存。解答ごとには呼ばない
    func save() {
        try? context.save()
    }

    /// 指定時点で「覚えた」段階にある語数と、その内訳。
    ///
    /// 単語マスターに実在する語だけを数える。マスターを入れ替えても `UserProgress` は
    /// 残す設計（`WordMasterSeeder` 参照）なので、進捗の行を全部数えると、
    /// 単語データの更新で消えた語まで「覚えた」に含まれ、単語帳やホームの習熟度と数が合わなくなる。
    func masteredSnapshot(at date: Date = .now) -> MasterySnapshot {
        let words = (try? context.fetch(FetchDescriptor<WordMaster>())) ?? []
        let progressByWordId = allProgress()

        var total = 0
        var breakdown: [String: Int] = [:]
        for word in words {
            guard let progress = progressByWordId[word.wordId],
                  progress.status(at: date) == .memorized else { continue }
            total += 1
            breakdown[MasteryBreakdown.key(for: word), default: 0] += 1
        }
        return MasterySnapshot(total: total, breakdown: breakdown)
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

    /// 直近 `days` 日分の日次ログを取得する。
    /// 全期間を読むと記録が増えるほど重くなるため、グラフに映る範囲だけを日付で絞る。
    func recentLogs(days: Int, endingOn today: Date = .now, calendar: Calendar = .current) -> [StudyLog] {
        let endDay = calendar.startOfDay(for: today)
        guard let startDay = calendar.date(byAdding: .day, value: -(days - 1), to: endDay) else { return [] }

        let descriptor = FetchDescriptor<StudyLog>(
            predicate: #Predicate { $0.date >= startDay },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 連続学習日数の判定用。途切れを跨いで数えないよう、直近1年分あれば足りる。
    func logsForStreak(today: Date = .now, calendar: Calendar = .current) -> [StudyLog] {
        recentLogs(days: 366, endingOn: today, calendar: calendar)
    }

    /// 当日分の StudyLog を取得する（未学習日は nil。record時のように新規作成はしない）
    func todayLog(date: Date = .now) -> StudyLog? {
        let day = Calendar.current.startOfDay(for: date)
        let descriptor = FetchDescriptor<StudyLog>(predicate: #Predicate { $0.date == day })
        return try? context.fetch(descriptor).first
    }

    /// 指定した語だけを対象に、ステータス内訳と累計正答率をまとめて返す。
    ///
    /// 習熟度を階層・分野などで絞って見るための入口。進捗の行は「一度でも解いた語」にしか
    /// 無いので、行の側からではなく語の側から引く（絞り込んだ語に対する未学習数は
    /// 呼び出し側が語数との差で求める）。
    ///
    /// - Note: SwiftDataには集計クエリが無く、全行の materialize が避けられない。
    ///   語彙数が数千規模で体感できるほど遅くなったら、集計値を別モデルに持たせて
    ///   解答時に加算する方式へ切り替える。
    func summarize(words: [WordMaster]) -> ProgressSummary {
        let byWordId = allProgress()
        let rows = words.compactMap { byWordId[$0.wordId] }
        return Self.summarize(progressRows: rows)
    }

    private static func summarize(progressRows: [UserProgress]) -> ProgressSummary {
        var statusCounts: [LearningStatus: Int] = Dictionary(
            uniqueKeysWithValues: LearningStatus.allCases.map { ($0, 0) }
        )
        var totalCorrect = 0
        var totalAttempts = 0

        for progress in progressRows {
            statusCounts[progress.status, default: 0] += 1
            totalCorrect += progress.correctCount
            totalAttempts += progress.attemptCount
        }

        return ProgressSummary(
            statusCounts: statusCounts,
            totalCorrect: totalCorrect,
            totalAttempts: totalAttempts
        )
    }
}

/// `UserProgress` 全体を1回走査して得られる集計値
struct ProgressSummary {
    var statusCounts: [LearningStatus: Int]
    var totalCorrect: Int
    var totalAttempts: Int

    static let empty = ProgressSummary(statusCounts: [:], totalCorrect: 0, totalAttempts: 0)

    func count(of status: LearningStatus) -> Int {
        statusCounts[status] ?? 0
    }

    /// 出題されたことのある語に対する累計正答率
    var accuracy: Double {
        totalAttempts == 0 ? 0 : Double(totalCorrect) / Double(totalAttempts)
    }
}
