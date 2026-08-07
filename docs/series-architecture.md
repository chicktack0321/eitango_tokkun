# シリーズ共通設計書 — 英単語特訓のマルチブランド展開

英検2級向け単体アプリとして開発した本アプリを、級別（4級/3級/準2級/準1級/1級）と
TOEIC の**別アプリ**としてシリーズ化するための設計。3つの要件を満たす。

1. **アプリ本体は同一プログラム** — 改善・不具合修正が全アプリへ自動で波及する
2. **単語データベースは一元管理** — 級をまたぐ語の訳・例文・品詞の整合性を1か所で保つ
3. **各シリーズのコア語彙を設計できる** — 「売り物になる語彙帯」を級ごとに定義する

決定済みの方針:

- 語彙マスターは**このリポジトリ内**（`vocab/`）で管理し、スクリプトで各アプリの同梱データを生成する
- 展開は**パイロット1本先行**。基盤整備 → 準2級で仕組みを検証 → 残りを量産

---

## 1. 全体方針: モノレポ + XcodeGen マルチターゲット

リポジトリは1つのまま、`project.yml` の **targetTemplates** でアプリターゲットを
エディションの数だけ生成する。共通コードは全ターゲットが同じファイルを参照するため、
「改善がすべてのアプリに反映される」は仕組みとして保証される（反映し忘れが起きえない）。

```
リポジトリ構成（移行後）

EitangoApp/            共通コード。全ターゲットが共有（現在の構成をそのまま使う）
Editions/
  G2/                  2級（既存アプリ）
    Edition.swift        級依存の値すべて（§3）
    word_master_seed.json  生成物（vocab/ から build_seed.py が出力）
    Assets.xcassets      アイコンとアプリ内ロゴ
    Products.storekit    課金アイテム定義
    Info.plist           CFBundleDisplayName など
  GP2/                 準2級（パイロット）
  ...                  G4 / G3 / GP1 / G1 / TOEIC
vocab/                 語彙マスター（§5）
scripts/
  build_seed.py        マスター → 各エディションの同梱JSON
  make_app_icon.py     アイコン生成（--edition 引数を追加）
docs/                  ストア提出・公開ページ関連（エディション別サブフォルダ化）
```

**別リポジトリへの複製はしない。** 複製すると改善のたびに N 回の取り込み作業が発生し、
必ず取りこぼす。エディション差分を `Editions/<名前>/` に閉じ込めることが本設計の核。

### エディション識別子

| エディション | 識別子 | wordId プレフィクス | bundle ID |
| --- | --- | --- | --- |
| 英検4級 | `G4` | `EIKEN_G4_` | `com.eitango.g4` |
| 英検3級 | `G3` | `EIKEN_G3_` | `com.eitango.g3` |
| 英検準2級 | `GP2` | `EIKEN_GP2_` | `com.eitango.gp2` |
| 英検2級（既存） | `G2` | `EIKEN_G2_` | `com.eitango.app` ※変更不可 |
| 英検準1級 | `GP1` | `EIKEN_GP1_` | `com.eitango.gp1` |
| 英検1級 | `G1` | `EIKEN_G1_` | `com.eitango.g1` |
| TOEIC | `TOEIC` | `TOEIC_` | `com.eitango.toeic` |

---

## 2. 不変条件 — 既存2級アプリで壊してはならないもの

2級アプリは公開済み（現在審査中）。移行のどの段階でも次を変えてはならない。

| 項目 | 値 | 壊すと起きること |
| --- | --- | --- |
| bundle ID | `com.eitango.app` | 別アプリ扱いになり、既存ユーザーが更新を受け取れない |
| wordId 体系 | `EIKEN_G2_<LEMMA>` | UserProgress が wordId キーのため**全ユーザーの学習履歴が消える** |
| プロダクトID | `com.eitango.app.unlock.grade2` | 購入済みユーザーの解放状態が復元できなくなる |
| UserDefaults キー | `studyScope` 等 | 設定と試用開始日がリセットされる |
| 同梱語彙データ | 3,955語の内容 | 変更自体は可。ただし wordId の削除・改名は履歴消失（`WordMasterSeeder` の Upsert 参照） |

**受け入れ基準: 基盤整備（Phase 0）の完了時点で、2級アプリのビルド成果物が機能的に同一であること。**
既存テスト（`EitangoAppTests` 一式）が無修正で通り、UIテストのスクリーンショットに差が無いこと。

---

## 3. エディション定義（EditionSpec）

級ごとに変わる値の棚卸し。現在のコード上の位置を併記する。
**太字**は現在 `AppConfig` に集約されておらず、コード中に散っている漏れ。

