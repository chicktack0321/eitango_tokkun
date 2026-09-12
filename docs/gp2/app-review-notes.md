# App Review に関する情報（備考欄）— 英検準2級（GP2）

App Store Connect → バージョン → 「App Review に関する情報」→ 備考 に**そのまま貼る**。

2級の初回審査で 2.1（Information Needed）の差し戻しを受け、8項目を聞かれた
（`docs/app-review-reply.md`）。Apple の返信には
"Include this information in the Notes field ... for future submissions" とあるため、
**準2級では最初から8項目すべてを備考に入れて提出する**。同じ質問で止められないための予防。

`<>` の箇所は提出前に自分で埋める。項目2の実機は嘘を書けない。

---

```
The following covers the information typically requested during review.

1. App overview and media
This app has no account registration, no login, and no account deletion flow,
because it stores no user account of any kind.
The app requests no permissions and shows no system permission prompts
(no location, contacts, camera, microphone, notifications, or App Tracking
Transparency). It contains no Info.plist usage description strings.
A screen recording captured on a physical device can be provided on request.

2. Devices and operating systems tested
- <あなたの実機。例: iPhone 15 Pro, iOS 26.0>
- iPhone 16 Pro Max Simulator, iOS 18.x (automated UI tests on CI)
Minimum supported version is iOS 17.0. The app is iPhone-only
(TARGETED_DEVICE_FAMILY = 1).

3. Functions and target audience
The app is an offline English vocabulary trainer for Japanese learners
preparing for the Eiken Grade Pre-2 English proficiency test, mainly junior
high school third-year and high school first-year students in Japan.
Problem it solves: existing vocabulary apps require sign-up and a network
connection, and interrupt study with advertisements. This app requires neither,
so it can be used on a commuter train or in a classroom where connectivity is
unavailable, and it stores nothing about the user outside the device.
It contains 3,325 words with meanings and example sentences, including 637
idioms and phrasal verbs, and provides four study modes (word list with search
and filters, four-choice quiz, typing practice, and audio listening) plus a
study history chart. Review order is scheduled by a Leitner-style spaced
repetition algorithm that runs entirely on device.
The app contains no advertising and no subscriptions.

This app is part of a series. We also publish the same application for other
Eiken grades, differing only in the bundled vocabulary data:
Grade 2 (com.eitango.app), Grade 3 (com.eitango.g3), and Grade 4
(com.eitango.g4). Grade 3 and Grade 4 are free and contain no in-app purchase.

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
All 3,325 words, Japanese meanings, and example sentences were written by us for
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
- Product ID: com.eitango.gp2.unlock.core
- Name: 準2級コア発展語彙の解放 (Unlock Grade Pre-2 core advanced vocabulary)
- Type: Non-Consumable, JPY 500
What the user buys: it adds the 1,182 advanced words (Tier 3) to the pool of
words used by the quiz, typing, and listening modes, permanently.
How to reach the purchase screen:
- Home -> the access status card at the top of the screen -> purchase sheet
- クイズ (Quiz) tab -> the "locked" notice -> purchase sheet
Restore Purchases is available in two places: on the purchase sheet, and at
Home -> "このアプリについて".

Important clarification about the trial (this app is not a trial version):
For the first 14 days after installation, all 3,325 words are included in the
study pool. After 14 days, every feature keeps working exactly as before -
quiz, typing, listening, study history, search, and audio playback are never
disabled. The only change is that the quiz/typing/listening pool is reduced to
2,143 words, and the remaining 1,182 words are what the purchase unlocks. The
word list itself continues to show, search, and pronounce all 3,325 words
regardless of purchase. No functionality expires.

Contact: <氏名 / メールアドレス>
```

---

## 2級版との違い（差し替えた箇所）

| 箇所 | 2級 | 準2級 |
| --- | --- | --- |
| 級名 | Grade 2 | Grade Pre-2 |
| 対象読者 | 高校生・社会人 | 中3〜高1 |
| 総語数 | 3,955 | 3,325 |
| 課金で増える語数 | 1,274 | 1,182 |
| 試用終了後の出題語数 | 2,681 | 2,143 |
| プロダクトID | `com.eitango.app.unlock.grade2` | `com.eitango.gp2.unlock.core` |
| 課金アイテム名 | 2級コア発展語彙の解放 | 準2級コア発展語彙の解放 |
| 熟語数 | 記載なし | 637（項目3に追記） |
| シリーズの説明 | なし | 項目3に追記（無料の3級・4級があることを先に言う） |
| 画面収録 | 添付済み | 「求められれば提出する」と書くに留める |

シリーズの説明を項目3に入れてあるのは、**同じ見た目のアプリを4本出すことを先に伝えるため**。
黙って出すと 4.3（Spam / 重複アプリ）を疑われる。語彙データだけが違う別の級であること、
下位2級は無料であることをこちらから書いておく。

画面収録は準2級では添付しない。2級の 2.1 は「備考に情報が無い」ことが理由で、
情報を最初から入れておけば収録は求められない見込み。求められたら
`docs/app-review-reply.md` §1 の手順で撮る。
