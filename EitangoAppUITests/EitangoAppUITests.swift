import XCTest

/// 実機やMacが手元になくても各画面の見た目を確認できるよう、主要画面を一通り遷移しながら
/// スクリーンショットを撮る。CIでは `xcparse` を使って `.xcresult` からPNGとして取り出し、
/// ワークフローのアーティファクトとしてアップロードする（ワークフロー側の設定を参照）。
final class EitangoAppUITests: XCTestCase {

    override func setUpWithError() throws {
        // 1画面の遷移に失敗しても、それまでに撮れたスクリーンショットは失わずに済むよう続行する
        continueAfterFailure = true
    }

    func testCaptureAllScreens() throws {
        let app = XCUIApplication()
        app.launch()

        capture(app, "01_Home")

        // ホームから学習の記録へ push して戻る
        let historyLink = app.buttons["学習の記録"].firstMatch
        if historyLink.waitForExistence(timeout: 5) {
            historyLink.tap()
            settle()
            capture(app, "01b_StudyHistory")

            let backButton = app.navigationBars.buttons.element(boundBy: 0)
            if backButton.waitForExistence(timeout: 5) {
                backButton.tap()
                settle()
            }
        }

        let wordListTab = app.tabBars.buttons["単語帳"]
        if wordListTab.waitForExistence(timeout: 10) {
            wordListTab.tap()
            settle()
            capture(app, "02_WordList")

            // word_master_seed.json の並び順（wordId昇順）で最初に来る語
            let firstWord = app.staticTexts["opportunity"]
            if firstWord.waitForExistence(timeout: 5) {
                firstWord.tap()
                settle()
                capture(app, "03_WordDetail")

                let backButton = app.navigationBars.buttons.element(boundBy: 0)
                if backButton.waitForExistence(timeout: 5) {
                    backButton.tap()
                    settle()
                }
            }
        }

        let quizTab = app.tabBars.buttons["4択クイズ"]
        if quizTab.waitForExistence(timeout: 5) {
            quizTab.tap()
            settle()
            capture(app, "04_Quiz_Start")

            let startButton = app.buttons["スタート"]
            if startButton.waitForExistence(timeout: 5) {
                startButton.tap()
                settle()
                capture(app, "05_Quiz_Playing")
            }
        }

        let listeningTab = app.tabBars.buttons["聞き流し"]
        if listeningTab.waitForExistence(timeout: 5) {
            listeningTab.tap()
            settle()
            capture(app, "06_Listening")
        }

        // タイピングはソフトウェアキーボードが画面下部（タブバーの上）に出たままになり、
        // 以降タブバーへのタップが届かなくなる。他のタブへ遷移する必要がある画面より後、
        // このテストの最後に実行する。
        let typingTab = app.tabBars.buttons["タイピング"]
        if typingTab.waitForExistence(timeout: 5) {
            typingTab.tap()
            settle()
            capture(app, "07_Typing_Start")

            let startButton = app.buttons["スタート"]
            if startButton.waitForExistence(timeout: 5) {
                startButton.tap()
                settle()
                capture(app, "08_Typing_Playing")
            }
        }
    }

    /// 画面遷移アニメーションが落ち着くのを待つ（厳密な待機条件がない箇所向けの簡易対応）
    private func settle() {
        Thread.sleep(forTimeInterval: 1)
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
