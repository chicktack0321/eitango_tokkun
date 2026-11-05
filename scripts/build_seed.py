"""語彙マスター（vocab/master.json）から各エディションの同梱 seed JSON を生成する。

使い方:
    python scripts/build_seed.py --edition G2 [--check] [--out パス]

--check は出力せず、現行の同梱 seed とデータ一致するかを検証する（G2 の移行検証用。
docs/series-implementation-handoff.md P0-3 の受け入れ基準）。

ルール（docs/series-architecture.md §5）:
- editions に当該エディションが載っている語だけを含める
- wordId は <プレフィクス>_<key>。key は公開後改名禁止
- editions.<ID> 内の meaning / example / category / domain は正本値を上書きできる
- core(3)・bridge(2) の例文カバレッジは100%でなければならない（basic は例文なしでよい）
- 聞き流し用の例文の和訳は vocab/example_translations.json（例文の英文 → 和訳）から、
  解説は vocab/explanations.json（key → 解説）から引く。editions.<ID>.explanation で上書きできる。
  和訳を例文の英文で引くのは、例文を直したときに古い和訳が黙って残らないようにするため
  （英文が変われば引けなくなり、未訳として数えられる）。
- 和訳は日本語の音声で読むため英字を含めてはならない（英字は日本語読みされて聞き取れない）。
  解説は画面表示だけだが、読み上げに戻す場合に備えて同じ制約を守る
"""
import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MASTER = ROOT / "vocab/master.json"
TRANSLATIONS = ROOT / "vocab/example_translations.json"
EXPLANATIONS = ROOT / "vocab/explanations.json"

EDITIONS = {
    "G4": "EIKEN_G4_",
    "G3": "EIKEN_G3_",
    "GP2": "EIKEN_GP2_",
    "G2": "EIKEN_G2_",
    "GP1": "EIKEN_GP1_",
    "G1": "EIKEN_G1_",
    "TOEIC": "TOEIC_",
}

def default_out(edition):
    """同梱先。エディション一式は Editions/<ID>/ に閉じ込めてある（設計書§7）"""
    return ROOT / f"Editions/{edition}/word_master_seed.json"

OVERRIDABLE = ["meaning", "example", "category", "domain", "explanation"]

LATIN = re.compile(r"[A-Za-zＡ-Ｚａ-ｚ]")


def load_optional(path):
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def build(master, edition, translations=None, explanations=None):
    translations = translations or {}
    explanations = explanations or {}
    prefix = EDITIONS[edition]
    out = []
    problems = []
    for entry in master["words"]:
        placement = entry["editions"].get(edition)
        if placement is None:
            continue
        tier = placement["tier"]
        if tier not in (1, 2, 3):
            problems.append(f"{entry['key']}: tier が不正 ({tier})")
            continue
        record = {
            "wordId": prefix + entry["key"],
            "word": entry["word"],
            "meaning": entry["meaning"],
            "example": entry["example"],
            "frequencyCount": entry.get("frequencyCount", 0),
            "category": entry["category"],
            "partOfSpeech": entry["partOfSpeech"],
            "tier": tier,
            "domain": entry["domain"],
            "isIdiom": entry.get("isIdiom", False),
        }
        if entry["key"] in explanations:
            record["explanation"] = explanations[entry["key"]]
        for field in OVERRIDABLE:
            if field in placement:
                record[field] = placement[field]
        translation = translations.get(record["example"].strip())
        if translation:
            record["exampleTranslation"] = translation
        # 空の解説と、例文の無い語の解説は出力しない。解説を出すのは例文モードの画面だけで、
        # 例文の無い語はそもそも流れないため、入れても seed が膨らむだけになる
        # （アプリ側は欠けていれば表示しない）
        if not record.get("explanation", "").strip() or not record["example"].strip():
            record.pop("explanation", None)
        for field in ("exampleTranslation", "explanation"):
            if field in record and LATIN.search(record[field]):
                problems.append(f"{entry['key']}: {field} に英字が含まれている ({record[field]})")
        if tier in (2, 3) and not record["example"].strip():
            problems.append(f"{entry['key']}: tier{tier} なのに例文が無い")
        out.append(record)

    ids = [r["wordId"] for r in out]
    if len(ids) != len(set(ids)):
        problems.append("wordId が重複している")
    return out, problems


def summarize(words):
    counts = {1: 0, 2: 0, 3: 0}
    for w in words:
        counts[w["tier"]] += 1
    return counts


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--edition", required=True, choices=sorted(EDITIONS))
    parser.add_argument("--check", action="store_true",
                        help="出力せず、既存の同梱 seed とのデータ一致を検証する")
    parser.add_argument("--out", type=Path, default=None)
    args = parser.parse_args()

    master = json.loads(MASTER.read_text(encoding="utf-8"))
    words, problems = build(master, args.edition, load_optional(TRANSLATIONS), load_optional(EXPLANATIONS))

    if not words:
        print(f"error: {args.edition} に配置された語がありません", file=sys.stderr)
        return 1
    for p in problems[:10]:
        print(f"error: {p}", file=sys.stderr)
    if len(problems) > 10:
        print(f"error: …ほか {len(problems) - 10}件", file=sys.stderr)

    counts = summarize(words)
    print(f"{args.edition}: {len(words)}語 (basic {counts[1]} / bridge {counts[2]} / core {counts[3]})")
    with_example = [w for w in words if w["example"].strip()]
    translated = sum(1 for w in with_example if w.get("exampleTranslation"))
    explained = sum(1 for w in with_example if w.get("explanation"))
    print(f"  例文あり {len(with_example)}語のうち 和訳 {translated} / 解説 {explained}")

    if args.check:
        current_path = default_out(args.edition)
        if not current_path.exists():
            print("error: 比較対象の既存 seed がありません", file=sys.stderr)
            return 1
        current = json.loads(current_path.read_text(encoding="utf-8"))["words"]
        built = {w["wordId"]: w for w in words}
        cur = {w["wordId"]: w for w in current}
        if built.keys() != cur.keys():
            only_new = sorted(built.keys() - cur.keys())[:5]
            only_old = sorted(cur.keys() - built.keys())[:5]
            print(f"error: wordId 集合が不一致 (+{only_new} / -{only_old})", file=sys.stderr)
            return 1
        diffs = [wid for wid in built if built[wid] != cur[wid]]
        if diffs:
            wid = diffs[0]
            print(f"error: {len(diffs)}語でフィールド不一致。例 {wid}:", file=sys.stderr)
            print(f"  built:   {built[wid]}", file=sys.stderr)
            print(f"  current: {cur[wid]}", file=sys.stderr)
            return 1
        print("check OK: 既存 seed とデータ一致")
        return 0

    if problems:
        return 1

    out_path = args.out or default_out(args.edition)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    seed_version = master.get("seedVersion", 1)
    out_path.write_text(
        json.dumps({"version": seed_version, "words": words}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
