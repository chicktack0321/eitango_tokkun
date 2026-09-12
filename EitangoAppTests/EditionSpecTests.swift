import XCTest
@testable import EitangoApp

/// エディション定義の完全性と、公開中の 1.0 と同じ文言が出ることを検証する。
///
/// 級固有の文言を `Editions/<ID>/Edition.swift` へ移したため、転記漏れがあっても
/// ビルドは通ってしまい、画面の文言だけが静かに変わる。公開済みの2級アプリでは
/// それが審査済みのスクリーンショットとのズレになるので、値を直接押さえる。
final class EditionSpecTests: XCTestCase {

    private let spec = Edition.current

    /// 階層の表示名・説明は全 case に定義が要る。
    /// 欠けていると既定値で埋まり、画面に級名の無いラベルが出る。
    func testEveryTierHasDisplayNameAndSummary() {
        for tier in VocabularyTier.allCases {
            XCTAssertNotNil(spec.tierDisplayNames[tier], "tierDisplayNames に \(tier) が無い")
            XCTAssertNotNil(spec.tierSummaries[tier], "tierSummaries に \(tier) が無い")
            XCTAssertFalse(tier.displayName.isEmpty)
            XCTAssertFalse(tier.summary.isEmpty)
        }
    }

    /// 公開中のビルドと同じ文言であること（UIテストのスクリーンショットが基準）
    func testG2StringsMatchShippedBuild() {
        XCTAssertEqual(spec.id, "G2")
        XCTAssertEqual(spec.appDisplayName, "英単語特訓")
        XCTAssertEqual(spec.gradeDisplayName, "英検®2級")
        XCTAssertEqual(VocabularyTier.basic.displayName, "基礎")
        XCTAssertEqual(VocabularyTier.bridge.displayName, "架け橋")
        XCTAssertEqual(VocabularyTier.core.displayName, "2級コア")
        XCTAssertEqual(spec.coreVocabularyName, "2級コア発展語彙")
        XCTAssertEqual(spec.paywallTitle, "2級コア語彙の解放")
        XCTAssertEqual(spec.nowPlayingAlbumTitle, "英検2級 英単語特訓")
    }

    /// プロダクトIDを変えると購入済みユーザーの復元が壊れる。
    /// wordId のプレフィクスは学習履歴のキーなので、こちらも固定。
    func testPurchaseAndIdentityConstantsAreFrozen() {
        XCTAssertEqual(spec.unlockProductID, "com.eitango.app.unlock.grade2")
        XCTAssertEqual(EditionSpec.seedResourceName, "word_master_seed")
    }

    /// 商標表記とURLは審査で見られる。空や http は事故になる。
    func testNoticesAndURLs() {
        XCTAssertTrue(spec.trademarkNotice.contains("登録商標"))
        XCTAssertEqual(spec.privacyPolicyURL.scheme, "https")
        XCTAssertEqual(spec.supportURL.scheme, "https")
    }
}
