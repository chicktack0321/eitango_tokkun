import Foundation
import SwiftData

/// タイピングのスコア履歴。自己ベストの表示と更新判定に使う。
@MainActor
struct TypingScoreRepository {
    let context: ModelContext

    /// 結果画面に出す上位件数
    static let rankingSize = 5

    /// 上位 `limit` 件を高い順に返す
    func best(limit: Int = rankingSize) -> [TypingScore] {
        var descriptor = FetchDescriptor<TypingScore>(
            sortBy: [SortDescriptor(\.score, order: .reverse), SortDescriptor(\.playedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 保存して、ベスト5に入ったかと自己ベスト更新かを返す。
    ///
    /// 判定は保存前の記録と比べる必要があるため、保存とまとめてここで行う。
    /// 画面側で順序を間違えると「常に1位」と表示されてしまう。
    @discardableResult
    func record(_ score: TypingScore) -> Achievement {
        let previous = best(limit: Self.rankingSize)
        let previousTop = previous.first?.score

        context.insert(score)
        try? context.save()

        let isNewBest = previousTop.map { score.score > $0 } ?? (score.score > 0)
        let enteredRanking = previous.count < Self.rankingSize
            || previous.contains { score.score > $0.score }

        return Achievement(
            isNewBest: isNewBest,
            enteredRanking: enteredRanking && score.score > 0,
            rank: rank(of: score)
        )
    }

    private func rank(of score: TypingScore) -> Int? {
        let top = best(limit: Self.rankingSize)
        guard let index = top.firstIndex(where: { $0.persistentModelID == score.persistentModelID }) else {
            return nil
        }
        return index + 1
    }

    struct Achievement {
        /// これまでの最高得点を超えた
        let isNewBest: Bool
        /// ベスト5に入った
        let enteredRanking: Bool
        /// 入った場合の順位（1始まり）
        let rank: Int?

        static let none = Achievement(isNewBest: false, enteredRanking: false, rank: nil)
    }
}
