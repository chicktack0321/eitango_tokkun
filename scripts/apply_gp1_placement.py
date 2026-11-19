"""GP1（英検準1級）の placement と GP1 専用データを vocab/master.json に反映する。

設計は docs/vocab-database-spec.md §3〜§4。要点:

- GP1 basic(1)  = G2 の tier1 + tier2（2級アプリの無料帯。準1級から見れば既習）
- GP1 bridge(2) = vocab/gp1_bridge_words.txt の選抜語（G2 tier3 から529語）
                  + vocab/gp1_new_bridge.txt の新規語（頻出度A・副詞・句動詞）
- GP1 core(3)   = G2 tier3 のうち **選抜されなかった745語** + vocab/gp1_new_core.txt の新規語

なぜ G2 tier3 を全量 bridge にしないのか。2級アプリは公開中で、その core 1,274語が
売り物である。準1級アプリの無料帯へ全量を流すと、¥500 で売っているものを自社の新作が
無料で配ることになる（コア独自性ルール。GP2 で実際に起きた事故）。選抜を41.5%に抑え、
2級アプリの独自性を58.5%に保つ。**残りを GP1 の core に据えるのは有料帯どうしの重複で、
独自性ルールに抵触しない**（abstract / advocate / ambiguous のような語は実質B2帯で、
準1級アプリから抜け落ちる方が商品として不自然）。

GP2 専用の新規語（A2帯。apron / faucet など）は GP1 には載せない。載せると
準2級アプリの課金対象が準1級アプリの無料帯に出てしまう（GP2 の独自性が 0% に落ちる）。

再実行してよい（毎回計算し直して上書きする）。
"""
import io
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MASTER = ROOT / "vocab/master.json"
BRIDGE_LIST = ROOT / "vocab/gp1_bridge_words.txt"
NEW_CORE = ROOT / "vocab/gp1_new_core.txt"
NEW_BRIDGE = ROOT / "vocab/gp1_new_bridge.txt"

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


def load_new_words(path, tier, existing_words, seen):
    """GP1 専用の新規語を canonical entry の形にして返す。"""
    rows = read_table(path, ["word", "meaning", "example", "partOfSpeech", "domain", "category"])
    entries = []
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
            problems.append(f"{word}: tier{tier} なのに例文が無い")
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
            "editions": {"GP1": {"tier": tier}},
        })
    return entries, problems


def main():
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")

    master = json.loads(MASTER.read_text(encoding="utf-8"))
    words = master["words"]

    # 前回の実行で追加した GP1 専用語を先に落とす。残したままだと、同じ語を
    # 新規語リストから読み直したときに「既にマスターにある」と誤検出する。
    # 他のエディションに載っている語（公開中・提出済みアプリのデータ）は決して消さない
    words[:] = [w for w in words if set(w["editions"]) != {"GP1"}]

    bridge_words = read_word_list(BRIDGE_LIST)
    tier3_words = {w["word"] for w in words if w["editions"].get("G2", {}).get("tier") == 3}
    unknown = sorted(bridge_words - tier3_words)
    if unknown:
        print(f"error: 選定リストの {len(unknown)}語が G2 tier3 に見つかりません: {unknown[:10]}",
              file=sys.stderr)
        return 1

    # 既存語の配置。GP1 に載るのは G2 に載っている語だけで、下位級専用の新規語は含めない
    counts = {1: 0, 2: 0, 3: 0}
    for entry in words:
        g2_tier = entry["editions"].get("G2", {}).get("tier")
        if g2_tier in (1, 2):
            gp1 = 1
        elif g2_tier == 3:
            gp1 = 2 if entry["word"] in bridge_words else 3
        else:
            entry["editions"].pop("GP1", None)
            continue
        entry["editions"]["GP1"] = {"tier": gp1}
        counts[gp1] += 1

    existing_words = {w["word"] for w in words}
    seen = set()
    new_core, problems = load_new_words(NEW_CORE, 3, existing_words, seen)
    new_bridge, more = load_new_words(NEW_BRIDGE, 2, existing_words, seen)
    problems += more
    for p in problems[:10]:
        print(f"error: {p}", file=sys.stderr)
    if len(problems) > 10:
        print(f"error: …ほか {len(problems) - 10}件", file=sys.stderr)
    if problems:
        return 1

    words.extend(new_core)
    words.extend(new_bridge)
    counts[3] += len(new_core)
    counts[2] += len(new_bridge)
    words.sort(key=lambda w: w["key"])

    # bridge / core は例文カバレッジ100%が必須（§6）。G2 tier3 由来の語は canonical に
    # 例文を持っているはずだが、取りこぼしがあれば build_seed が落ちる前にここで報せる
    need_example = [
        w["key"] for w in words
        if w["editions"].get("GP1", {}).get("tier") in (2, 3)
        and not w["example"].strip()
        and not w["editions"]["GP1"].get("example", "").strip()
    ]

    MASTER.write_text(json.dumps(master, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    total = sum(counts.values())
    print(f"GP1: {total}語 (basic {counts[1]} / bridge {counts[2]} / core {counts[3]})")
    print(f"  bridge の内訳: 選抜 {counts[2] - len(new_bridge)}語（G2 tier3 から）"
          f" + 新規 {len(new_bridge)}語")
    print(f"  core の内訳: 再利用 {counts[3] - len(new_core)}語（G2 tier3 の非選抜）"
          f" + 新規 {len(new_core)}語")
    if need_example:
        print(f"  error: 例文が無い bridge/core 語 {len(need_example)}件 "
              f"（例: {', '.join(need_example[:5])}）", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
