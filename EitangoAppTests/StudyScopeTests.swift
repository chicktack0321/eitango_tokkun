import XCTest
@testable import EitangoApp

/// 出題・集計の範囲を絞る条件をテストする。
///
/// 「自分で追加した単語は必ず出る」「権利の無い階層は選んでも出ない」といった
/// 例外が絡むため、条件の組み合わせを個別に押さえる。
final class StudyScopeTests: XCTestCase {

    private func word(
        id: String = "w1",
        tier: VocabularyTier = .core,
        category: FrequencyRank = .a,
        domain: VocabularyDomain = .general,
        source: WordSource = .bundled
    ) -> WordMaster {
        WordMaster(
            wordId: id,
            word: "word",
            meaning: "意味",
            example: "",
            frequencyCount: 0,
            category: category,
            partOfSpeech: .noun,
            source: source,
            tier: tier,
            domain: domain
        )
    }

    private let allTiers = Set(VocabularyTier.allCases)

    // MARK: - 階層

    /// 既定では基礎（既習）を出題しない
    func testDefaultScopeExcludesBasicTier() {
        let scope = StudyScope.default

        XCTAssertFalse(scope.contains(word(tier: .basic), availableTiers: allTiers, unspecified: StudyScope.studyDefaultTiers))
        XCTAssertTrue(scope.contains(word(tier: .bridge), availableTiers: allTiers, unspecified: StudyScope.studyDefaultTiers))
        XCTAssertTrue(scope.contains(word(tier: .core), availableTiers: allTiers, unspecified: StudyScope.studyDefaultTiers))
    }

    /// 階層を選ぶと、その階層だけになる（基礎も明示すれば選べる）
    func testSelectingTierNarrowsToThatTierOnly() {
        var scope = StudyScope.default
        scope.tier = .basic

        XCTAssertTrue(scope.contains(word(tier: .basic), availableTiers: allTiers, unspecified: StudyScope.studyDefaultTiers))
        XCTAssertFalse(scope.contains(word(tier: .core), availableTiers: allTiers, unspecified: StudyScope.studyDefaultTiers))
    }

    /// 権利の無い階層は、選んでも出題されない。
    /// 範囲の指定で課金を迂回できてはいけない。
    func testSelectedTierIsStillLimitedByRights() {
        var scope = StudyScope.default
        scope.tier = .core

        XCTAssertFalse(
            scope.contains(word(tier: .core), availableTiers: AccessRights.locked.availableTiers, unspecified: StudyScope.studyDefaultTiers)
        )
    }

    // MARK: - 頻出度・分野

    func testCategoryAndDomainNarrowTheScope() {
        var scope = StudyScope.default
        scope.category = .a
        scope.domain = .environment

        XCTAssertTrue(
            scope.contains(word(category: .a, domain: .environment), availableTiers: allTiers, unspecified: StudyScope.studyDefaultTiers)
        )
        XCTAssertFalse(
            scope.contains(word(category: .b, domain: .environment), availableTiers: allTiers, unspecified: StudyScope.studyDefaultTiers)
        )
        XCTAssertFalse(
            scope.contains(word(category: .a, domain: .health), availableTiers: allTiers, unspecified: StudyScope.studyDefaultTiers)
        )
    }

    // MARK: - 自分で追加した単語

    /// 自分で入れた語が出てこないのは、どんな理由であれ意図に反する。
    /// 階層・分野・権利のどれでも弾かれないこと。
    func testUserWordIsAlwaysIncluded() {
        var scope = StudyScope.default
        scope.tier = .basic
        scope.domain = .environment

        let mine = word(tier: .core, domain: .health, source: .user)

        XCTAssertTrue(scope.contains(mine, availableTiers: AccessRights.locked.availableTiers, unspecified: StudyScope.studyDefaultTiers))
    }

    /// 「自分の単語のみ」を選ぶと、同梱の語は他の条件に関わらず外れる
    func testOnlyUserWordsExcludesEverythingElse() {
        var scope = StudyScope.default
        scope.onlyUserWords = true

        XCTAssertTrue(scope.contains(word(source: .user), availableTiers: allTiers, unspecified: StudyScope.studyDefaultTiers))
        XCTAssertFalse(scope.contains(word(source: .bundled), availableTiers: allTiers, unspecified: StudyScope.studyDefaultTiers))
    }

    // MARK: - 「未指定」の意味は用途で変わる

    /// 習熟度の集計では、階層を選んでいなければ基礎語彙も数に入ること。
    /// 「すべて」を選んだのに基礎が抜けていては、何を見ている数字なのか分からない。
    func testUnspecifiedTierCoversEveryTierWhenSummarizing() {
        let scope = StudyScope.default

        XCTAssertTrue(
            scope.contains(word(tier: .basic), availableTiers: allTiers, unspecified: StudyScope.allTiers)
        )
        XCTAssertTrue(
            scope.contains(word(tier: .core), availableTiers: allTiers, unspecified: StudyScope.allTiers)
        )
    }

    /// 同じ「未指定」でも、出題では基礎を外すこと（用途で意味が変わる）
    func testUnspecifiedTierExcludesBasicWhenStudying() {
        let scope = StudyScope.default

        XCTAssertFalse(
            scope.contains(word(tier: .basic), availableTiers: allTiers, unspecified: StudyScope.studyDefaultTiers)
        )
    }

    // MARK: - 表示

    func testSummaryDescribesTheScope() {
        XCTAssertEqual(StudyScope.default.summary, "すべて")

        var scope = StudyScope.default
        scope.tier = .core
        scope.domain = .environment
        XCTAssertEqual(scope.summary, "2級コア / 環境")

        scope.onlyUserWords = true
        XCTAssertEqual(scope.summary, "自分で追加した単語のみ")
    }
}
