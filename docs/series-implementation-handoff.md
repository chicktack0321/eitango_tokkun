# シリーズ化 実装指示書（引き継ぎ用）

本書だけで実装に着手できるように書いてある。設計の背景と全体像は
`docs/series-architecture.md`（共通設計書）を先に読むこと。本書はそのタスク分解。

## 0. リポジトリと開発環境の前提

- iOS ネイティブアプリ（SwiftUI / SwiftData / StoreKit 2 / AVFoundation）。iPhone のみ、iOS 17+
- **手元マシンは Windows。Xcode は無い。ビルド・テストはすべて GitHub Actions（macOS runner）**
  - 検証ループ: push → `ios-build.yml`（ビルド＋単体テスト＋UIテスト＋スクリーンショット成果物）→
    `gh run watch` / `gh run download` で確認
  - TestFlight 配信は `testflight.yml` を `gh workflow run` で手動起動
- `.xcodeproj` はコミットしない。**`project.yml`（XcodeGen）が唯一の正**。CI が毎回 `xcodegen generate` する
- 語彙: `EitangoApp/Resources/word_master_seed.json`（3,955語。tier 1:1512 / 2:1169 / 3:1274）
- テスト: `EitangoAppTests/`（純粋ロジック中心。SwiftData は in-memory）、`EitangoAppUITests/`
  （スクリーンショット撮影 + 審査用画像。壊すと提出物が作れなくなる）

## 1. 絶対に壊してはいけないもの（最初に読むこと）

2級アプリは **App Store 公開済み**。以下は理由なく変えた時点で事故になる。

1. bundle ID `com.eitango.app`・ターゲット名 `EitangoApp`・スキーム名（CI と TEST_HOST が参照）
2. wordId 体系 `EIKEN_G2_<KEY>` — `UserProgress` が wordId をキーに学習履歴を持つ。
   **改名・削除＝そのユーザーの履歴消失**。`vocab/master.json` の `key` は公開後改名禁止
3. プロダクトID `com.eitango.app.unlock.grade2` — 購入の復元が壊れる
4. UserDefaults キー（`studyScope` / `masteryScope` / `pronouncesWords` / `gameSoundEnabled`、
   TrialManager の試用開始日）
5. `ProgressRepository.recordAnswer` のホットパスに**全件走査を戻さない**。
   過去に解答のたびに 3,955語を走査して判定が目に見えて遅くなった事故がある
   （コミット 9fb4bb3 / 95d64ae の経緯参照）。集計はセッション開始時か表示時に寄せる
6. アイコン素材は 1024×1024・アルファなし・角丸焼き込みなし（`scripts/make_app_icon.py` が検証する）

また、**2級アプリが審査中の間は main のコードを変更しない**こと（docs と vocab の準備は可）。

## 2. Phase 0 — 基盤整備（2級の挙動を変えずに共通化）

完了条件: 既存テスト全通過 / UIテストのスクリーンショットに差なし / §P0-3 の seed 再現一致。

### P0-1: EditionSpec の導入と級依存値の集約

- 目的: 級ごとに変わる値を1型に集め、共通コードから「2級」を消す
- 変更:
  - 新規 `EitangoApp/Common/EditionSpec.swift`（型定義。設計書§3のフィールド）
  - 新規 `Editions/G2/Edition.swift`（`EditionSpec.current`。値は現行 `AppConfig` と散在文言から転記）
  - `AppConfig` は URL 等を Spec へ移して縮小（互換のため段階的でよい）
  - 置換箇所（漏れの棚卸し。転記元の値は現行コードを正とする）:
    - `EitangoApp/Models/Enums.swift:39,46,47` — VocabularyTier displayName/summary → Spec 参照に変更
    - `EitangoApp/Features/Home/HomeView.swift:76,81`
    - `EitangoApp/Features/Purchase/PaywallView.swift:31,76`
    - `EitangoApp/Features/Quiz/QuizView.swift:145`
    - `EitangoApp/Services/TTS/AudioPlaybackManager.swift:312`（アルバム名）
- 受け入れ基準:
  - `grep -rn "2級" EitangoApp/` のヒットが**コメントを除きゼロ**（文言はすべて Editions/G2 側）
  - 既存テスト全通過。UIテストのスクリーンショット文言が従来と一致

### P0-2: project.yml の targetTemplates 化

- 目的: ターゲットを足すだけでエディションが増える状態にする
- 変更: 設計書§7の YAML 構成。`EitangoApp/App/Info.plist`・`Assets.xcassets`・seed JSON・
  `Products.storekit` を `Editions/G2/` へ移動し、共通 sources から exclude
- 注意:
  - ターゲット名 `EitangoApp` は維持（テストの TEST_HOST、CI の `-scheme EitangoApp` が参照）
  - `Products.storekit` はルートからの移動になるため、UIテストの
    `SKTestSession(configurationFileNamed: "Products")` と `project.yml` の
    UIテスト用 resources 参照も追従させる
- 受け入れ基準: CI green。`testflight.yml` を**動かさずに** Archive まで通ることは
  ios-build の build で担保（署名は不要）

### P0-3: 語彙マスターの逆輸入と生成

