import XCTest
@testable import EitangoApp

/// 権利判定と試用期間をテストする。
///
/// ここが壊れても画面上は正常に見え、「本来買うはずの人に全語彙が出続ける」または
/// 「買った人に出ない」という形で静かに損害が出るため、境界を細かく押さえる。
@MainActor
final class EntitlementTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        // 実機やCIの設定を汚さないよう、テストごとに専用の保存領域を使う
        suiteName = "EntitlementTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
    }

    private func day(_ offset: Int, from base: Date) -> Date {
        base.addingTimeInterval(Double(offset) * 86_400)
    }

    // MARK: - 出題範囲

    func testLockedRightsExcludeCoreTier() {
        let rights = AccessRights.locked
        XCTAssertFalse(rights.hasFullAccess)
        XCTAssertEqual(rights.availableTiers, [.basic, .bridge])
        XCTAssertFalse(rights.availableTiers.contains(.core))
    }

    func testTrialGivesAllTiers() {
        let rights = AccessRights(isPurchased: false, isTrialActive: true)
        XCTAssertTrue(rights.hasFullAccess)
        XCTAssertEqual(rights.availableTiers, Set(VocabularyTier.allCases))
    }

    /// 購入済みなら試用が終わっていても全階層が使えること
    func testPurchaseGivesAllTiersAfterTrialEnds() {
        let rights = AccessRights(isPurchased: true, isTrialActive: false)
        XCTAssertTrue(rights.hasFullAccess)
        XCTAssertTrue(rights.availableTiers.contains(.core))
    }

    // MARK: - 試用期間

    func testTrialIsActiveOnFirstLaunch() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let trial = TrialManager(defaults: defaults)

        trial.startIfNeeded(now: start)

        XCTAssertTrue(trial.isActive(now: start))
        XCTAssertEqual(trial.daysRemaining(now: start), TrialManager.trialDays)
    }

    /// 起点は初回だけ記録され、あとから起動しても延びないこと
    func testTrialStartIsRecordedOnlyOnce() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let trial = TrialManager(defaults: defaults)

        trial.startIfNeeded(now: start)
        trial.startIfNeeded(now: day(5, from: start))

        XCTAssertEqual(trial.startedAt, start)
        XCTAssertEqual(trial.daysRemaining(now: day(5, from: start)), TrialManager.trialDays - 5)
    }

    /// 期間の内と外の境界。14日目は使えて、15日目には終わっていること
    func testTrialEndsAfterFourteenDays() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let trial = TrialManager(defaults: defaults)
        trial.startIfNeeded(now: start)

        XCTAssertTrue(trial.isActive(now: day(13, from: start)), "13日目はまだ試用中であるべき")
        XCTAssertFalse(trial.isActive(now: day(14, from: start)), "14日ちょうどで終了する")
        XCTAssertFalse(trial.isActive(now: day(15, from: start)))
        XCTAssertNil(trial.daysRemaining(now: day(15, from: start)))
    }

    /// 端末の時計を戻しても試用が復活しないこと。
    /// サーバーを持たない以上ここが唯一の防御線になる。
    func testTrialDoesNotRevivewWhenClockIsTurnedBack() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let trial = TrialManager(defaults: defaults)
        trial.startIfNeeded(now: start)

        // 20日後まで進めて試用を終わらせる
        trial.startIfNeeded(now: day(20, from: start))
        XCTAssertFalse(trial.isActive(now: day(20, from: start)))

        // 時計を初日に戻す
        trial.startIfNeeded(now: start)

        XCTAssertFalse(trial.isActive(now: start), "時計を戻しただけで試用が戻ってはいけない")
        XCTAssertNil(trial.daysRemaining(now: start))
    }

    /// 残り日数は切り上げ。残り数時間でも「残り1日」と出て、0日とは出ないこと
    func testDaysRemainingIsRoundedUp() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let trial = TrialManager(defaults: defaults)
        trial.startIfNeeded(now: start)

        let almostOver = start.addingTimeInterval(Double(TrialManager.trialDays) * 86_400 - 3_600)
        XCTAssertEqual(trial.daysRemaining(now: almostOver), 1)
    }
}
