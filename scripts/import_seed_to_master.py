"""現行の2級 seed から語彙マスター（vocab/master.json）の初期版を作る。

シリーズ展開の語彙は vocab/master.json を正本にする（docs/series-architecture.md §5）。
その初期データは、公開済み2級アプリの同梱 seed から逆輸入する。

- canonical key は wordId のプレフィクス（EIKEN_G2_）を外したもの。**公開後は改名禁止**
- 正本フィールド（word/meaning/example/...）は現行 seed の値をそのまま採用する
- 全語に editions.G2 = {tier: 現行値} を付ける

一度マスター方式へ移行したら本スクリプトは再実行しない（マスター側の編集が正になるため）。
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SEED = ROOT / "EitangoApp/Resources/word_master_seed.json"
OUT = ROOT / "vocab/master.json"

G2_PREFIX = "EIKEN_G2_"


def main():
    seed = json.loads(SEED.read_text(encoding="utf-8"))
    words = []
    for entry in seed["words"]:
        word_id = entry["wordId"]
        if not word_id.startswith(G2_PREFIX):
            print(f"error: 想定外の wordId: {word_id}", file=sys.stderr)
            return 1
        words.append({
            "key": word_id[len(G2_PREFIX):],
            "word": entry["word"],
            "meaning": entry["meaning"],
            "example": entry["example"],
            "partOfSpeech": entry["partOfSpeech"],
            "domain": entry["domain"],
            "category": entry["category"],
            "frequencyCount": entry["frequencyCount"],
            "isIdiom": entry["isIdiom"],
            "editions": {"G2": {"tier": entry["tier"]}},
        })

    keys = [w["key"] for w in words]
    if len(keys) != len(set(keys)):
        print("error: key が重複しています", file=sys.stderr)
        return 1

    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text(
        json.dumps({"version": 1, "seedVersion": seed["version"], "words": words},
                   ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {OUT.relative_to(ROOT)}: {len(words)}語")
    return 0


if __name__ == "__main__":
    sys.exit(main())
