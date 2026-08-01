# 英検2級 英単語特訓（完全オフライン）

英検2級対策の完全オフライン単語学習アプリ。サーバー通信・アカウント登録なし。TTSは `AVSpeechSynthesizer`（OS標準）のみを使用し、音声ファイルを同梱しないことでアプリ容量を極小化している。

## ビルド方法（Mac実機なし・GitHub ActionsのmacOSランナーを使用）

このプロジェクトは `.xcodeproj` をコミットせず、[XcodeGen](https://github.com/yonaskolb/XcodeGen) が `project.yml` から毎回生成する構成になっている。

### CIでビルド確認する場合

このリポジトリを GitHub にpushすると `.github/workflows/ios-build.yml` が自動実行され、iOS Simulator向けのビルドが通るか（コンパイルエラーがないか）を検証する。Actionsタブの実行結果を確認すること。

### CIでスクリーンショットを確認する場合（実機・ローカルSimulatorなしで見た目を確認）

同じワークフロー内で `EitangoAppUITests`（`EitangoAppUITests/EitangoAppUITests.swift`）がiOS Simulator上でアプリを実際に操作し、
ホーム・単語帳・単語詳細・4択クイズ・タイピング・聞き流しの各画面を [`xcparse`](https://github.com/ChargePoint/xcparse) でPNG抽出する。
Actionsの実行結果ページ → Artifacts欄の **`ui-screenshots`** をダウンロードすると、実際にシミュレータで描画された画面を確認できる
（`.xcresult` そのものも `test-results-xcresult` としてアップロードされるが、開くにはXcodeが必要）。

### Macが用意できた場合のローカル手順

```bash
brew install xcodegen
xcodegen generate
open EitangoApp.xcodeproj
```

## ディレクトリ構成

```
EitangoApp/
├── App/            # エントリポイント、ModelContainer初期化、Info.plist
├── Common/         # TabRouter等、画面をまたいで使う共有部品
├── Models/         # SwiftData @Model（WordMaster / UserProgress / StudyLog / 各種Enum）
├── Resources/
│   ├── word_master_seed.json      # 同梱マスターデータ（差し替えでアップデート）
│   └── Assets.xcassets/AppIcon.appiconset/  # アプリアイコン（1024x1024、アルファなし）
├── Services/
│   ├── DataSeeder/  # マスターデータのUpsert・学習履歴保持ロジック
│   └── TTS/         # AVSpeechSynthesizerラッパー（聞き流し機能）
├── Repositories/    # SwiftDataクエリの隠蔽層
└── Features/        # 画面ごとの View + ViewModel（Home / WordList / Quiz / Typing / Listening）

EitangoAppUITests/   # 画面遷移してスクリーンショットを撮るXCUITest（CIでの見た目確認用）
```

## データベース設計の要点

- `WordMaster`（マスター、Read-Only想定）と `UserProgress`（学習履歴、Read-Write）は `wordId` (String) でのみ緩く紐付け、SwiftDataの `@Relationship` は張らない。
- アプリ更新時、同梱の `word_master_seed.json` の `version` が既適用バージョンより新しければ `WordMasterSeeder` がマスターをUpsertする。学習履歴（`UserProgress`）には一切触れないため、単語データを総入れ替えしてもユーザーの進捗は保持される。

### 起動時の堅牢性について

単語データが入らなくてもアプリが「起動しない」状態にはならないよう、以下の方針を取っている。

- 適用済みシードバージョンは UserDefaults、実データは SwiftData と保存先が分かれるため、両者は食い違いうる（ストアの作り直し、バックアップ復元など）。`WordMaster` が0件ならバージョンに関わらず再シードする。
- バージョンの記録は `context.save()` が成功した**後**に行う。逆順にすると save 失敗時に「バージョンだけ進んで単語が空」の状態が永続化され、以降のシードがスキップされて復旧できなくなる。
- シード失敗は `AppContainer` でログに記録するだけで、起動は継続する（同梱JSONの破損でアプリが二度と起動しなくなるのを防ぐ）。
- 永続ストアを開けない場合はインメモリにフォールバックする。「起動しない」より「今回の履歴は保存されないが使える」方が損害が小さいという判断。

## タイピングテストについて

`Features/Typing/` は寿司打風のタイムアタック方式（`C:\System_Dev\etyping2` のゲームロジックを参考に移植）。
制限時間60秒の中で1文字ずつリアルタイム判定し、ミスすると同じ文字を打ち直すまで先に進めない。単語を打ち切ると自動で次の単語へ進み、
単語の長さに応じて残り時間にボーナスが加算される（`TypingViewModel` 内の `timeBonus` / `wordScore`）。「1問ずつ解答して次へ」という
静的なテスト形式ではなく、時間内に何語打ち切れるかを競うエンドレスモード。

## 既知の未実装スコープ

- 課金・広告
- ユニットテスト
