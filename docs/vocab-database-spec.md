# 単語データベース設計仕様書

シリーズ全アプリの語彙を一元管理する `vocab/master.json` の仕様と、級ごとの語彙帯設計の
ルールを定める。`docs/series-architecture.md` §5 の詳細版であり、**語彙に関しては本書が正**。
実装タスクへの対応は `docs/series-implementation-handoff.md` P0-3（生成基盤）と
P1-1（準2級の配置設計）。

なぜ一元管理するのか。同じ語（例: `abandon`）が2級では発展語、準1級では既習語として
複数のアプリに出る。アプリごとに語彙ファイルを持つと、訳の修正が片方にしか入らない、
級をまたいで訳語が食い違う、といった破綻が必ず起きる。**語の正本は1つ、級ごとの扱いは
配置情報として持つ**のが本設計の核。

---

## 1. 全体像

```
vocab/master.json              語の正本 + エディションごとの配置（唯一の正）
vocab/gp2_bridge_words.txt     選定リスト。人間がレビューする中間成果物（§9）
vocab/gp2_bridge_examples.txt  「key | 例文」。editions.GP2.example になる
vocab/gp2_new_core.txt         そのエディション専用の新規語（全フィールド）
        ↓ scripts/apply_<id>_placement.py   （配置と専用データを master へ書き戻す。冪等）
        ↓ scripts/build_seed.py --edition X （検証しつつアプリ同梱 JSON を生成）
        ↓ scripts/check_core_exclusivity.py （課金 core の独自性を検査。§4）
Editions/<ID>/word_master_seed.json         アプリに同梱される生成物
```

**master.json を手で編集しない。** 上記の入力ファイルを直し、apply スクリプトを流し直す
（冪等なので何度でも実行してよい）。手編集は次回の apply で消える。

現状（2026-08-15 時点）:

| エディション | 状態 | basic | bridge | core | 計 |
| --- | --- | --- | --- | --- | --- |
| G2（英検2級） | **公開済み・変更不可** | 1,512 | 1,169 | 1,274 | 3,955 |
| GP2（準2級） | 語彙設計 完了（core 独自性 54.5%） | 886 | 1,257 | 1,182 | 3,325 |
| G4 / G3 / GP1 / G1 / TOEIC | 未着手 | — | — | — | — |

マスターの総語数は 4,599（G2 由来 3,955 + GP2 専用の新規語 644）。

---

## 2. スキーマ仕様

```jsonc
{
  "version": 1,          // master.json のフォーマット版
  "seedVersion": 18,     // 生成物に載る版。§8 の規則で上げる
  "words": [ /* canonical entry の配列 */ ]
}
```

### canonical entry（語の正本）

| フィールド | 型 | 必須 | 制約 |
| --- | --- | --- | --- |
| `key` | string | ✔ | `^[A-Z0-9_]+$`。`word` を大文字化し英数字以外を `_` にしたもの（現行3,955語すべてこの規則に一致）。**公開後は絶対に改名しない**（§8） |
| `word` | string | ✔ | 見出し語。小文字。句・イディオムは半角スペース区切り（`above all`） |
| `meaning` | string | ✔ | 日本語の訳。読点区切りで複数可（`捨てる、断念する`） |
| `example` | string | ✔ | 英語の例文。空文字可（basic のみ。§6） |
| `partOfSpeech` | string | ✔ | `noun` / `verb` / `adjective` / `adverb` / `other` のいずれか（`PartOfSpeech`） |
| `domain` | string | ✔ | `daily` / `environment` / `technology` / `health` / `business` / `society` / `education` / `general`（`VocabularyDomain`） |
| `category` | string | ✔ | `A` / `B` / `C`。頻出度ランク（`FrequencyRank`）。A が最頻出 |
| `frequencyCount` | int | — | 出題回数の実データ用。**現状は全語 0**（未使用）。省略時 0 |
| `isIdiom` | bool | — | 句・熟語なら true（現行296語）。省略時 false |
| `editions` | object | ✔ | 下記。空オブジェクトの語はどのアプリにも載らない（削除候補） |