- 目的: `vocab/master.json` を唯一の語彙正本にする
- 変更:
  - 新規 `scripts/import_seed_to_master.py` — 現行 seed から `vocab/master.json` を生成
    （全語 `editions.G2 = {tier: 現行値}`。meaning/example/category/domain は正本側へ）
  - 新規 `scripts/build_seed.py --edition G2` — master から `Editions/G2/word_master_seed.json` を出力
  - 検証: wordId 重複 / editions が空の語 / core 語の例文カバレッジ率の警告
- 受け入れ基準:
  - **再現一致テスト**: build_seed の出力と現行 seed が全エントリ・全フィールドで一致
    （比較スクリプトを CI に追加。キー順・空白の差は無視してよい）
  - 一致するまで `Editions/G2/word_master_seed.json` は**手で置き換えない**

### P0-4: CI のエディション対応

- 変更:
  - `ios-build.yml`: matrix 化。**単体テスト・UIテストは G2 のみ**、他エディションは
    ビルド通過のみ確認（実行時間を級数倍にしない）
  - `testflight.yml`: `workflow_dispatch` に `edition` choice を追加し、scheme・
    アイコン検証（PrivacyInfo / CFBundleDisplayName 等の焼き込み確認ステップ）を切り替え
- 受け入れ基準: G2 の従来フロー（push で CI、dispatch で TestFlight）が無変更で動く

## 3. Phase 1 — パイロット（準2級 = GP2）

完了条件: GP2 が App Store に公開され、手順書（本節の実績版）が残ること。

### P1-1: 語彙設計と placement

- `vocab/master.json` に GP2 の placement を追加。目安: core（準2級帯・A2）1,000〜1,500語、
  bridge=3級帯、basic=4級以下
- 2級の既存語を再利用してよい（2級 core の平易な語 → GP2 core/bridge、下位語 → basic）。
  級に不釣り合いな訳・例文は `editions.GP2` の override で差し替え
- 新規語は canonical key を新設（`ABANDON` 形式。公開後改名禁止）
- 受け入れ基準: `build_seed.py --edition GP2` が警告なしで出力。core 語数がレンジ内、
  **core と bridge の例文カバレッジ 100%**（2級の実績。basic は例文なしでよい — 2級も0%）

### P1-2: エディション一式

- `Editions/GP2/` に Edition.swift / Info.plist / Assets（アイコンは
  `make_app_icon.py --edition GP2`）/ Products.storekit（`com.eitango.gp2.unlock.core`・¥500）
- project.yml にターゲット `EitangoGP2` 追加
- 受け入れ基準: CI で GP2 ビルド通過。G2 のテスト・スクリーンショットに差なし

### P1-3: 公開準備物

- Googleサイト: プライバシーポリシー文面を「シリーズ各アプリ」へ一般化（既存URLのまま更新）、
  `/support-gp2` ページ新設、問い合わせフォームに「対象アプリ」設問を追加
- `docs/` に GP2 用の store-listing / 提出手順（G2 版を雛形に）
- 審査用スクリーンショット: `testCapturePurchaseScreen` を GP2 ターゲットで実行して取得
  （ストアフロント JPN 指定は実装済み。ドル表記になっていたら storefront 設定を疑う）
- App Store Connect: 新規アプリ登録（bundle ID `com.eitango.gp2`）、課金アイテム登録
  （審査用スクリーンショット＋説明文が無いと「送信準備完了」にならない）、
  **初回提出時はバージョンページでの課金アイテム紐付けを忘れない**（G2 提出手順書の 4-4 参照）
- 受け入れ基準: TestFlight で実機確認 → 審査提出

## 4. 検証のやり方（共通）

```bash
# push 後
gh run list --repo <repo> --workflow ios-build.yml --limit 1
gh run watch <id> --repo <repo>
gh run download <id> --name ui-screenshots --dir shots/   # 画面の目視確認

# TestFlight（エディション指定）
gh workflow run testflight.yml --repo <repo> --ref main -f edition=GP2 -f whats_new="..."
```

- スクリーンショット比較は G2 の従来画像（過去 run の成果物）と目視で差分確認
- 体感性能（解答レスポンス等）は CI で測れない。実機 TestFlight で確認する運用

## 5. やってはいけないこと（過去の事故の再発防止）

| 禁止事項 | 理由（実際に起きたこと） |
| --- | --- |
| 解答・打鍵のホットパスに fetch 全件走査や毎回の `context.save()` を入れる | 判定が体感で遅れ、ユーザー指摘→2ビルド分の修正になった |
| wordId・canonical key の改名 | 学習履歴が全ユーザーで消える |
| `Info.plist` を XcodeGen の `info:` 生成に切り替える | 手書き plist が上書きされ、バックグラウンド再生等の宣言が消えた前歴（project.yml のコメント参照） |
| アイコンに角丸・透過を焼き込む | Apple のマスクで角が欠ける／審査で弾かれる。`make_app_icon.py` の検証を通すこと |
| 審査中に main のコード変更・TestFlight 連発 | 審査対象とのズレ、テスター通知の氾濫 |
| storekit のストアフロント未指定のまま審査用画像を作る | $2.99 表記の画像ができ、登録価格（¥500）と食い違う |
