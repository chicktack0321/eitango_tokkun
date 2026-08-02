import XCTest
import SwiftData
@testable import EitangoApp

/// 権利によって出題母集団が実際に変わることをテストする。
///
/// `AccessRights` 単体が正しくても、`fetchStudyPool` で反映し忘れれば
/// 課金の意味が無くなる。ここは繋ぎ込みの検証。
@MainActor
final class PurchaseGateTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var repository: WordRepository!
    private var previousIncludesBasicTier = false

    override func setUpWithError() throws {
        let schema = Schema([WordMaster.self, UserProgress.self, StudyLog.self, TypingScore.self, UserWord.self])
        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        context = container.mainContext
        repository = WordRepository(context: context)

        // 出題範囲の設定は端末に保存されるため、テストの都合で変えたら必ず戻す
        previousIncludesBasicTier = StudySettings.includesBasicTier
        StudySettings.includesBasicTier = false

        insert(tier: .basic, count: 5)
        insert(tier: .bridge, count: 3)
        insert(tier: .core, count: 4)
    }

    override func tearDownWithError() throws {
        StudySettings.includesBasicTier = previousIncludesBasicTier
        repository = nil
        context = nil
        container = nil
    }

    private func insert(tier: VocabularyTier, count: Int) {
        for index in 0..<count {
            context.insert(
                WordMaster(
                    wordId: "\(tier.rawValue)-\(index)",
                    word: "word\(tier.rawValue)\(index)",
                    meaning: "意味\(index)",
                    example: "",
                    frequencyCount: 0,
                    category: .a,
                    partOfSpeech: .noun,
                    tier: tier
                )
            )
        }
    }

    /// 未購入・試用終了では 2級コア語彙が出題されないこと
    func testLockedPoolExcludesCoreWords() {
        let pool = repository.fetchStudyPool(availableTiers: AccessRights.locked.availableTiers)

        XCTAssertEqual(pool.count, 3, "架け橋層の3語だけが残るはず")
        XCTAssertFalse(pool.contains { $0.tier == .core })
    }

    /// 試用中・購入済みでは全語が出題対象になること
    func testFullAccessPoolIncludesCoreWords() {
        let rights = AccessRights(isPurchased: false, isTrialActive: true)

        let pool = repository.fetchStudyPool(availableTiers: rights.availableTiers)

        XCTAssertEqual(pool.count, 7, "架け橋3語 + 2級コア4語")
        XCTAssertEqual(pool.filter { $0.tier == .core }.count, 4)
    }

    /// 「基礎語彙も出題する」を入れても、権利が無ければ 2級コアは増えないこと。
    /// 設定と権利を掛け合わせている（片方だけ見ていない）ことの確認。
    func testBasicTierSettingDoesNotUnlockCoreWords() {
        StudySettings.includesBasicTier = true

        let pool = repository.fetchStudyPool(availableTiers: AccessRights.locked.availableTiers)

        XCTAssertEqual(pool.count, 8, "基礎5語 + 架け橋3語")
        XCTAssertFalse(pool.contains { $0.tier == .core })
    }

    /// 自分で追加した単語は、階層にも権利にも関わらず必ず出題対象に入ること
    func testUserAddedWordIsAlwaysIncluded() throws {
        try UserWordRepository(context: context).add(
            word: "serendipity",
            meaning: "偶然の幸運",
            example: "",
            category: .c,
            partOfSpeech: .noun
        )

        let pool = repository.fetchStudyPool(availableTiers: AccessRights.locked.availableTiers)

        XCTAssertTrue(
            pool.contains { $0.word == "serendipity" },
            "自分で入れた単語が出てこないのは、どんな理由であれ意図に反する"
        )
    }
}