| 項目 | 現在の位置 | EditionSpec での扱い |
| --- | --- | --- |
| 級の表示名（英検®2級） | `AppConfig.gradeDisplayName` | `gradeDisplayName` |
| アプリ表示名 | `AppConfig.appDisplayName` + `Info.plist` CFBundleDisplayName | `appDisplayName` / Info.plist は Editions 側 |
| seed ファイル名 | `AppConfig.seedResourceName` | 全エディション同名で可（ターゲット別リソース） |
| プロダクトID | `AppConfig.unlockProductID` | `unlockProductID` |
| 商標文言 | `AppConfig.trademarkNotice` | `trademarkNotice`（§8: TOEIC は ETS 商標） |
| 公開URL | `AppConfig.privacyPolicyURL` / `supportURL` | `privacyPolicyURL` / `supportURL` |
| **階層の表示名・説明** | `Models/Enums.swift:39,46,47`（「2級コア」等） | `tierDisplayNames` / `tierSummaries` |
| **ホームのロック文言** | `Features/Home/HomeView.swift:76,81` | `coreTierName` から組み立て |
| **購入画面の文言** | `Features/Purchase/PaywallView.swift:31,76` | `paywallTitle` / `coreTierDescription` |
| **クイズのロック案内** | `Features/Quiz/QuizView.swift:145` | 同上 |
| **ロック画面のアルバム名** | `Services/TTS/AudioPlaybackManager.swift:312` | `nowPlayingAlbumTitle` |
| bundle ID | `project.yml` | targetTemplates の変数 |
| アイコン・ロゴ | `EitangoApp/Resources/Assets.xcassets` | `Editions/<ID>/Assets.xcassets` へ移動 |
| storekit 定義 | `Products.storekit`（ルート） | `Editions/<ID>/Products.storekit` へ移動 |
| 試用期間 | `TrialManager`（14日） | 共通のまま。変えたくなったら Spec へ |

`EditionSpec` は**コンパイル時に決まる値**として実装する（実行時にJSONを読む方式にしない）。
ターゲットごとに `Editions/<ID>/Edition.swift` 1ファイルをコンパイル対象へ含め、
共通コードは `Edition.current`（`EditionSpec` 型の定数）だけを参照する。
実行時読み込みにしないのは、タイプミスがビルドで捕まり、起動コストも増えないため。

```swift
// 共通側（EitangoApp/Common/EditionSpec.swift）
struct EditionSpec {
    let id: String                      // "G2"
    let appDisplayName: String          // "英単語特訓"
    let gradeDisplayName: String        // "英検®2級"
    let unlockProductID: String
    let trademarkNotice: String
    let privacyPolicyURL: URL
    let supportURL: URL
    let tierDisplayNames: [VocabularyTier: String]   // .core: "2級コア"
    let tierSummaries: [VocabularyTier: String]
    let coreTierDescription: String     // 購入画面の「何が解放されるか」
    let nowPlayingAlbumTitle: String
}

// エディション側（Editions/G2/Edition.swift。このファイルだけターゲット別）
extension EditionSpec {
    static let current = EditionSpec(id: "G2", ...)
}
```

---

## 4. 階層（Tier）設計の一般化

現在の3層モデルはそのまま全シリーズに適用できる。**tierRaw の数値と意味は共通**、
表示名だけがエディションごとに変わる。

| tierRaw | 共通の意味 | 出題への関与 | 課金 |
| --- | --- | --- | --- |
| 1 (basic) | 既習の前提語彙。下位級までの語 | 既定の出題範囲から外す（明示選択で出せる） | 無料 |
| 2 (bridge) | 前級帯からの橋渡し | 既定で出題 | 無料 |
| 3 (core) | **当該試験の得点源。売り物** | 既定で出題 | 試用14日 → 課金 |

この構造は `StudyScope.studyDefaultTiers = [.bridge, .core]`、
`AccessRights.availableTiers`（未購入 = basic+bridge）にそのまま実装されており、変更不要。

### 英検各級の語彙帯マッピング

| エディション | basic（既習） | bridge（橋渡し） | core（売り物） |
| --- | --- | --- | --- |
| G4 | 中1レベル | 5級帯 | 4級帯（CEFR A1） |
| G3 | 〜5級帯 | 4級帯 | 3級帯（A1+〜A2） |
| GP2 | 〜4級帯 | 3級帯 | 準2級帯（A2） |
| G2（既存） | 中〜高校基礎 | 準2級〜2級の橋渡し | 2級帯（B1）1,274語 |
| GP1 | 〜2級帯 | 2級上位帯 | 準1級帯（B2） |
| G1 | 〜準1級帯 | 準1級上位帯 | 1級帯（C1） |
| TOEIC | 中学英語 | 〜600点帯 | 730点+帯（ビジネス語彙中心） |

