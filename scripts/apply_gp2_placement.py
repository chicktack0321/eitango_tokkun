"""GP2（英検準2級）の placement と GP2 専用データを vocab/master.json に反映する。

設計は docs/vocab-database-spec.md §3〜§4。要点:

- GP2 core(3)   = G2 の tier2 のうち **category A のみ**（538語）+ GP2 専用の新規語。
                  G2 tier2 を全量 core にすると「準2級の課金対象が2級アプリでは無料」に
                  なるため（コア独自性ルール）、頻出上位帯だけを残して他は bridge へ降ろす
- GP2 bridge(2) = G2 tier2 の category B/C（無料帯へ降格。例文は canonical にある）
                  + vocab/gp2_bridge_words.txt の選定語（G2 tier1 由来。例文は下記リストから）
- GP2 basic(1)  = G2 の tier1 の残り（4級以下の既習語）
- G2 の tier3（2級コア・B1）は準2級より上のレベルなので GP2 には載せない

GP2 専用データ:
- vocab/gp2_bridge_examples.txt  「<key> | <例文>」。G2 では basic で例文が無い語に、
  GP2 用の例文を editions.GP2.example として与える。**canonical には書かない**
  （書くと G2 の同梱 seed が変わり、公開中アプリの再現一致ゲートが落ちる）
- vocab/gp2_new_core.txt         GP2 専用の新規 core 語。canonical entry を新設する

再実行してよい（毎回計算し直して上書きする）。
"""
import io
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MASTER = ROOT / "vocab/master.json"
BRIDGE_LIST = ROOT / "vocab/gp2_bridge_words.txt"
BRIDGE_EXAMPLES = ROOT / "vocab/gp2_bridge_examples.txt"
NEW_CORE = ROOT / "vocab/gp2_new_core.txt"

# G2 tier2 のうち core に残す頻出度ランク。残りは bridge へ降ろす
CORE_CATEGORIES = {"A"}

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
    """`|` 区切りのテキストを dict のリストで返す。空行と # 始まりは無視する。"""
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
    """GP2 専用の新規 core 語を canonical entry の形にして返す。"""
    rows = read_table(NEW_CORE, ["word", "meaning", "example", "partOfSpeech", "domain", "category"])
    entries = []
    seen = set()
    problems = []
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
            "editions": {"GP2": {"tier": 3}},
        })
    return entries, problems


def main():
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")

    master = json.loads(MASTER.read_text(encoding="utf-8"))
    words = master["words"]

    # 前回の実行で追加した GP2 専用語を先に落とす。残したままだと、同じ語を
    # 新規語リストから読み直したときに「既にマスターにある」と誤検出する。
    # G2 に載っている語（公開中アプリのデータ）は決して消さない
    words[:] = [w for w in words if set(w["editions"]) != {"GP2"} or "G2" in w["editions"]]

    bridge_words = read_word_list(BRIDGE_LIST)
    tier1_words = {w["word"] for w in words if w["editions"].get("G2", {}).get("tier") == 1}
    unknown = sorted(bridge_words - tier1_words)
    if unknown:
        print(f"error: 選定リストの {len(unknown)}語が G2 tier1 に見つかりません: {unknown[:10]}",
              file=sys.stderr)
        return 1

    # 例文 override（GP2 でのみ使う。canonical は空のまま）
    example_rows = read_table(BRIDGE_EXAMPLES, ["key", "example"])
    examples = {r["key"]: r["example"] for r in example_rows}
    if len(examples) != len(example_rows):
        print("error: 例文リストに重複キーがあります", file=sys.stderr)
        return 1

    # 既存語の配置
    counts = {1: 0, 2: 0, 3: 0}
    for entry in words:
        g2_tier = entry["editions"].get("G2", {}).get("tier")
        if g2_tier == 2:
            gp2 = 3 if entry["category"] in CORE_CATEGORIES else 2
        elif g2_tier == 1:
            gp2 = 2 if entry["word"] in bridge_words else 1
        else:
            entry["editions"].pop("GP2", None)
            continue
        placement = {"tier": gp2}
        # G2 で basic だった語は canonical に例文が無い。GP2 では bridge なので必要
        if gp2 == 2 and not entry["example"].strip():
            example = examples.get(entry["key"])
            if example:
                placement["example"] = example
        entry["editions"]["GP2"] = placement
        counts[gp2] += 1

    existing_words = {w["word"] for w in words}
    new_entries, problems = load_new_core(existing_words)
    for p in problems[:10]:
        print(f"error: {p}", file=sys.stderr)
    if len(problems) > 10:
        print(f"error: …ほか {len(problems) - 10}件", file=sys.stderr)
    if problems:
        return 1

    words.extend(new_entries)
    counts[3] += len(new_entries)
    words.sort(key=lambda w: w["key"])

    # 例文 override の取りこぼし報告
    need_example = [
        w["key"] for w in words
        if w["editions"].get("GP2", {}).get("tier") == 2
        and not w["example"].strip()
        and not w["editions"]["GP2"].get("example", "").strip()
    ]
    unused = sorted(set(examples) - {w["key"] for w in words})

    MASTER.write_text(json.dumps(master, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    total = sum(counts.values())
    print(f"GP2: {total}語 (basic {counts[1]} / bridge {counts[2]} / core {counts[3]})")
    print(f"  core の内訳: 既存 {counts[3] - len(new_entries)}語（G2 tier2 の category "
          f"{'/'.join(sorted(CORE_CATEGORIES))}）+ 新規 {len(new_entries)}語")
    if need_example:
        print(f"  未執筆の bridge 例文: {len(need_example)}件 "
              f"（例: {', '.join(need_example[:5])}）")
    if unused:
        print(f"  警告: 使われていない例文 {len(unused)}件（例: {', '.join(unused[:5])}）",
              file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
