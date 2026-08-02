import XCTest
import SwiftData
@testable import EitangoApp

/// ユーザーが追加した単語の保存と、マスターデータ更新に対する耐性をテストする。
///
/// 同梱JSONのUpsertは「JSONに無い語」を削除するため、区別を誤ると
/// アプリを更新した瞬間にユーザーの自作単語が消える。実機では次の更新まで
/// 気付けない類の不具合なので、ここで押さえる。
@MainActor
final class UserWordTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var repository: UserWordRepository!

    override func setUpWithError() throws {
        let schema = Schema([WordMaster.self, UserProgress.self, StudyLog.self, TypingScore.self, UserWord.self])
        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        context = container.mainContext
        repository = UserWordRepository(context: context)
    }

    override func tearDownWithError() throws {
        repository = nil
        context = nil
        container = nil
    }

    private func masters() -> [WordMaster] {
        (try? context.fetch(FetchDescriptor<WordMaster>())) ?? []
    }

    @discardableResult
    private func addSample(word: String = "serendipity", meaning: String = "偶然の幸運") throws -> UserWord {
        try repository.add(word: word, meaning: meaning, example: "", category: .b, partOfSpeech: .noun)
    }

    // MARK: - 追加

    /// 追加した単語が単語帳（WordMaster）にも現れ、出題に必要な進捗行も用意されること
    func testAddedWordAppearsInTheWordList() throws {
        let added = try addSample()

        let mirrored = masters().first { $0.wordId == added.wordId }
        XCTAssertNotNil(mirrored)
        XCTAssertEqual(mirrored?.word, "serendipity")
        XCTAssertEqual(mirrored?.meaning, "偶然の幸運")
        XCTAssertEqual(mirrored?.source, .user)

        let progress = (try? context.fetch(FetchDescriptor<UserProgress>())) ?? []
        XCTAssertEqual(progress.map(\.wordId), [added.wordId], "出題対象にするには進捗行が要る")
    }

    func testAddRejectsEmptyInput() {
        XCTAssertThrowsError(try repository.add(word: "  ", meaning: "意味", example: "", category: .a, partOfSpeech: .noun)) {
            XCTAssertEqual($0 as? UserWordRepository.SaveError, .emptyWord)
        }
        XCTAssertThrowsError(try repository.add(word: "apple", meaning: " ", example: "", category: .a, partOfSpeech: .noun)) {
            XCTAssertEqual($0 as? UserWordRepository.SaveError, .emptyMeaning)
        }
    }

    /// 同じ綴りを二重に登録させない（大文字小文字は区別しない）
    func testAddRejectsDuplicateSpelling() throws {
        try addSample(word: "apple", meaning: "りんご")

        XCTAssertThrowsError(try repository.add(word: "Apple", meaning: "りんご", example: "", category: .a, partOfSpeech: .noun)) {
            XCTAssertEqual($0 as? UserWordRepository.SaveError, .duplicate("Apple"))
        }
    }

    /// 同梱データと同じ綴りも重複として扱う
    func testAddRejectsSpellingThatExistsInBundledData() throws {
        context.insert(
            WordMaster(
                wordId: "EIKEN_G2_0001",
                word: "opportunity",
                meaning: "機会",
                example: "",
                frequencyCount: 10,
                category: .a,
                partOfSpeech: .noun
            )
        )

        XCTAssertThrowsError(
            try repository.add(word: "opportunity", meaning: "チャンス", example: "", category: .a, partOfSpeech: .noun)
        )
    }

    // MARK: - 編集・削除

    func testUpdateRewritesBothTheRecordAndTheWordList() throws {
        let added = try addSample()

        try repository.update(
            added,
            word: "serendipity",
            meaning: "思いがけない発見",
            example: "a serendipity moment",
            category: .a,
            partOfSpeech: .noun
        )

        let mirrored = masters().first { $0.wordId == added.wordId }
        XCTAssertEqual(mirrored?.meaning, "思いがけない発見")
        XCTAssertEqual(mirrored?.example, "a serendipity moment")
        XCTAssertEqual(mirrored?.category, .a)
    }

    func testDeleteRemovesTheWordAndItsProgress() throws {
        let added = try addSample()

        repository.delete(added)

        XCTAssertTrue(masters().isEmpty)
        XCTAssertTrue(repository.all().isEmpty)
        XCTAssertTrue(((try? context.fetch(FetchDescriptor<UserProgress>())) ?? []).isEmpty)
    }

    // MARK: - マスターデータ更新への耐性

    /// 同梱データの改訂で単語帳が総入れ替えされても、自作の単語は残ること。
    /// seed の Upsert は「JSONに無い語」を消すので、ここが壊れるとアプリ更新で消える。
    func testUserWordSurvivesMasterDataReplacement() throws {
        // 新しい同梱データには含まれない、改訂で消える予定の語
        context.insert(
            WordMaster(
                wordId: "EIKEN_G2_REMOVED",
                word: "obsolete",
                meaning: "旧版の語",
                example: "",
                frequencyCount: 1,
                category: .c,
                partOfSpeech: .adjective
            )
        )
        let added = try addSample()

        // 適用済みバージョンが残っているとシードがスキップされ、
        // 「消されなかった」ではなく「何も起きなかった」で通ってしまう。
        UserDefaults.standard.removeObject(forKey: "wordMasterSeedVersion")

        // 新しい同梱データ（旧版の語は含まれない）を適用する
        try WordMasterSeeder.seedIfNeeded(context: context, bundle: .main)

        XCTAssertFalse(
            masters().contains { $0.wordId == "EIKEN_G2_REMOVED" },
            "同梱データの入れ替え（不要な語の削除）が行われていない＝テストが素通りしている"
        )

        let remaining = masters()
        XCTAssertTrue(
            remaining.contains { $0.wordId == added.wordId },
            "自分で追加した単語がマスター更新で消えている"
        )
        XCTAssertNotNil(repository.userWord(for: added.wordId), "原本が消えている")
    }

    /// ストアを作り直したあとでも、原本から単語帳へ復元できること
    func testSyncToMasterRestoresTheWordList() throws {
        let added = try addSample()

        // 単語帳側だけを失った状態を作る
        for master in masters() {
            context.delete(master)
        }
        try context.save()
        XCTAssertTrue(masters().isEmpty)

        repository.syncToMaster()

        XCTAssertEqual(masters().first?.wordId, added.wordId)
    }

    /// 原本が消えている複製は掃除されること
    func testSyncToMasterRemovesOrphanedCopies() throws {
        context.insert(
            WordMaster(
                wordId: "USER_ghost",
                word: "ghost",
                meaning: "幽霊",
                example: "",
                frequencyCount: 0,
                category: .c,
                partOfSpeech: .noun,
                source: .user
            )
        )
        try context.save()

        repository.syncToMaster()

        XCTAssertFalse(masters().contains { $0.wordId == "USER_ghost" })
    }
}
