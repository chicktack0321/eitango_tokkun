"""GP2（英検準2級）の placement を vocab/master.json に反映する。

設計（docs/series-architecture.md §4）:
- GP2 core(3)   = G2 の tier2 全体。「準2級〜2級の橋渡し帯」が準2級の得点源に相当する
- GP2 bridge(2) = G2 の tier1 のうち vocab/gp2_bridge_words.txt に載っている語（3級帯）
- GP2 basic(1)  = G2 の tier1 の残り（4級以下の既習語）
- G2 の tier3（2級コア・B1）は準2級より上のレベルなので GP2 には載せない

選定リストの語がマスターに見つからない場合はエラーにする（打ち間違いの検出）。
再実行してよい（毎回計算し直して上書きする）。
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MASTER = ROOT / "vocab/master.json"
BRIDGE_LIST = ROOT / "vocab/gp2_bridge_words.txt"


def main():
    master = json.loads(MASTER.read_text(encoding="utf-8"))
    bridge_words = {
        line.strip()
        for line in BRIDGE_LIST.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.startswith("#")
    }

    tier1_words = {w["word"] for w in master["words"] if w["editions"].get("G2", {}).get("tier") == 1}
    unknown = sorted(bridge_words - tier1_words)
    if unknown:
        print(f"error: 選定リストの {len(unknown)}語が G2 tier1 に見つかりません: {unknown[:10]}",
              file=sys.stderr)
        return 1

    counts = {1: 0, 2: 0, 3: 0}
    for entry in master["words"]:
        g2_tier = entry["editions"].get("G2", {}).get("tier")
        if g2_tier == 2:
            gp2 = 3
        elif g2_tier == 1:
            gp2 = 2 if entry["word"] in bridge_words else 1
        else:
            entry["editions"].pop("GP2", None)
            continue
        entry["editions"]["GP2"] = {"tier": gp2}
        counts[gp2] += 1

    MASTER.write_text(json.dumps(master, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    total = sum(counts.values())
    print(f"GP2: {total}語 (basic {counts[1]} / bridge {counts[2]} / core {counts[3]})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