列挙値はアプリ側の enum（`EitangoApp/Models/Enums.swift`）と一対一。**未定義の値を書くと
`WordMasterSeeder.upsert` がその語を黙って捨てる**（`FrequencyRank(rawValue:)` の
guard で continue するため）。生成時の検証で弾くこと。

### editions.\<ID\>（配置）

```jsonc
"editions": {
  "G2":  { "tier": 3 },
  "GP2": { "tier": 2, "meaning": "あきらめる" }   // 級に合わせた上書き
}
```

| フィールド | 説明 |
| --- | --- |
| `tier` | 必須。`1`=basic / `2`=bridge / `3`=core（`VocabularyTier`。§3） |
| `meaning` `example` `category` `domain` | 任意。その級だけ正本を上書きする（`build_seed.py` の `OVERRIDABLE`）。§5 |

`word` `partOfSpeech` `key` `isIdiom` は**上書きできない**。語そのものが変わるなら別エントリ。

### wordId 生成規約

`wordId = <プレフィクス> + key`。プレフィクスは `build_seed.py` の `EDITIONS` が正。

| ID | プレフィクス | bundle ID |
| --- | --- | --- |
| G4 / G3 / GP2 / G2 / GP1 / G1 | `EIKEN_G4_` / `EIKEN_G3_` / `EIKEN_GP2_` / `EIKEN_G2_` / `EIKEN_GP1_` / `EIKEN_G1_` | `com.eitango.g4` … G2 のみ `com.eitango.app` |
| TOEIC | `TOEIC_` | `com.eitango.toeic` |

wordId は `UserProgress` の主キーとして学習履歴を紐づける。アプリ間で履歴は共有されない
（別アプリ・別ストア）ので、**一意性は級内だけ担保すればよい**。

---

## 3. 語彙帯（tier）の設計

### 3層モデル

| tier | 名称 | 意味 | 既定の出題 | 課金 |
| --- | --- | --- | --- | --- |
| 1 | basic | 下位級までの既習語 | 対象外（明示選択で出せる） | 無料 |
| 2 | bridge | 前級帯からの橋渡し | 対象 | 無料 |
| 3 | core | **当該試験の得点源。売り物** | 対象 | 試用14日 → 課金 |

実装は `StudyScope.studyDefaultTiers = [.bridge, .core]` と
`Entitlements.availableTiers`（未購入 = basic+bridge）。エディションを増やしても変更不要。

**課金で変わるのは出題範囲だけ**。単語帳は購入状態に関わらず全語を表示・検索・発音する
（`WordRepository.fetchWords(matching:)` が `allTiers` で引く）。したがって守るべきは
「語のリストを見せないこと」ではなく、**その級の core を無料で学習し切る経路を作らないこと**（§4）。

### 級のスライド（原則）

級 N の core は、上位級では既習語になる。この関係を配置に落とす。

> 級 N の core は、級 N+1 では **bridge の母体**、級 N+2 以上では **basic の母体**になる。
> ただし上位級の無料帯へは**全量を持ち込まず、頻出上位40〜50%を選抜する**（§4 ルールB）。

core の語数は **1,000〜1,500語**を目安にする。2級の実績（1,274語 / 1日100問で約3.5か月、
1日150問で約2.3か月で9割到達）が「完走できる分量」の実証値。超える級は bridge へ降ろす。

### エディション別の設計方針

| エディション | core（売り物） | 母体にする既存語 | 新規執筆の見積もり |
| --- | --- | --- | --- |
| G4 | 4級帯（A1） | G2 basic の易しい層 | basic（中1・5級帯）の補充 + core 不足分。数百語 |
| G3 | 3級帯（A1+〜A2） | `gp2_bridge_words.txt` の626語が中心 | core 補充 約400語 + 4級帯 bridge の選定 |
| GP2 | 準2級帯（A2）1,182語 | G2 bridge の category A（538語）のみ | **完了**: 新規 core 644語 + bridge 626語の例文 |
| G2 | 2級帯（B1）1,274語 | — | **変更不可**（公開済み） |
| GP1 | 準1級帯（B2） | bridge = G2 core 1,274語から**約550語を選抜** | **core 約1,200〜1,500語を新規**（訳・例文込み） |
| G1 | 1級帯（C1） | bridge = GP1 core から選抜 | **core 約1,200〜1,500語を新規** |
| TOEIC | 730点+帯（ビジネス語彙） | G2/GP1 と重なる語は canonical を再利用 | ビジネス固有語を新規。tier 表示名はスコア帯（§7 の Spec 側） |

