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

        // iマークの説明。以前は吹き出し（ポップオーバー）で本文の幅・高さが詰められ、
        // 最も長い「習熟度」の説明が見切れていたため、全文が読めることを毎回撮って確かめる。
        let masteryInfo = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH '習熟度' AND label ENDSWITH 'の説明'"))
            .firstMatch
        if masteryInfo.waitForExistence(timeout: 5) {
            if !masteryInfo.isHittable {
                app.swipeUp()
                settle()
            }
            if masteryInfo.isHittable {
                masteryInfo.tap()
                settle()
                capture(app, "01a_MetricInfo")

                let closeButton = app.buttons["閉じる"]
                if closeButton.waitForExistence(timeout: 5) {
                    closeButton.tap()
                    settle()
                }
            }
        }

        // ホームから学習の記録へ push して戻る。
        // カードは画面下方にあり初期表示では隠れていることがあるので、必要なら送る。
        let historyLink = app.buttons["historyCardLink"]
        if historyLink.waitForExistence(timeout: 5) {
            if !historyLink.isHittable {
                app.swipeUp()
                settle()
            }
            if historyLink.isHittable {
                historyLink.tap()
                settle()
                capture(app, "01b_StudyHistory")

                let backButton = app.navigationBars.buttons.element(boundBy: 0)
                if backButton.waitForExistence(timeout: 5) {
                    backButton.tap()
                    settle()
                }
            }
        }

        let wordListTab = app.tabBars.buttons["単語帳"]
        if wordListTab.waitForExistence(timeout: 10) {
            wordListTab.tap()
            settle()
            capture(app, "02_WordList")

            // 単語はアルファベット順に並ぶ。語彙が増えると特定の語は画面外に出るため、
            // 見出しの語名ではなく「絞り込み行の次のセル＝最初の単語」を開く。
            let firstWord = app.cells.element(boundBy: 3)
            if firstWord.waitForExistence(timeout: 5), firstWord.isHittable {
                firstWord.tap()
                settle()
                capture(app, "03_WordDetail")

                let backButton = app.navigationBars.buttons.element(boundBy: 0)
                if backButton.waitForExistence(timeout: 5) {
                    backButton.tap()
                    settle()
                }
            }

            captureAddWordSpellCheck(app)
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

    /// 単語追加のスペルチェック。わざと綴りを間違えて、警告と候補が出ることを撮る。
    /// 終わったら必ずシートを閉じる（開いたままだとソフトウェアキーボードが残り、
    /// 以降のタブ操作が届かなくなる）。
    private func captureAddWordSpellCheck(_ app: XCUIApplication) {
        let addButton = app.buttons["addWordButton"]
        guard addButton.waitForExistence(timeout: 5), addButton.isHittable else { return }
        addButton.tap()
        settle()

        let wordField = app.textFields["英単語"]
        if wordField.waitForExistence(timeout: 5) {
            wordField.tap()
            wordField.typeText("oportunity")

            let addConfirm = app.buttons["追加"]
            if addConfirm.exists {
                addConfirm.tap()
                settle()
                capture(app, "02b_AddWord_SpellCheck")
            }
        }

        let cancel = app.buttons["キャンセル"]
        if cancel.waitForExistence(timeout: 5) {
            cancel.tap()
            settle()
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
