import XCTest
import SwiftData
@testable import EitangoApp

/// 「覚えた語数」の集計をテストする。
///
/// この数字はホームの習熟度・単語帳・学習の記録の3か所に出るが、それぞれ別の経路で数えていた。
/// 食い違っても画面を見比べないと気付けないため、数え方の境界をここで押さえる。
@MainActor
final class MasteryBreakdownTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([WordMaster.self, UserProgress.self, StudyLog.self])
        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
    }

    // MARK: - 内訳の絞り込み

    private func breakdown() -> [String: Int] {
        [
            key(tier: .basic, category: .a, domain: .general): 3,
            key(tier: .core, category: .a, domain: .general): 5,
            key(tier: .core, category: .b, domain: .general): 7,
            MasteryBreakdown.userWordsKey: 2
        ]
    }

    private func key(tier: VocabularyTier, category: FrequencyRank, domain: VocabularyDomain) -> String {
        "\(tier.rawValue)|\(category.rawValue)|\(domain.rawValue)"
    }

    func testDefaultScopeCountsEveryCell() {
        XCTAssertEqual(MasteryBreakdown.count(in: breakdown(), scope: .default), 17)
    }

    /// 階層を選んでいないときは全階層を数える。出題と違い、集計では基礎語彙も含める。
    func testTierFilterKeepsUserWords() {
        var scope = StudyScope()
        scope.tier = .core
        // 5 + 7 に、階層の指定に関わらず対象になる自分の単語 2 を足す
        XCTAssertEqual(MasteryBreakdown.count(in: breakdown(), scope: scope), 14)
    }

    func testCategoryAndTierCombineAsAnd() {
        var scope = StudyScope()
        scope.tier = .core
        scope.category = .b
        XCTAssertEqual(MasteryBreakdown.count(in: breakdown(), scope: scope), 9) // 7 + 自分の単語2
    }

    func testDomainFilterExcludesOtherDomains() {
        var scope = StudyScope()
        scope.domain = .education
        XCTAssertEqual(MasteryBreakdown.count(in: breakdown(), scope: scope), 2) // 自分の単語のみ
    }

    func testOnlyUserWordsCountsUserBucketAlone() {
        var scope = StudyScope()
        scope.onlyUserWords = true
        XCTAssertEqual(MasteryBreakdown.count(in: breakdown(), scope: scope), 2)
    }

    // MARK: - 内訳を持たない日

    /// 内訳は後から足した項目なので、それ以前の記録は範囲で分けられない。
    /// 0と混同すると「その期間だけ覚えた語が消えた」ように見えるため、nilで区別する。
    func testDayWithoutBreakdownCannotBeFiltered() {
        let day = DailyStudy(
            date: .now,
            studiedWordCount: 1,
            correctCount: 1,
            attemptCount: 1,
            masteredWordCount: 12
        )
        var scope = StudyScope()
        scope.tier = .core

        XCTAssertNil(day.masteredCount(scope: scope))
        // 範囲を指定していなければ合計値で描けるので、内訳が無くても数えられる
        XCTAssertEqual(day.masteredCount(scope: .default), 12)
    }

    func testZeroMasteredIsCountedAsZeroNotUnknown() {
        let day = DailyStudy(date: .now, studiedWordCount: 0, correctCount: 0, attemptCount: 0)
        var scope = StudyScope()
        scope.tier = .core
        XCTAssertEqual(day.masteredCount(scope: scope), 0)
    }

    // MARK: - 実在しない語を数えない

    /// 単語マスターを入れ替えても UserProgress は残す設計（WordMasterSeeder 参照）。
    /// 進捗の行を全部数えると、単語データの更新で消えた語まで「覚えた」に含まれ、
    /// 単語帳やホームの習熟度と数が合わなくなる。
    func testSnapshotIgnoresProgressForWordsThatNoLongerExist() throws {
        let repository = ProgressRepository(context: context)

        context.insert(makeWord(id: "EXISTS", tier: .core, category: .a, domain: .general))
        context.insert(memorizedProgress(wordId: "EXISTS"))
        // 単語マスターには無いが進捗だけ残っている語
        context.insert(memorizedProgress(wordId: "REMOVED"))
        try context.save()

        let snapshot = repository.masteredSnapshot()

        XCTAssertEqual(snapshot.total, 1)
        XCTAssertEqual(snapshot.breakdown.values.reduce(0, +), 1)
    }

    /// スナップショットの合計と、単語帳・ホームが使う集計が一致すること
    func testSnapshotMatchesSummarizeForTheSameWords() throws {
        let repository = ProgressRepository(context: context)

        let words = [
            makeWord(id: "A", tier: .basic, category: .a, domain: .general),
            makeWord(id: "B", tier: .core, category: .b, domain: .general),
            makeWord(id: "C", tier: .core, category: .b, domain: .general)
        ]
        words.forEach { context.insert($0) }
        context.insert(memorizedProgress(wordId: "A"))
        context.insert(memorizedProgress(wordId: "B"))
        // C は一度も解いていないので進捗の行を作らない
        try context.save()

        let snapshot = repository.masteredSnapshot()
        let summary = repository.summarize(words: words)

        XCTAssertEqual(snapshot.total, summary.count(of: .memorized))
    }

    private func makeWord(
        id: String,
        tier: VocabularyTier,
        category: FrequencyRank,
        domain: VocabularyDomain
    ) -> WordMaster {
        WordMaster(
            wordId: id,
            word: id.lowercased(),
            meaning: "意味",
            example: "",
            frequencyCount: 0,
            category: category,
            partOfSpeech: .noun,
            tier: tier,
            domain: domain
        )
    }

    /// 「覚えた」段階（7日以上の間隔に到達し、まだ期限が来ていない）の進捗を作る
    private func memorizedProgress(wordId: String) -> UserProgress {
        UserProgress(
            wordId: wordId,
            lastReviewedAt: .now,
            correctCount: 5,
            attemptCount: 5,
            reviewBox: UserProgress.masteredBox,
            nextReviewAt: Calendar.current.date(byAdding: .day, value: 7, to: .now)
        )
    }
}