TOEIC は級の直列関係に載らないため、スライド原則の外。basic=中学英語 / bridge=〜600点帯 /
core=730点+帯 とし、重複語は他級の配置に影響しない（`editions` に TOEIC 行を足すだけ）。

### 選定の手順（GP2 で確立したパターン）

1. 母体になる既存 tier を機械的に抽出する
2. 人間がレビューできる**選定リスト**を作る（`vocab/<id>_<帯>_words.txt`。1行1語、`#` コメント可）
3. `scripts/apply_<id>_placement.py` がリストと母体から配置を計算し master へ書き戻す（冪等）
4. `build_seed.py --edition <ID>` の検証を通す → `check_core_exclusivity.py` を通す

新規語は canonical entry を新設する。`key` は §2 の規則で機械的に決まり、**以後不変**。

---

## 4. 商品保護 — コア独自性ルール

### 問題

語彙を一元管理し「級のスライド」を素朴に適用すると、**あるアプリの課金対象が、別の自社
アプリでは無料で学習できる**状態が生まれる。シリーズとして商品の整合が取れない。

当初の GP2 配置がまさにこれだった（`scripts/check_core_exclusivity.py` 導入時の実測）:

```
[NG] GP2: core 1169語 / 独自 0語 = 独自性 0.0%
       G2 の無料帯に 1169語 (100.0%) が露出
```

GP2 の core が G2 の bridge 全量だったため、**準2級アプリの ¥500 の対象が、2級アプリでは
1円も払わずに出題される**状態だった。是正済み（下記）。

将来はもっと深刻な形で再発する。スライド原則のまま GP1 を作ると
**bridge（無料）= G2 core 1,274語の全量**となり、既に販売中の2級アプリの課金価値を
自社の新作が消してしまう。

### ルールA — コア独自性

> どのエディションの無料帯（tier1+2）も、他エディションの core を全量含んではならない。
> **独自性率**（= その core のうち、他のどのエディションの無料帯にも無い語の割合）に
> 目標値を置き、機械検証する。

目標は全エディション **50%**（`check_core_exclusivity.py` の `DEFAULT_TARGET`）。
core の過半がその級固有なら、他のアプリはその級の代替にならない。
個別に緩める場合は同スクリプトの `TARGETS` に書き、**根拠を本節に残す**（現在は例外なし）。

実測（2026-08-15）: G2 100.0% / GP2 54.5%。

### ルールB — 選抜スライド

> 下位級の core を上位級の無料帯へ持ち込むときは**全量にしない**。頻出上位40〜50%に絞る。

復習帯としては十分な量であり、かつ「下位級アプリを買う理由」を残す。
**特に GP1 の bridge を G2 core 1,274語の全量にしてはならない。**
目安: GP1 bridge = G2 core から約550語（43%）。

### GP2 で実際にやったこと（是正の実績）

| | 語数 | 独自性 |
| --- | --- | --- |
| 当初 | 再利用 1,169（G2 bridge 全量）+ 新規 0 = 1,169 | 0.0% |
| **是正後** | 再利用 **538** + 新規 **644** = **1,182** | **54.5%** ✔ |

1. **再利用を頻出上位帯だけに絞った**。core に残すのは G2 bridge の category A（538語）のみ。
   外した631語（category B/C）は **GP2 の bridge へ降ろした**（無料帯なので G2 と重なってよい）。
   G2 bridge は例文カバレッジ100%なので、降格に伴う例文の追加執筆は発生していない
2. **準2級専用の新規 core 語を644語書いた**（`vocab/gp2_new_core.txt`）。
   G2 の3,955語に無い A2 帯の語。前半は日常・学校・仕事・健康・旅行の具体語、
   後半は品詞の偏りを直すために動詞55語・形容詞104語を補った
3. **bridge へ昇格した626語の例文を書いた**（`vocab/gp2_bridge_examples.txt`）。
   G2 では basic で例文が無い語。`editions.GP2.example` として与える（§5 の注意を参照）

