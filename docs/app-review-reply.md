# App Review 2.1（Information Needed）への返信

Submission ID: `a9a3a33a-f64f-49cb-8474-5be16bb9305c` / 1.0 for iOS

コードの修正は不要。**聞かれた8項目に答える文面**と**実機の画面収録**を出せば足りる。
差し戻しの本文は「バグがある」ではなく「審査に必要な情報が App Review Information に
入っていない」という意味で、実際 4-5「App Review に関する情報」の備考が
`store-listing.md` の審査メモだけでは8項目をカバーしていない。

やることは3つ。

1. 実機で画面収録を撮る（項目1。これだけ手間がかかる）
2. 下の英文を App Store Connect の返信に貼り、収録動画を添付する
3. 同じ英文を「App Review に関する情報」→ 備考にも入れて再提出する

備考にも入れておくのは、次のバージョンで同じ質問を繰り返されないため
（Appleの文面の "Include this information in the Notes field ... for future submissions"）。

---

## 1. 画面収録の撮り方（Macなしで完結する）

Appleは **physical device**（実機）での収録を求めている。シミュレータの録画は使えない。
手元のiPhoneに TestFlight で入れて、iOS標準の画面収録で撮ればよい。

1. Actions → **TestFlight** を手動実行し、自分のiPhoneに TestFlight から入れる
2. 設定 → コントロールセンター → 「画面収録」を追加
3. **アプリを一度削除してから**収録を開始する（初回起動・試用開始から映す必要がある）
4. 下の順に操作する。全体で3〜5分に収める

| 順 | 映すもの | 理由（Appleの要求のどれに対応するか） |
| --- | --- | --- |
| 1 | ホーム画面からアプリを起動 | "must begin with launching the app" |
| 2 | 単語帳 → 検索・絞り込み → 単語詳細 → 音声再生 | コア機能 |
| 3 | 4択クイズを数問 → 結果画面 | コア機能 |
| 4 | タイピング → 聞き流し | コア機能 |
| 5 | 学習の記録（グラフ） | コア機能 |
| 6 | ホーム →「このアプリについて」→ 商標表記・購入を復元 | 権利表記と復元導線の所在 |
| 7 | ホームの利用状況カード → 購入画面 → **実際に購入まで完了** | "including any in-app purchase flows" |
| 8 | 購入後にクイズで全語彙が出題対象になったところ | 課金で何が変わるか |

**7が最重要。** 8項目目でも別途聞かれている（"What the user can buy with In-App Purchase and
how to navigate to the purchase locations"）ので、購入シートの価格表示と完了までを必ず映す。

TestFlightのビルドは自動的にStoreKitのサンドボックスになるため、**実際に課金は発生しない**。
サンドボックステスターの作成も不要で、そのiPhoneのApple Accountのまま購入できる。

収録後、写真アプリから動画を書き出し、App Store Connect の返信に**添付**する
（外部リンクを貼るより添付のほうが確実）。長い場合は解像度を落として構わない。

---

## 2. 返信に貼る英文

App Store Connect → App Review → 返信欄。項目番号はAppleの質問と対応させてある。

