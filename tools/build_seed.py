#!/usr/bin/env python3
"""単語データ（パイプ区切りテキスト）から、アプリに同梱する word_master_seed.json を組み立てる。

語彙を直接JSONで管理すると、5,000語規模では差分が読めず、重複や表記ゆれにも気付けない。
そこで人が読み書きしやすいテキストを原本とし、JSONは常にこのスクリプトの出力とする。

1行1語、"|" 区切りで6項目:
    word|meaning|pos|rank|domain|example

    word    見出し語（熟語・句動詞は空白を含んでよい）
    meaning 日本語の意味。複数の訳は「、」で並べる
    pos     noun / verb / adjective / adverb / other
    rank    A / B / C（試験での出題頻度の目安）
    domain  daily / environment / technology / health / business / society / education / general
    example 例文（省略可。基礎層は空でよい）

階層（tier）はファイル名から決まる: data/tier1.txt → 1, tier2.txt → 2, tier3.txt → 3,
data/idioms.txt → 2（熟語・句動詞は架け橋層として扱い、isIdiom を立てる）。

wordId は見出し語から機械的に作る（EIKEN_G2_TAKE_OFF）。
連番にすると、語を追加・並べ替えるたびにIDがずれて既存の学習履歴が
別の単語に紐付いてしまうため、綴りに固定する。
"""

from __future__ import annotations

import json
import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data"
OUTPUT = ROOT / "EitangoApp" / "Resources" / "word_master_seed.json"

# ファイル名の接頭辞で階層が決まる。分野ごとに分けて書き足せるよう、
# tier3_environment.txt のように接尾辞を付けたファイルもまとめて読む。
SOURCE_GROUPS = [
    ("tier1*.txt", 1, False),
    ("tier2*.txt", 2, False),
    ("tier3*.txt", 3, False),
    ("idioms*.txt", 2, True),
]

VALID_POS = {"noun", "verb", "adjective", "adverb", "other"}
VALID_RANK = {"A", "B", "C"}
VALID_DOMAIN = {
    "daily", "environment", "technology", "health",
    "business", "society", "education", "general",
}


def word_id(word: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9]+", "_", word.strip().upper()).strip("_")
    return f"EIKEN_G2_{slug}"


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    sys.exit(1)


def load(path: Path, tier: int, is_idiom: bool) -> list[dict]:
    if not path.exists():
        return []

    entries: list[dict] = []
    for line_number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue

        parts = line.split("|")
        if len(parts) == 5:
            parts.append("")
        if len(parts) != 6:
            fail(f"{path.name}:{line_number}: 列が6つではありません（{len(parts)}）: {line[:60]}")

        word, meaning, pos, rank, domain, example = (p.strip() for p in parts)

        if not word:
            fail(f"{path.name}:{line_number}: 見出し語が空です")
        if not meaning:
            fail(f"{path.name}:{line_number}: 意味が空です: {word}")
        if pos not in VALID_POS:
            fail(f"{path.name}:{line_number}: 品詞が不正です: {word} / {pos}")
        if rank not in VALID_RANK:
            fail(f"{path.name}:{line_number}: 頻出度が不正です: {word} / {rank}")
        if domain not in VALID_DOMAIN:
            fail(f"{path.name}:{line_number}: 分野が不正です: {word} / {domain}")
        if not re.fullmatch(r"[A-Za-z][A-Za-z\-' ]*", word):
            fail(f"{path.name}:{line_number}: 見出し語に英字以外が混ざっています: {word}")
        # 全角の括弧などは日本語として正常。全角の英数字だけは表示崩れのもとになるので弾く
        if re.search(r"[Ａ-Ｚａ-ｚ０-９]", meaning):
            fail(f"{path.name}:{line_number}: 意味に全角英数字が含まれます: {word}")
        # 訳語に英単語がそのまま残っているのは、書き写しの取りこぼし
        if re.search(r"[A-Za-z]{3,}", meaning):
            fail(f"{path.name}:{line_number}: 意味に英単語が残っています: {word} / {meaning}")

        entries.append({
            "wordId": word_id(word),
            "word": word,
            "meaning": meaning,
            "example": example,
            # 過去問での実出題回数は公開されていないため持たない。
            # 頻出度は rank（A/B/C）で表す。
            "frequencyCount": 0,
            "category": rank,
            "partOfSpeech": pos,
            "tier": tier,
            "domain": domain,
            "isIdiom": is_idiom,
            # 重複を報告するときにどのファイルの語かを示すためだけの一時項目
            "file": path.name,
        })
    return entries


def main() -> None:
    all_entries: list[dict] = []
    for pattern, tier, is_idiom in SOURCE_GROUPS:
        for path in sorted(DATA_DIR.glob(pattern)):
            loaded = load(path, tier, is_idiom)
            print(f"{path.name}: {len(loaded)}件")
            all_entries.extend(loaded)

    # 同じ綴りが複数のファイルに現れると、単語帳に二重に並び、4択のダミーも重複する。
    # 語を書き足すたびに1件ずつ止まると手戻りが大きいので、まとめて報告する。
    seen: dict[str, str] = {}
    duplicates: list[str] = []
    for entry in all_entries:
        key = entry["wordId"]
        if key in seen:
            duplicates.append(f"{entry['word']}（{seen[key]} と {entry['file']}）")
        else:
            seen[key] = entry["file"]
    if duplicates:
        fail("見出し語が重複しています:\n  - " + "\n  - ".join(duplicates))

    for entry in all_entries:
        del entry["file"]

    # 単語帳はID順に並ぶため、IDを綴り由来にしてある＝アルファベット順に見える
    all_entries.sort(key=lambda e: e["wordId"])

    version = json.loads(OUTPUT.read_text(encoding="utf-8"))["version"] if OUTPUT.exists() else 0
    payload = {"version": version + 1, "words": all_entries}
    OUTPUT.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    by_tier: dict[int, int] = {}
    for entry in all_entries:
        by_tier[entry["tier"]] = by_tier.get(entry["tier"], 0) + 1
    print(f"\n合計 {len(all_entries)}語 → {OUTPUT.relative_to(ROOT)} (version {payload['version']})")
    for tier in sorted(by_tier):
        print(f"  Tier {tier}: {by_tier[tier]}語")


if __name__ == "__main__":
    main()