結果: GP2 は basic 886 / bridge 1,257 / core 1,182 = 3,325語。
core の品詞構成は 名詞48% / 動詞25% / 形容詞18%（G2 core は 41/34/20）。
下位級ほど具体名詞が増えるのは自然だが、名詞寄りである点は §9 のレベル妥当性レビューで確認する。

**残る限界**: 隣接級である以上「準2級帯の語が2級アプリの無料帯にある」こと自体はゼロにできない
（G2 を変更できないため、538語＝core の45.5%が該当する）。狙いは、core の過半を準2級専用にし、
2級アプリが準2級アプリの代替にならない状態を作ることにある。

### 検証

```bash
python scripts/check_core_exclusivity.py          # レポート
python scripts/check_core_exclusivity.py --gate   # 目標未達なら exit 1（CI 用）
```

目標値は同スクリプトの `TARGETS` に置く。**変更するときは本節の根拠も併せて更新すること。**

---

## 5. 級間の再利用と上書き

同じ語を複数の級で使うときの規約。

- **正本（canonical entry）の訳・例文は、その語を使う級のうち最上位の級に合わせて書く。**
  下位級のために正本を平易化すると、上位級の品質が下がる
- 下位級に合わない場合は `editions.<ID>` に override を書く。上書きできるのは
  `meaning` / `example` / `category` / `domain` の4つ

override を書く判断基準:

| 状況 | 対応 |
| --- | --- |
| 訳語が級に対して硬い・抽象的（`abandon`「断念する」→ 下位級では「あきらめる」） | `meaning` を override |
| 例文が当該級より上の語彙を含む（§6 の制約に違反する） | `example` を override |
| その級では出題頻度が違う | `category` を override |
| 級によって主な使用文脈が違う（`account`: 一般 ↔ ビジネス） | `domain` を override |
| 語義そのものが別（同綴異義） | override ではなく**別の canonical entry**にする |

**公開済みエディションが「例文なし」で出している語に、後から例文を足す場合は必ず override にする。**
canonical の `example` に書くと、その語を含む公開済みエディションの同梱 seed が変わり、
G2 の再現一致ゲート（§7）が落ちる。GP2 の bridge 626語がこれに当たる
（G2 では basic で例文が無い → `editions.GP2.example` に626件）。

> 将来 G2 が語彙改訂を伴うリリースを出すときに、この626件を canonical へ移して
> G2 でも例文を出す判断はありうる。そのときは G2 の同梱 seed も同時に更新し、
> 再現一致の基準を意図的に更新する（黙ってゲートを外さない）。

現在の override: GP2 の例文 626件。訳の平易化 override は未着手（§9 のレビュー項目）。

---

## 6. 例文・訳の品質規約

| tier | 例文カバレッジ | 根拠 |
| --- | --- | --- |
| core (3) | **100% 必須** | 課金対象。例文が無い語が混じると商品として成立しない |
| bridge (2) | **100% 必須** | 既定で出題される。クイズの解答後に例文を表示する導線がある |
| basic (1) | 不要（0%で可） | 既習語。G2 も 0/1,512 で運用している |

`build_seed.py` がこれを検証し、core/bridge に空例文があるとエラーで停止する。

例文の書式（G2 の実績: 平均5.8語 / 3〜12語）:

- **1文で完結**し、目安 4〜10語。クイズ画面は2行で打ち切る（`lineLimit(2)`）ため長文は不可
- **当該級までの語彙で構成する**。core 語の例文に、その級の他の core 語を複数入れない
- 見出し語をそのままの形で含める（活用形の変化は可）
- 固有名詞・時事ネタ・特定の文化前提を避ける（陳腐化と誤解の元）

訳の書式:

- 品詞に沿った日本語（動詞なら「〜する」、名詞なら体言止め）
- 主要語義1〜2個。読点区切り。多義語を網羅しない

---

## 7. 生成・検証パイプライン

