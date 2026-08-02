import Foundation
import SwiftData

/// WordMaster への問い合わせを集約する。ViewModelがSwiftDataのクエリ構文に直接依存しないようにする層。
@MainActor
struct WordRepository {
    let context: ModelContext

    func fetchAll() -> [WordMaster] {
        (try? context.fetch(FetchDescriptor<WordMaster>(sortBy: [SortDescriptor(\.wordId)]))) ?? []
    }

    func fetchCount() -> Int {
        (try? context.fetchCount(FetchDescriptor<WordMaster>())) ?? 0
    }

    /// クイズ・タイピング・聞き流しの出題母集団。
    ///
    /// 「ユーザーが選んだ範囲」（`StudySettings`。基礎語彙を含めるか）と
    /// 「購入・試用で使える範囲」（`AccessRights`）の積を取る。
    /// 2つを混ぜて1つのフラグにすると、出題されない理由が設定なのか未購入なのかを
    /// 切り分けられなくなり、画面の案内も出し分けられない。
    ///
    /// 自分で追加した単語は階層にも権利にも関わらず必ず含める
    /// （自分で入れた語が出てこないのは、どんな理由であれ意図に反する）。
    func fetchStudyPool(
        availableTiers: Set<VocabularyTier> = Entitlements.shared.availableTiers
    ) -> [WordMaster] {
        let tiers = StudySettings.studyTiers.intersection(availableTiers)
        return fetchAll().filter { $0.source == .user || tiers.contains($0.tier) }
    }

    func fetch(category: FrequencyRank?, partOfSpeech: PartOfSpeech?) -> [WordMaster] {
        var descriptor = FetchDescriptor<WordMaster>(sortBy: [SortDescriptor(\.wordId)])

        switch (category, partOfSpeech) {
        case let (.some(category), .some(pos)):
            let c = category.rawValue, p = pos.rawValue
            descriptor.predicate = #Predicate { $0.categoryRaw == c && $0.partOfSpeechRaw == p }
        case let (.some(category), nil):
            let c = category.rawValue
            descriptor.predicate = #Predicate { $0.categoryRaw == c }
        case let (nil, .some(pos)):
            let p = pos.rawValue
            descriptor.predicate = #Predicate { $0.partOfSpeechRaw == p }
        case (nil, nil):
            break
        }

        return (try? context.fetch(descriptor)) ?? []
    }
}
