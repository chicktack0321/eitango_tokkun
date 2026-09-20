"""G1（英検1級）の placement と G1 専用データを vocab/master.json に反映する。

設計は docs/vocab-database-spec.md §3〜§4。要点:

- G1 basic(1)  = G2 の tier1 + tier2（1級から見れば既習）
                 + GP1 の bridge（2級コアからの選抜529語と、準1級帯の頻出度A・副詞・句動詞）
- G1 bridge(2) = vocab/g1_bridge_words.txt の選抜語
                 （GP1 の core のうち、準1級専用に書き起こした新規語の頻出度B）
- G1 core(3)   = vocab/g1_new_core.txt の新規語（C1帯。全語が1級専用）

**GP1 の core を全量は持ち込まない**（コア独自性ルール）。特に:

- 2級コア由来の745語（GP1 core の大半）は1級の無料帯に置かない。公開中の2級アプリの
  課金対象であり、無料帯に出すと2級の独自性が 58.5% → 0% に落ちる
- 準1級専用語の頻出度C（337語）も持ち込まない。準1級アプリの売り物を守るため

`scripts/apply_gp1_placement.py` を先に流してから実行すること（GP1 の配置が入力になる）。
再実行してよい（毎回計算し直して上書きする）。
"""
import io
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MASTER = ROOT / "vocab/master.json"
BRIDGE_LIST = ROOT / "vocab/g1_bridge_words.txt"
NEW_CORE = ROOT / "vocab/g1_new_core.txt"

POS_VALUES = {"noun", "verb", "adjective", "adverb", "other"}
DOMAIN_VALUES = {"daily", "environment", "technology", "health",
                 "business", "society", "education", "general"}
CATEGORY_VALUES = {"A", "B", "C"}


def canonical_key(word):
    return re.sub(r"[^A-Z0-9]+", "_", word.upper()).strip("_")


def read_word_list(path):
    if not path.exists():
        return set()
    return {
        line.strip()
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.startswith("#")
    }


def read_table(path, fields):
    if not path.exists():
        return []
    rows = []
    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip() or line.startswith("#"):
            continue
        cells = line.split("|")
        if len(cells) != len(fields):
            raise SystemExit(f"{path.name}:{lineno}: 列数が {len(cells)}（期待 {len(fields)}）: {line[:60]}")
        rows.append(dict(zip(fields, (c.strip() for c in cells))))
    return rows


def load_new_core(existing_words):
    rows = read_table(NEW_CORE, ["word", "meaning", "example", "partOfSpeech", "domain", "category"])
    entries = []
    problems = []
    seen = set()
    for row in rows:
        word = row["word"]
        key = canonical_key(word)
        if word in existing_words:
            problems.append(f"{word}: 既にマスターにある（新規語ではない）")
            continue
        if key in seen:
            problems.append(f"{word}: 新規語リスト内で重複")
            continue
        if row["partOfSpeech"] not in POS_VALUES:
            problems.append(f"{word}: partOfSpeech が不正 ({row['partOfSpeech']})")
        if row["domain"] not in DOMAIN_VALUES:
            problems.append(f"{word}: domain が不正 ({row['domain']})")
        if row["category"] not in CATEGORY_VALUES:
            problems.append(f"{word}: category が不正 ({row['category']})")
        if not row["example"]:
            problems.append(f"{word}: core なのに例文が無い")
        if not row["meaning"]:
            problems.append(f"{word}: 訳が無い")
        seen.add(key)
        entries.append({
            "key": key,
            "word": word,
            "meaning": row["meaning"],
            "example": row["example"],
            "partOfSpeech": row["partOfSpeech"],
            "domain": row["domain"],
            "category": row["category"],
            "frequencyCount": 0,
            "isIdiom": " " in word,
            "editions": {"G1": {"tier": 3}},
        })
    return entries, problems


def main():
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")

    master = json.loads(MASTER.read_text(encoding="utf-8"))
    words = master["words"]

    # 前回の実行で追加した G1 専用語を先に落とす（冪等にするため）。
    # 他のエディションに載っている語は決して消さない
    words[:] = [w for w in words if set(w["editions"]) != {"G1"}]

    bridge_words = read_word_list(BRIDGE_LIST)
    gp1_core = {w["word"] for w in words if w["editions"].get("GP1", {}).get("tier") == 3}
    unknown = sorted(bridge_words - gp1_core)
    if unknown:
        print(f"error: 選定リストの {len(unknown)}語が GP1 core に見つかりません: {unknown[:10]}",
              file=sys.stderr)
        print("       先に scripts/apply_gp1_placement.py を流すこと", file=sys.stderr)
        return 1

    # 2級コア由来の語を1級の無料帯へ流していないか。ここを誤ると公開中の
    # 2級アプリの課金価値が消える（check_core_exclusivity でも検出されるが、
    # 原因が分かる形でここで止める）
    leaked = sorted(w["word"] for w in words
                    if w["word"] in bridge_words and w["editions"].get("G2", {}).get("tier") == 3)
    if leaked:
        print(f"error: 選定リストに2級コア由来の語が {len(leaked)}件あります: {leaked[:10]}",
              file=sys.stderr)
        return 1

    counts = {1: 0, 2: 0, 3: 0}
    for entry in words:
        g2_tier = entry["editions"].get("G2", {}).get("tier")
        gp1_tier = entry["editions"].get("GP1", {}).get("tier")
        if entry["word"] in bridge_words:
            g1 = 2
        elif g2_tier in (1, 2) or gp1_tier == 2:
            # 2級の無料帯と、準1級の無料帯（2級コアからの選抜を含む）が1級の既習語になる
            g1 = 1
        else:
            entry["editions"].pop("G1", None)
            continue
        entry["editions"]["G1"] = {"tier": g1}
        counts[g1] += 1

    existing_words = {w["word"] for w in words}
    new_core, problems = load_new_core(existing_words)
    for p in problems[:10]:
        print(f"error: {p}", file=sys.stderr)
    if len(problems) > 10:
        print(f"error: …ほか {len(problems) - 10}件", file=sys.stderr)
    if problems:
        return 1

    words.extend(new_core)
    counts[3] += len(new_core)
    words.sort(key=lambda w: w["key"])

    need_example = [
        w["key"] for w in words
        if w["editions"].get("G1", {}).get("tier") in (2, 3)
        and not w["example"].strip()
        and not w["editions"]["G1"].get("example", "").strip()
    ]

    MASTER.write_text(json.dumps(master, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    total = sum(counts.values())
    print(f"G1: {total}語 (basic {counts[1]} / bridge {counts[2]} / core {counts[3]})")
    print(f"  bridge: GP1 の新規 core から {counts[2]}語を選抜")
    print(f"  core: 1級専用の新規語 {len(new_core)}語")
    if need_example:
        print(f"  error: 例文が無い bridge/core 語 {len(need_example)}件 "
              f"（例: {', '.join(need_example[:5])}）", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
