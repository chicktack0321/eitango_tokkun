# 英検2級 英単語特訓（完全オフライン）

英検2級対策の完全オフライン単語学習アプリ。サーバー通信・アカウント登録なし。TTSは `AVSpeechSynthesizer`（OS標準）のみを使用し、音声ファイルを同梱しないことでアプリ容量を極小化している。

## ビルド方法（Mac実機なし・GitHub ActionsのmacOSランナーを使用）

このプロジェクトは `.xcodeproj` をコミットせず、[XcodeGen](https://github.com/yonaskolb/XcodeGen) が `project.yml` から毎回生成する構成になっている。

### CIでビルド確認する場合

このリポジトリを GitHub にpushすると `.github/workflows/ios-build.yml` が自動実行され、iOS Simulator向けのビルドが通るか（コンパイルエラーがないか）を検証する。Actionsタブの実行結果を確認すること。

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
```

## データベース設計の要点

- `WordMaster`（マスター、Read-Only想定）と `UserProgress`（学習履歴、Read-Write）は `wordId` (String) でのみ緩く紐付け、SwiftDataの `@Relationship` は張らない。
- アプリ更新時、同梱の `word_master_seed.json` の `version` が既適用バージョンより新しければ `WordMasterSeeder` がマスターをUpsertする。学習履歴（`UserProgress`）には一切触れないため、単語データを総入れ替えしてもユーザーの進捗は保持される。

## タイピングテストについて

`Features/Typing/` は寿司打風のタイムアタック方式（`C:\System_Dev\etyping2` のゲームロジックを参考に移植）。
制限時間60秒の中で1文字ずつリアルタイム判定し、ミスすると同じ文字を打ち直すまで先に進めない。単語を打ち切ると自動で次の単語へ進み、
単語の長さに応じて残り時間にボーナスが加算される（`TypingViewModel` 内の `timeBonus` / `wordScore`）。「1問ずつ解答して次へ」という
静的なテスト形式ではなく、時間内に何語打ち切れるかを競うエンドレスモード。

## 既知の未実装スコープ

- 課金・広告
- ユニットテスト
