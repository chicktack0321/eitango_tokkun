# App Review に関する情報（備考欄）— 英検1級（G1）

App Store Connect → バージョン → 「App Review に関する情報」→ 備考 に**そのまま貼る**。
準2級版（`docs/gp2/app-review-notes.md`）の語数・級名・プロダクトIDを置き換えたもの。

2級の初回審査で 2.1（Information Needed）の差し戻しを受け、8項目を聞かれた
（`docs/app-review-reply.md`）。Apple の返信には
"Include this information in the Notes field ... for future submissions" とあるため、
**最初から8項目すべてを備考に入れて提出する**。

**備考欄は4,000文字まで。** 下の文面は 3,943 文字で、余裕は 57 文字。
`<>` を実際の値に置き換えると正味 +16 文字ほど増える見込み。足すときは必ず数え直すこと:

```bash
python -c "import sys;print(len(open(sys.argv[1],encoding='utf-8').read().rstrip()))" <ファイル>
```

`<>` の2か所は提出前に自分で埋める。項目2の実機は嘘を書けない。

---

```
1. Accounts and permissions
No account registration, login, or deletion: the app holds no user account. It
requests no permissions and shows no system prompts (location, camera,
microphone, notifications, ATT) and has no Info.plist usage description
strings. A screen recording can be provided on request.

2. Devices tested
<実機。例: iPhone 15 Pro, iOS 26.0>; iPhone 16 Pro Max Simulator, iOS 18.x
(automated UI tests on CI). Minimum iOS 17.0, iPhone only.

3. Function and audience
An offline English vocabulary trainer for Japanese learners preparing for the
Eiken Grade 1 test, mainly working adults and advanced learners. It needs
no sign-up or connection and shows no ads, so it works offline and stores
nothing off the device. It bundles 5,006 words with meanings and example
sentences, including 589 idioms, and offers four study modes (word list with
filters, four-choice quiz, typing, audio listening) plus a history chart.
Review order uses Leitner-style spaced repetition, on device. No advertising,
no subscriptions.

One of a series: the same app published for other Eiken grades, differing only
in bundled vocabulary. Grade 2 (com.eitango.app), Grade Pre-2
(com.eitango.gp2), Grade Pre-1 (com.eitango.gp1), Grade 3 (com.eitango.g3),
Grade 4 (com.eitango.g4); Grade 3
and 4 are free with no in-app purchase.

4. Setup
None. All content is bundled and available on first launch; no credentials or
sample files. Word list, quiz, typing and listening are the four tabs; study
history is on the Home chart. Trademark notice, privacy policy, support contact
and Restore Purchases: Home -> "このアプリについて".

5. External services
None. The app makes no network requests of its own: no backend, analytics,
advertising SDK, authentication, AI service, or third-party SDK. Vocabulary is
bundled JSON we authored; audio is AVSpeechSynthesizer (Apple's on-device TTS);
storage is SwiftData and UserDefaults on device; payments use StoreKit 2. The
only network traffic is Apple's own for purchase and restore; our App Privacy
declaration is "Data Not Collected".

6. Regional differences
None. Behaviour and content are identical everywhere. The interface is Japanese
only; distribution is worldwide because the audience includes Japanese learners
abroad. No region gating, remote configuration, or server.

7. Rights and trademark
Not a regulated industry; no third-party protected material. All 5,006 words,
meanings and example sentences were written by us, with nothing reproduced from
any published book, the Eiken test, or other source, so Content Rights is
declared "Does Not Contain, Show, or Access Third-Party Content". "英検" (Eiken)
is a registered trademark of the Eiken Foundation of Japan; we are not
affiliated with or endorsed by the Foundation and use the name only to identify
the examination the vocabulary targets. A disclaimer appears in the app and the
App Store description. If you prefer it removed from the name or icon, we will
submit a revised build promptly.

8. In-App Purchase
Exactly one, non-consumable and one-time. No subscription, no auto-renewal.
Product ID com.eitango.g1.unlock.core, "1級コア発展語彙の解放" (Unlock Grade 1
core advanced vocabulary), JPY 800. It permanently adds 1,219 advanced
words (Tier 3) to the pool used by quiz, typing and listening. Two paths to the
purchase sheet: the Home access status card, or the Quiz tab "locked" notice.
Restore Purchases appears on the purchase sheet and under Home ->
"このアプリについて".

This is not a trial version. For 14 days after installation all 5,006 words are
in the study pool. After that every feature keeps working as before: quiz,
typing, listening, history and search are never disabled. The only change is
that the quiz/typing/listening pool drops to 3,787 words, and the remaining
1,219 are what the purchase unlocks. The word list continues to show, search
and pronounce all 5,006 words regardless of purchase. No functionality expires.

Contact: <氏名 / メールアドレス>
```

---

## 準2級版から変えたところ

| 箇所 | 準2級 | 1級 |
| --- | --- | --- |
| 級名 | Grade Pre-2 | Grade 1 |
| 対象読者 | 14〜16歳 | 社会人・上級学習者 |
| 総語数 | 3,325 | 5,006 |
| 熟語数 | 637 | 589 |
| 課金で増える語数 | 1,182 | 1,219 |
| 試用終了後の出題語数 | 2,143 | 3,787 |
| プロダクトID | `com.eitango.gp2.unlock.core` | `com.eitango.g1.unlock.core` |
| 価格 | JPY 500 | JPY 800 |

項目3のシリーズ列挙には、**そのとき公開済み・審査済みの級だけを書く**。
1級を出す時点で準1級がまだ公開されていなければ、その行は落とす（未公開のアプリを
「公開している」と書かない）。

価格が級によって違うことは備考に書いていない。App Store Connect の価格設定と
掲載文の表記が一致していれば足り、書くと「なぜ違うのか」を説明する必要が生じる。