```
Thank you for the review. Please find the requested information below.
A screen recording captured on a physical device is attached to this message.

1. Screen recording
Attached. It starts from launching the app on a physical iPhone and covers the
word list, multiple-choice quiz, typing practice, listening playback, study
history, the About screen (trademark notice and Restore Purchases), and the
complete in-app purchase flow including the purchase confirmation.
The app has no account registration, no login, and no account deletion flow,
because it stores no user account of any kind.
The app requests no permissions and shows no system permission prompts
(no location, contacts, camera, microphone, notifications, or App Tracking
Transparency). It contains no Info.plist usage description strings.

2. Devices and operating systems tested
- <あなたの実機。例: iPhone 15 Pro, iOS 26.0>
- iPhone 16 Pro Max Simulator, iOS 18.x (automated UI tests on CI)
Minimum supported version is iOS 17.0. The app is iPhone-only
(TARGETED_DEVICE_FAMILY = 1).

3. Functions and target audience
The app is an offline English vocabulary trainer for Japanese learners
preparing for the Eiken Grade 2 English proficiency test, mainly high school
students and adult learners in Japan.
Problem it solves: existing vocabulary apps require sign-up and a network
connection, and interrupt study with advertisements. This app requires neither,
so it can be used on a commuter train or in a classroom where connectivity is
unavailable, and it stores nothing about the user outside the device.
It contains 3,955 words with meanings and example sentences, and provides four
study modes (word list with search and filters, four-choice quiz, typing
practice, and audio listening) plus a study history chart. Review order is
scheduled by a Leitner-style spaced repetition algorithm that runs entirely
on device.
The app contains no advertising and no subscriptions.

4. Setup and access instructions
No setup, login credentials, or sample files are required. All content is
bundled in the app and is available immediately on first launch.
- Word list: "単語帳" tab
- Quiz: "クイズ" tab
- Typing: "タイピング" tab
- Listening: "聞き流し" tab
- Study history: Home -> the weekly chart
- Trademark notice, privacy policy, support contact, and Restore Purchases:
  Home -> "このアプリについて" (About)

5. External services, tools, and platforms
None. The app makes no network requests of its own. It has no backend server,
no analytics, no advertising SDK, no authentication service, no AI service, and
no third-party SDK of any kind.
- Vocabulary data: bundled JSON authored by us, read from the app bundle
- Audio: AVSpeechSynthesizer (Apple's on-device text-to-speech). No audio files
  are bundled and no cloud TTS is used
- Storage: SwiftData and UserDefaults, on device only
- Payments: StoreKit 2 only
The only network traffic the app can cause is Apple's own traffic for purchase
and restore. Accordingly, our App Privacy declaration is "Data Not Collected",
which matches the implementation.

6. Regional differences
There are none. The app behaves identically in all regions and contains the
same content everywhere. Its user interface is Japanese only, and it is
distributed worldwide because the target audience includes Japanese learners
living outside Japan. There is no region-based gating, no remote configuration,
and no server that could vary the content by region.

7. Regulated industry / third-party protected material
The app is not part of a regulated industry and contains no third-party
protected material.
All 3,955 words, Japanese meanings, and example sentences were written by us for
this app. No content is reproduced from any published vocabulary book, from the
Eiken test itself, or from any other third-party source. Accordingly, Content
Rights in App Information is declared as "Does Not Contain, Show, or Access
Third-Party Content".
"英検" (Eiken) is a registered trademark of the Eiken Foundation of Japan. We
are not affiliated with, endorsed by, or authorized by the Eiken Foundation, and
we do not claim to be. The name is used descriptively, only to identify the
examination the vocabulary is aimed at. A disclaimer to that effect is shown
inside the app (Home -> "このアプリについて") and in the App Store description.
If you would prefer that the trademark be removed from the app name or icon, we
will submit a revised build promptly.

8. In-App Purchase
There is exactly one in-app purchase, and it is a one-time non-consumable
purchase. There is no subscription and no auto-renewal.
- Product ID: com.eitango.app.unlock.grade2
- Name: 2級コア発展語彙の解放 (Unlock Grade 2 core advanced vocabulary)
- Type: Non-Consumable, JPY 500
What the user buys: it adds the 1,274 advanced words (Tier 3) to the pool of
words used by the quiz, typing, and listening modes, permanently.
How to reach the purchase screen (both paths are in the recording):
- Home -> the access status card at the top of the screen -> purchase sheet
- クイズ (Quiz) tab -> the "locked" notice -> purchase sheet
Restore Purchases is available in two places: on the purchase sheet, and at
Home -> "このアプリについて".

Important clarification about the trial (this app is not a trial version):
For the first 14 days after installation, all 3,955 words are included in the
study pool. After 14 days, every feature keeps working exactly as before -
quiz, typing, listening, study history, search, and audio playback are never
disabled. The only change is that the quiz/typing/listening pool is reduced to
2,681 words, and the remaining 1,274 words are what the purchase unlocks. The
word list itself continues to show, search, and pronounce all 3,955 words
regardless of purchase. No functionality expires.

Contact: <氏名 / メールアドレス>
```

**`<>` の3か所は自分で埋める。** 特に項目2の実機は嘘を書けない
（実際に収録した端末とOSを書く）。iOSのバージョンは 設定 → 一般 → 情報 で確認する。

---

## 3. 想定される次の一手

今回は2.1の情報要求なので、上記を出せば審査は再開する。ただし項目7で商標に触れられた以上、
次に **5.2.1（他社の商標・権利）** を指摘される可能性は残る。指摘されたときの備えは
`appstore-submission.md` に書いたとおりで、

- アプリ名から `英検®` を外し `英単語特訓 2級 4000語` にする
- アイコンから「英検」の文字を外した版に差し替える

の2点。返信文の項目7の末尾に「求められれば速やかに差し替える」と先に書いてあるのは、
再度の差し戻しではなく修正指示として返ってくるようにするため。

なお **App名の変更はバージョンのメタデータなので、ビルドの再アップロードは要らない**。
アイコンを変える場合はビルドの作り直しが要る。
