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
