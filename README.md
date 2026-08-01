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

### TestFlightへ配信する

Actionsタブ → **TestFlight** ワークフロー → **Run workflow** を手動実行する。
push のたびに配信するとビルドが溜まりテスターへの通知も続くため、意図的に手動トリガーにしている。

証明書とProvisioning Profileは持ち回らず、App Store Connect APIキーを使って
`-allowProvisioningUpdates` でXcodeに取得させる（手元にMacが無く、証明書を書き出せないため）。
必要なSecretsは以下の3つ。

| Secret | 内容 |
| --- | --- |
| `ASC_API_KEY_ID` | App Store Connect APIキーの Key ID |
| `ASC_API_ISSUER_ID` | 同 Issuer ID |
| `ASC_API_KEY_P8` | ダウンロードした `.p8` の中身（BEGIN/END行を含む全文） |

ビルド番号にはワークフローの実行番号を使う。App Store Connectは同じ（バージョン, ビルド番号）の
組を二度受け付けないため、必ず増える値が要る。表示用のバージョンを上げるときは
`project.yml` の `MARKETING_VERSION` を変更する。

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

EitangoAppTests/     # ロジックのユニットテスト（間隔反復・出題順）
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

## 間隔反復（SRS）について

出題順は `Services/Study/StudyQueue.swift` が決める。ランダム出題ではなく、次の優先度で並べる。

1. 復習期限が来た語（間違えた語・間隔が満了した語）
2. まだ一度も解いていない語
3. 期限前の語（期限が近い順）

間隔は Leitner ボックス方式で、`UserProgress.reviewIntervalDays` の固定テーブル（0/1/3/7/14/30日）を使う。
正解すると1段階上がって間隔が伸び、間違えると段階0に戻ってその日のうちに再出題される。
SM-2のような可変難易度を持たせていないのは、動作が予測しやすく説明もしやすいため。

次回復習日は「日」単位に丸めているので、朝に解いても夜に解いても期限は同じ日付になる。
このロジックは `EitangoAppTests/` でユニットテストしている（壊れても画面上は正常に見えてしまい、
学習効果だけが静かに落ちるため）。

## タイピングテストについて

`Features/Typing/` は寿司打風のタイムアタック方式（`C:\System_Dev\etyping2` のゲームロジックを参考に移植）。
制限時間60秒の中で1文字ずつリアルタイム判定し、ミスすると同じ文字を打ち直すまで先に進めない。単語を打ち切ると自動で次の単語へ進み、
単語の長さに応じて残り時間にボーナスが加算される（`TypingViewModel` 内の `timeBonus` / `wordScore`）。「1問ずつ解答して次へ」という
静的なテスト形式ではなく、時間内に何語打ち切れるかを競うエンドレスモード。

## 学習履歴について

`Features/History/` が `StudyLog` の日次データを Swift Charts（OS標準）で可視化する。
ホームには直近1週間のミニグラフと連続日数を置き、タップで2週間/1か月を切り替えられる詳細画面へ push する。

日付まわりは `Services/Study/StudyHistory.swift` に純粋関数として切り出し、ユニットテストしている。

- 学習していない日も0で埋める（飛ばすと横軸が詰まって推移が読めなくなる）
- 連続日数は、当日まだ学習していなくても前日までの記録で数える。
  厳密に当日で切ると朝アプリを開いた瞬間に0日と表示され、継続の動機付けにならないため。
- 期間の正答率は解答数で重み付けする。日ごとの正答率を単純平均すると1問だけ解いた日が重く効いてしまう。

## 実装しないもの

- 課金・広告（方針として実装しない）