コア語彙設計のガイドライン:

- **coreの語数は 1,000〜1,500語** を目安にする。2級の実績（1,274語・1日100問で約3.5か月）が
  完走可能な分量の基準になる。多すぎる級は bridge へ降ろす
- **同じ語が複数の級に出てよい**。ある級の core は上位級では basic になる（例: 2級 core の
  `abandon` は準1級では basic）。この昇格・降格はマスターの配置表（§5）で級ごとに指定する
- 級内の一意性だけ守ればよい。アプリ間で wordId は独立（学習履歴はアプリをまたがない）
- TOEIC はスコア帯で切る。表示名は `tierDisplayNames` で「基礎 / 〜600点 / 730点+」等にする

---

## 5. 語彙マスター（`vocab/`）

### 形式

語の**正本**と、エディション×語の**配置**を1ファイルで持つ。

```jsonc
// vocab/master.json
{
  "version": 1,
  "words": [
    {
      "key": "ABANDON",              // canonical key。公開後は絶対に改名しない
      "word": "abandon",
      "meaning": "捨てる、断念する",
      "example": "They abandoned the plan after the accident.",
      "partOfSpeech": "verb",
      "domain": "general",
      "category": "B",               // 頻出度の既定値
      "editions": {
        "G2":  { "tier": 3 },
        "GP1": { "tier": 1 },
        "GP2": { "tier": 2, "meaning": "あきらめる" }   // 級に合わせた訳の上書き
      }
    }
  ]
}
```

- `editions` に載っている級だけがその語を同梱する
- `tier` 以外のフィールド（meaning / example / category / domain）は**級ごとに上書き可**。
  下位級には平易な訳・短い例文を出せる
- 級別の一覧性が必要になったら `vocab/placements/<ID>.json` へ分割してよいが、
  整合性検証が1ファイルのほうに寄るため、まずは単一ファイルで始める

### 生成

`scripts/build_seed.py --edition G2` が `Editions/G2/word_master_seed.json` を出力する。

- wordId は `<プレフィクス>_<key>`（例: `EIKEN_G2_ABANDON`）で機械的に決まる
- 生成時に検証する: wordId 重複なし / **core・bridge の例文カバレッジ100%**
  （2級の実績。basic は既習語なので例文なしでよい）/ tier ごとの語数 / 上書きフィールドの型

### 移行と回帰の受け入れ基準

1. **逆輸入**: `scripts/import_seed_to_master.py` が現行の
   `EitangoApp/Resources/word_master_seed.json`（3,955語）を読み、`vocab/master.json` の
   初期版（全語 `editions.G2` 付き）を作る
2. **再現一致**: `build_seed.py --edition G2` の出力が現行 seed と**データ一致**すること
   （全エントリの全フィールドが等しい。キー順・整形は問わない）。これを CI のテストにする。
   一致しない限りマスター方式へ切り替えない

### 語の削除・改名のルール

- 公開済みエディションから語を**消してよい**（`WordMasterSeeder` が孤児進捗を許容する設計）が、
  **key の改名は禁止**。改名は「削除＋新規」になり、その語の学習履歴が全ユーザーで失われる
- 訳・例文の修正は自由。wordId が同じなら履歴は保持される（既存の Upsert 挙動）

---

## 6. 課金・試用

| 項目 | 設計 |
| --- | --- |
| 商品構成 | 各アプリ1つの非消耗型（core 解放）。現行と同じ |
| プロダクトID | `com.eitango.<小文字ID>.unlock.core`（例: `com.eitango.gp2.unlock.core`）。G2 のみ既存の `com.eitango.app.unlock.grade2` を維持 |
| storekit | `Editions/<ID>/Products.storekit`。審査用スクリーンショットのUIテスト（`testCapturePurchaseScreen`）はストアフロント JPN 指定込みで共通利用可 |
| 試用 | `TrialManager` の14日を共通。級で変える理由が出るまで Spec に載せない |
| 価格 | App Store Connect 側の設定が正。storekit はテスト表示用（¥500） |

---

## 7. ビルドと CI

### project.yml（targetTemplates）

