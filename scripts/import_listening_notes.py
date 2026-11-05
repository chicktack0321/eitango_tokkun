"""聞き流しの例文モードで読む「例文の和訳」と「解説」を取り込む。

使い方:
    python scripts/import_listening_notes.py --edition G4 notes.tsv [notes2.tsv ...]

TSV は1行1語で「key<TAB>例文の和訳<TAB>解説」。key は vocab/master.json の key。
和訳は、そのエディションで実際に使う例文（editions.<ID>.example の上書きを反映したもの）に
ひも付けて vocab/example_translations.json に書く。解説は vocab/explanations.json に書く。

既にある値は上書きする（見直した版を取り込み直せるように）。空欄の列は取り込まない。
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

LATIN = re.compile(r"[A-Za-zＡ-Ｚａ-ｚ]")


def load(path):
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def save(path, data):
    path.write_text(
        json.dumps(dict(sorted(data.items())), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--edition", required=True)
    parser.add_argument("files", nargs="+", type=Path)
    args = parser.parse_args()

    master = json.loads(MASTER.read_text(encoding="utf-8"))
    examples = {}
    for entry in master["words"]:
        placement = entry["editions"].get(args.edition)
        if placement is not None:
            examples[entry["key"]] = placement.get("example", entry["example"]).strip()

    translations = load(TRANSLATIONS)
    explanations = load(EXPLANATIONS)
    problems = []
    imported = 0

    for path in args.files:
        for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if not line.strip():
                continue
            cols = line.split("\t")
            where = f"{path.name}:{lineno}"
            if len(cols) != 3:
                problems.append(f"{where}: 列が3つではない")
                continue
            key, translation, explanation = (c.strip() for c in cols)
            if key not in examples:
                problems.append(f"{where}: {key} は {args.edition} に無い")
                continue
            for label, text in (("和訳", translation), ("解説", explanation)):
                if LATIN.search(text):
                    problems.append(f"{where}: {key} の{label}に英字がある")
            if translation:
                if not examples[key]:
                    problems.append(f"{where}: {key} には例文が無い")
                else:
                    translations[examples[key]] = translation
            if explanation:
                explanations[key] = explanation
            imported += 1

    for p in problems:
        print(f"error: {p}", file=sys.stderr)
    if problems:
        return 1

    save(TRANSLATIONS, translations)
    save(EXPLANATIONS, explanations)
    print(f"{imported}語を取り込んだ（和訳 計{len(translations)} / 解説 計{len(explanations)}）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