| スクリプト | 役割 | 再実行 |
| --- | --- | --- |
| `scripts/import_seed_to_master.py` | 現行 G2 seed → master の逆輸入 | **一度きり。再実行禁止**（override や新規語を上書きしてしまう） |
| `scripts/apply_<id>_placement.py` | 選定リスト + 母体 tier から配置を計算し、専用の新規語と例文 override も含めて master へ書き戻す | 冪等。何度でも可 |
| `scripts/build_seed.py --edition X` | 検証しつつ同梱 JSON を生成 | 冪等 |
| `scripts/build_seed.py --edition G2 --check` | **G2 の再現一致ゲート**。生成結果が現行同梱 seed とデータ一致するか | 冪等。CI に入れる |
| `scripts/check_core_exclusivity.py` | §4 のコア独自性検査 | 冪等 |

`build_seed.py` の検証ゲート（違反はエラー、`--check` 時以外は exit 1）:

1. `tier` が 1/2/3 以外
2. core/bridge に空例文（§6）
3. wordId の重複
4. そのエディションに配置された語が0件

エラーは先頭10件 + 総数で表示する（626件のような大量エラーで端末が埋まらないように）。

**G2 の再現一致は永続的な回帰ゲート**。master 側を編集して `--check` が落ちたら、
それは公開中アプリの語彙を変えたということ。意図した変更なら §8 の手順を踏む。

---

## 8. 更新とバージョニング

### seedVersion

生成物の `version` になり、アプリの `WordMasterSeeder.seedIfNeeded` が
UserDefaults の `wordMasterSeedVersion` と比較する。**大きくなったときだけ** Upsert が走る。

- 語の追加・削除、訳・例文・tier の変更を含むリリースでは**必ずインクリメントする**
  （上げ忘れると、更新したのに端末の語彙が変わらない）
- master.json とアプリ同梱の生成物は**同一コミットに入れる**（片方だけ更新された状態を残さない）
- エディションごとに分けず、master 全体で1つの連番にする（現在 18）

### 語の削除・改名

| 操作 | 可否 | 理由 |
| --- | --- | --- |
| 訳・例文・tier・domain の変更 | 可 | wordId が同じなら Upsert で更新され、学習履歴は保持される |
| 語の削除（`editions` から外す） | 可 | `WordMasterSeeder` が孤児の `UserProgress` を許容する設計（該当行は表示されなくなるだけ） |
| **`key` の改名** | **禁止** | wordId が変わる = 削除＋新規。**その語の学習履歴が全ユーザーで失われる** |

綴りの誤りを見つけた場合も、公開済みエディションでは改名しない。`word` フィールドだけ直す
（`key` と `word` の対応が規則から外れるが、履歴保持を優先する。この例外は本書に記録する）。

### リリース手順

```bash
# 1. master.json を編集（配置スクリプト or 手編集）
python scripts/apply_gp2_placement.py

# 2. seedVersion をインクリメント（手編集）

# 3. 検証と生成
python scripts/build_seed.py --edition G2 --check     # 公開中アプリに影響が無いこと
python scripts/build_seed.py --edition GP2
python scripts/check_core_exclusivity.py --gate

# 4. master と生成物を同一コミットで push
```

---

## 9. 品質保証

- **選定リストを必ず残す**。配置をスクリプト内のロジックだけで決めると、後から
  「なぜこの語が core なのか」を人間が検証できない。`vocab/<id>_<帯>_words.txt` を
  レビュー可能な中間成果物として置く（`gp2_bridge_words.txt` の方式）
- **級レベルの妥当性はサンプリングで確認する**。各 tier から30語程度を抜き、
  その級の過去問・公式教材の語彙帯と照合する。全語の人力レビューは現実的でない
- **例文は core/bridge を全数確認する**（カバレッジは機械検証できるが、
  級に対して難しすぎる例文は検出できない）
- 配置を変えたら `check_core_exclusivity.py` を必ず通す。数値が悪化したら §4 に戻る

---

## 10. 関連文書

| 文書 | 内容 |
| --- | --- |
| `docs/series-architecture.md` | シリーズ全体の設計（ターゲット構成・EditionSpec・CI・商標） |
| `docs/series-implementation-handoff.md` | 実装タスクの分解と受け入れ基準（P0-3 が §7、P1-1 が §3〜§4 に対応） |
