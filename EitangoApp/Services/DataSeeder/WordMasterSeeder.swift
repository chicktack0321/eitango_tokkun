import Foundation
import SwiftData

/// JSONデコード用のDTO。SwiftDataの `@Model` と分離しておくことで、
/// マスターデータの配布フォーマット（JSON/将来的にはsqlite同梱など）を自由に差し替えられるようにする。
private struct WordSeedFile: Decodable {
    let version: Int
    let words: [WordSeedEntry]
}

private struct WordSeedEntry: Decodable {
    let wordId: String
    let word: String
    let meaning: String
    let example: String
    let frequencyCount: Int
    let category: String
    let partOfSpeech: String
}

enum WordMasterSeederError: Error {
    case seedFileNotFound
    case decodeFailed(Error)
}

/// アプリ起動時に「マスターデータ（WordMaster）」を最新へUpsertしつつ、
/// 「学習履歴（UserProgress）」は一切手を触れずに保持するための初期化処理。
@MainActor
enum WordMasterSeeder {
    /// UserDefaults に保存する、直近で適用した seed のバージョン番号
    private static let appliedVersionKey = "wordMasterSeedVersion"

    /// アプリ起動時に一度だけ呼び出す。バンドル同梱JSONのバージョンが
    /// 既適用バージョンより新しい場合のみ Upsert を実行する（毎起動フルスキャンを避ける）。
    static func seedIfNeeded(context: ModelContext, bundle: Bundle = .main) throws {
        let seedFile = try loadSeedFile(bundle: bundle)

        let appliedVersion = UserDefaults.standard.integer(forKey: appliedVersionKey)
        guard seedFile.version > appliedVersion else { return }

        try upsert(entries: seedFile.words, context: context)
        try ensureProgressRowsExist(for: seedFile.words, context: context)

        UserDefaults.standard.set(seedFile.version, forKey: appliedVersionKey)
        try context.save()
    }

    private static func loadSeedFile(bundle: Bundle) throws -> WordSeedFile {
        guard let url = bundle.url(forResource: "word_master_seed", withExtension: "json") else {
            throw WordMasterSeederError.seedFileNotFound
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(WordSeedFile.self, from: data)
        } catch {
            throw WordMasterSeederError.decodeFailed(error)
        }
    }

    /// 既存の `wordId` は上書き更新、未知の `wordId` は新規追加する（= Upsert）。
    private static func upsert(entries: [WordSeedEntry], context: ModelContext) throws {
        // 既存マスターを wordId でインデックス化し、更新のたびにフェッチしないようにする
        let existing = try context.fetch(FetchDescriptor<WordMaster>())
        var existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.wordId, $0) })

        for entry in entries {
            guard
                let category = FrequencyRank(rawValue: entry.category),
                let partOfSpeech = PartOfSpeech(rawValue: entry.partOfSpeech)
            else { continue }

            if let word = existingById[entry.wordId] {
                word.word = entry.word
                word.meaning = entry.meaning
                word.example = entry.example
                word.frequencyCount = entry.frequencyCount
                word.category = category
                word.partOfSpeech = partOfSpeech
                word.updatedAt = .now
                existingById.removeValue(forKey: entry.wordId)
            } else {
                let word = WordMaster(
                    wordId: entry.wordId,
                    word: entry.word,
                    meaning: entry.meaning,
                    example: entry.example,
                    frequencyCount: entry.frequencyCount,
                    category: category,
                    partOfSpeech: partOfSpeech
                )
                context.insert(word)
            }
        }

        // 新しいseedに含まれなくなった単語（改訂で削除された語）はマスターから除去する。
        // UserProgress側は意図的に触らない = 学習履歴は残り続けるが、参照先の単語が消えても実害はない
        // （UI側は WordMaster が存在する行だけを表示するため孤立した進捗レコードは単に表示されなくなるだけ）。
        for orphan in existingById.values {
            context.delete(orphan)
        }
    }

    /// 新規単語（初回起動時の全件、またはアップデートで追加された語）に対して
    /// デフォルト状態（未学習）の UserProgress を作成する。既存の進捗には一切触れない。
    private static func ensureProgressRowsExist(for entries: [WordSeedEntry], context: ModelContext) throws {
        let existingProgress = try context.fetch(FetchDescriptor<UserProgress>())
        let existingIds = Set(existingProgress.map(\.wordId))

        for entry in entries where !existingIds.contains(entry.wordId) {
            context.insert(UserProgress(wordId: entry.wordId))
        }
    }
}
