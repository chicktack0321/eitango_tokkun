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
    /// 「ユーザーが選んだ範囲」（`StudyScope`）と「購入・試用で使える範囲」（`AccessRights`）の
    /// 積を取る。2つを混ぜて1つの条件にすると、出題されない理由が設定なのか未購入なのかを
    /// 切り分けられなくなり、画面の案内も出し分けられない。
    func fetchStudyPool(
        scope: StudyScope = StudySettings.studyScope,
        availableTiers: Set<VocabularyTier> = Entitlements.shared.availableTiers
    ) -> [WordMaster] {
        fetchAll().filter { scope.contains($0, availableTiers: availableTiers) }
    }

    /// 指定した範囲に入る語数。出題を始める前に「この条件で何語あるか」を見せるために使う
    func countStudyPool(
        scope: StudyScope,
        availableTiers: Set<VocabularyTier> = Entitlements.shared.availableTiers
    ) -> Int {
        fetchStudyPool(scope: scope, availableTiers: availableTiers).count
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
