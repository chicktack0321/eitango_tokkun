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
    /// 以下は語彙階層を導入した v4 以降の項目。
    /// 省略可能にしておくことで、古い形式のJSONもそのまま読める。
    let tier: Int?
    let domain: String?
    let isIdiom: Bool?
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
        // 適用済みバージョンは UserDefaults、実データは SwiftData と保存先が分かれているため、
        // 両者が食い違うことがある（ストアの作り直し、バックアップからの復元など）。
        // 単語が1件も無ければバージョンに関わらず作り直して、空のまま復旧しない状態を防ぐ。
        let existingWordCount = (try? context.fetchCount(FetchDescriptor<WordMaster>())) ?? 0
        let storeIsEmpty = existingWordCount == 0
        guard seedFile.version > appliedVersion || storeIsEmpty else { return }

        do {
            try upsert(entries: seedFile.words, context: context)
            try ensureProgressRowsExist(for: seedFile.words, context: context)
            try context.save()
        } catch {
            // 中途半端に適用された変更を残すと次回以降の判定が狂うため、破棄してから投げ直す
            context.rollback()
            throw error
        }

        // 保存が成功して初めてバージョンを記録する。
        // 逆順にすると save 失敗時に「バージョンだけ進んで単語が空」の状態が永続化され、
        // 以降シードがスキップされて二度と復旧しなくなる。
        UserDefaults.standard.set(seedFile.version, forKey: appliedVersionKey)
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

            let tier = entry.tier.flatMap(VocabularyTier.init(rawValue:)) ?? .core
            let domain = entry.domain.flatMap(VocabularyDomain.init(rawValue:)) ?? .general

            if let word = existingById[entry.wordId] {
                word.word = entry.word
                word.meaning = entry.meaning
                word.example = entry.example
                word.frequencyCount = entry.frequencyCount
                word.category = category
                word.partOfSpeech = partOfSpeech
                word.tier = tier
                word.domain = domain
                word.isIdiom = entry.isIdiom ?? false
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
                    partOfSpeech: partOfSpeech,
                    tier: tier,
                    domain: domain,
                    isIdiom: entry.isIdiom ?? false
                )
                context.insert(word)
            }
        }

        // 新しいseedに含まれなくなった単語（改訂で削除された語）はマスターから除去する。
        // UserProgress側は意図的に触らない = 学習履歴は残り続けるが、参照先の単語が消えても実害はない
        // （UI側は WordMaster が存在する行だけを表示するため孤立した進捗レコードは単に表示されなくなるだけ）。
        //
        // ただしユーザーが自分で追加した語は同梱JSONに載っていないため、
        // 区別せずに消すとアプリを更新するたびに自作の単語が失われる。
        for orphan in existingById.values where orphan.source == .bundled {
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
