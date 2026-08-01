import Foundation

/// 出題順を決めるロジック。
///
/// 単語アプリの価値は「忘れかけた語を適切なタイミングで再提示すること」にあるため、
/// 毎回ランダムに出すのではなく次の優先度で並べる:
///
/// 1. 復習期限が来ている語（間違えた語・間隔が満了した語）
/// 2. まだ一度も解いていない語
/// 3. まだ期限前の語（期限が近い順）
///
/// SwiftDataに触れない純粋関数にしてあるため、そのままユニットテストできる。
enum StudyQueue {
    static func prioritize(
        words: [WordMaster],
        progress: [String: UserProgress],
        now: Date = .now
    ) -> [WordMaster] {
        var due: [WordMaster] = []
        var unstudied: [WordMaster] = []
        var scheduled: [(word: WordMaster, dueDate: Date)] = []

        for word in words {
            guard let record = progress[word.wordId], record.attemptCount > 0 else {
                unstudied.append(word)
                continue
            }
            if let nextReviewAt = record.nextReviewAt {
                if nextReviewAt <= now {
                    due.append(word)
                } else {
                    scheduled.append((word, nextReviewAt))
                }
            } else {
                // 解いた記録はあるが日程が入っていない（旧バージョンからの移行データ）は復習対象として扱う
                due.append(word)
            }
        }

        // 同じ優先度の中では順番を固定したくないのでシャッフルする。
        // 期限前の語だけは「期限が近い順」に意味があるため並びを保つ。
        due.shuffle()
        unstudied.shuffle()

        return due + unstudied + scheduled.sorted { $0.dueDate < $1.dueDate }.map(\.word)
    }

    /// 復習期限が来ている語の件数（ホーム画面の「今日の復習」表示用）
    static func dueCount(
        words: [WordMaster],
        progress: [String: UserProgress],
        now: Date = .now
    ) -> Int {
        words.reduce(into: 0) { count, word in
            guard let record = progress[word.wordId], record.attemptCount > 0 else { return }
            if record.isDue(at: now) { count += 1 }
        }
    }
}
