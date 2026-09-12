# App Review に関する情報（備考欄）— 英検準2級（GP2）

App Store Connect → バージョン → 「App Review に関する情報」→ 備考 に**そのまま貼る**。

2級の初回審査で 2.1（Information Needed）の差し戻しを受け、8項目を聞かれた
（`docs/app-review-reply.md`）。Apple の返信には
"Include this information in the Notes field ... for future submissions" とあるため、
**準2級では最初から8項目すべてを備考に入れて提出する**。同じ質問で止められないための予防。

**備考欄は4,000文字まで。** 下の文面は 3877 文字で、余裕は 123 文字。
2級への返信文をそのまま持ってくると5,782文字になり、登録できない。
足すときは必ず数え直すこと:

```bash
python -c "import sys;print(len(open(sys.argv[1],encoding='utf-8').read().rstrip()))" <ファイル>
```

`<>` の2か所は提出前に自分で埋める。項目2の実機は嘘を書けない。
連絡先は氏名とメールアドレスで、プレースホルダより長くなる分の余裕は取ってある。

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
Eiken Grade Pre-2 test, mainly students aged 14 to 16. It needs no sign-up or
connection and shows no ads, so it works offline and stores nothing off the
device. It bundles 3,325 words with meanings and example sentences, including
637 idioms, and offers four study modes (word list with filters, four-choice
quiz, typing, audio listening) plus a history chart. Review order uses
Leitner-style spaced repetition, on device. No advertising, no subscriptions.

One of a series: the same app published for other Eiken grades, differing only
in bundled vocabulary. Grade 2 (com.eitango.app), Grade 3 (com.eitango.g3),
Grade 4 (com.eitango.g4); Grade 3 and 4 are free with no in-app purchase.

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
Not a regulated industry; no third-party protected material. All 3,325 words,
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
Product ID com.eitango.gp2.unlock.core, "準2級コア発展語彙の解放" (Unlock Grade
Pre-2 core advanced vocabulary), JPY 500. It permanently adds 1,182 advanced
words (Tier 3) to the pool used by quiz, typing and listening. Two paths to the
purchase sheet: the Home access status card, or the Quiz tab "locked" notice.
Restore Purchases appears on the purchase sheet and under Home ->
"このアプリについて".

This is not a trial version. For 14 days after installation all 3,325 words are
in the study pool. After that every feature keeps working as before: quiz,
typing, listening, history and search are never disabled. The only change is
that the quiz/typing/listening pool drops to 2,143 words, and the remaining
1,182 are what the purchase unlocks. The word list continues to show, search
and pronounce all 3,325 words regardless of purchase. No functionality expires.

Contact: <氏名 / メールアドレス>
```

---

## 2級版から削ったもの・変えたもの

4,000文字に収めるため、**内容は落とさずに文を詰めた**。Apple が聞いた8項目は
すべて残っている。加えて2点だけ内容を変えている。

| 箇所 | 2級 | 準2級 |
| --- | --- | --- |
| 級名 | Grade 2 | Grade Pre-2 |
| 対象読者 | 高校生・社会人 | 14〜16歳 |
| 総語数 | 3,955 | 3,325 |
| 課金で増える語数 | 1,274 | 1,182 |
| 試用終了後の出題語数 | 2,681 | 2,143 |
| プロダクトID | `com.eitango.app.unlock.grade2` | `com.eitango.gp2.unlock.core` |
| 課金アイテム名 | 2級コア発展語彙の解放 | 準2級コア発展語彙の解放 |
| シリーズの説明 | なし | **項目3に追記** |
| 画面収録 | 添付済み | 「求められれば出す」と書くに留める |

シリーズの説明を項目3に入れてあるのは、**同じ見た目のアプリを4本出すことを先に伝えるため**。
黙って出すと 4.3（Spam / 重複アプリ）を疑われる。語彙データだけが違う別の級であること、
下位2級は無料であることをこちらから書いておく。

画面収録は準2級では添付しない。2級の 2.1 は「備考に情報が無い」ことが理由で、
情報を最初から入れておけば収録は求められない見込み。求められたら
`docs/app-review-reply.md` §1 の手順で撮る。

## 3級・4級に流用するとき

課金が無いので**項目8をまるごと落とす**（約900文字空く）。あわせて次を直す:

- 項目3の語数（3級 1,686語 / 4級 980語）と対象年齢、シリーズの列挙から自分の級を外す
- 項目4から「Restore Purchases」を消す（無料アプリには購入の復元が無い）
- 項目5の「payments use StoreKit 2」と、購入・復元の通信に触れた一文を消す。
  無料アプリは**通信が本当にゼロ**なので、そう書けるのは強み
- 項目7の語数