```yaml
targetTemplates:
  EditionApp:
    type: application
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: EitangoApp
        excludes: ["App/Info.plist", "Resources/Assets.xcassets", "Resources/word_master_seed.json"]
      - path: Editions/${edition_dir}
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: ${bundle_id}
        INFOPLIST_FILE: Editions/${edition_dir}/Info.plist
        # 他は現行 EitangoApp ターゲットの settings をそのまま

targets:
  EitangoApp:        # 2級。ターゲット名も既存のまま（スキーム・CI・TEST_HOST を壊さない）
    templates: [EditionApp]
    templateAttributes: { edition_dir: G2, bundle_id: com.eitango.app }
  EitangoGP2:
    templates: [EditionApp]
    templateAttributes: { edition_dir: GP2, bundle_id: com.eitango.gp2 }
```

テストターゲットは現行どおり `EitangoApp`（=G2）に依存させたまま共通ロジックを検証する。
エディション固有のテストは原則不要（差分は Edition.swift とデータだけ）。

### CI

| ワークフロー | 変更 |
| --- | --- |
| `ios-build.yml` | matrix でエディションごとにビルド。**テストとUIテスト（スクリーンショット）は G2 のみ**（共通コードの検証はどのターゲットでも同じ。全エディションで回すと実行時間が級数倍になる）。他エディションはビルドが通ることだけ確認 |
| `testflight.yml` | `workflow_dispatch` に `edition` 入力を追加。scheme とアイコン検証・アップロード先を切り替える。ビルド番号は現行どおり run_number |
| seed 検証 | `build_seed.py` の再現一致テスト（§5）を ios-build に追加 |

---

## 8. アセット・公開ページ・商標

### アイコン

`scripts/make_app_icon.py --edition GP2` で `Editions/<ID>/docs-assets` の元画像から生成。
現行の検証（1024角・アルファなし・マスクはみ出し検査）はそのまま全エディションに適用。
級の判別はアイコン内の級表記＋配色で行う（"英単語特訓" ロゴ部は共通でよい）。

### Googleサイト（プライバシーポリシー / サポート）

現行: `sites.google.com/view/eitango-tokkun/privacy-policy` / `support`（2級の文面）。

- **プライバシーポリシーは1ページを全アプリで共用**する。現文面の「対象: iPhoneアプリ
  『英単語特訓 英検®2級』」を「『英単語特訓』シリーズ各アプリ」に一般化する
  （収集しない・通信しない設計は全エディション共通のため、内容の差分が無い）
- **サポートページはアプリ別**にする（語数・級名・課金内容が違うため）。
  URLパス例: `/support-gp2`。お問い合わせフォームは1つを共用し、フォームに
  「どのアプリについてですか」の選択肢を追加する
- 2級の既公開URLは変更しない（アプリに焼き込み済み）

### 商標

| エディション | 注意点 |
| --- | --- |
| 英検系 | 現行文言を流用（「英検®は公益財団法人 日本英語検定協会の登録商標です。本アプリは同協会が承認・許諾したものではありません。」） |
| TOEIC | **ETS の登録商標**。文言を差し替える（「TOEIC is a registered trademark of ETS. This app is not endorsed or approved by ETS.」相当の日本語）。アプリ名の先頭に商標を置くと審査で照会されることがあるため、名称は「英単語特訓 TOEIC®対策」のように自社ブランドを先頭にする |

---

## 9. ロードマップ

| Phase | 内容 | 完了条件 |
| --- | --- | --- |
| **0. 基盤** | EditionSpec 抽出 / targetTemplates 化 / vocab マスター逆輸入と生成・一致テスト / CI 対応 | 2級アプリが機能的に無変更（既存テスト全通過・スクリーンショット差なし・seed 再現一致）。**2級の審査完了後に着手**（審査中はコードを動かさない） |
| **1. パイロット（準2級）** | GP2 の語彙設計（core 1,000〜1,500語）と placement / Edition.swift / アイコン / storekit / サポートページ / ストア文書・審査用スクリーンショット / TestFlight → 提出 | GP2 が App Store 公開。横展開の作業手順書（かかった工数込み）が残っている |
| **2. 量産** | 残り（G4/G3/GP1/G1/TOEIC）を Phase 1 の手順書どおりに展開。順序は市場判断（推奨: 3級 → 準1級 → TOEIC → 4級 → 1級） | 各アプリ公開。語彙レビューのワークフローが確立 |

各エディションで新規に必要な作業は最終的に次だけになる:
**語彙の placement 設計（最重量）/ Edition.swift 1ファイル / アイコン元画像 / サポートページ / ストア入力**。

---

## 10. 実装時の参照

実装タスクの分解と受け入れ基準は `docs/series-implementation-handoff.md`（実装指示書）を参照。
本書と指示書の対応: §3→P0-1、§7→P0-2/P0-4、§5→P0-3、§9 Phase1→P1-x。
