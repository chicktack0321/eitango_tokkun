"""各エディションの core（課金対象）が、他エディションの無料帯とどれだけ重なるかを検査する。

シリーズ全体で語彙を一元管理しているため、素朴に「級のスライド」で配置すると
**あるアプリの課金対象が、別のアプリでは無料で学習できてしまう**。
この検査はその重なりを定量化する（docs/vocab-database-spec.md §4）。

用語:
- 無料帯   = tier1(basic) + tier2(bridge)。未購入・試用終了後でも出題される範囲
- 独自性率 = そのエディションの core のうち、他のどのエディションの無料帯にも
             載っていない語の割合。高いほど「そのアプリを買う理由」が守られている

使い方:
    python scripts/check_core_exclusivity.py            # レポート表示のみ
    python scripts/check_core_exclusivity.py --gate     # 目標値未達なら exit 1
"""
import argparse
import io
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MASTER = ROOT / "vocab/master.json"

FREE_TIERS = (1, 2)
CORE_TIER = 3

# 独自性率の目標値（%）。docs/vocab-database-spec.md §4 に根拠を書くこと。
# 既定は 50。隣接級との重複が構造的に避けられないエディションはここで個別に緩める。
DEFAULT_TARGET = 50
# 個別に緩めるエディションがあればここに書く。**緩める根拠を
# docs/vocab-database-spec.md §4 に必ず残すこと。**
# GP2 は当初 core が G2 の無料 bridge そのもの（独自性 0%）で、隣接級ゆえ
# 到達不能とみて 30% を置いていたが、専用の新規 core 語を書き足して既定値を満たした。
TARGETS = {}

# App内課金を持たないエディション。守るべき売り物が無いので独自性は評価しない。
# 一方、**そのエディションでは core も無料で出題される**ため、他エディションの
# core がここへ流れ込んでいないかは見る必要がある（core を無料帯として数える）。
#
# G4・G3 がこれに当たる。4級・3級の語彙帯は公開中の2級アプリの basic 帯に
# 構造的にほぼ全部含まれており（中学レベルの語を143語サンプリングして
# master に無いのは5語）、独自性50%を満たすには級に合わない語で水増しするしかない。
# 有料にせず、上位級への入口として無料で出す判断をした（2026-09-12）。
# 根拠は docs/vocab-database-spec.md §4「無料エディション」。
FREE_EDITIONS = {"G4", "G3"}


def load_master():
    return json.loads(MASTER.read_text(encoding="utf-8"))


def index_by_edition(words):
    """エディション -> {core: set(key), free: set(key)}

    課金の無いエディションでは core も無料で出題されるので free にも入れる。
    """
    result = {}
    for entry in words:
        for edition, placement in entry["editions"].items():
            slot = result.setdefault(edition, {"core": set(), "free": set()})
            tier = placement.get("tier")
            if tier == CORE_TIER:
                slot["core"].add(entry["key"])
                if edition in FREE_EDITIONS:
                    slot["free"].add(entry["key"])
            elif tier in FREE_TIERS:
                slot["free"].add(entry["key"])
    return result


def report(index, gate):
    editions = sorted(index)
    failed = []

    for edition in editions:
        core = index[edition]["core"]
        if not core:
            continue
        if edition in FREE_EDITIONS:
            print(f"[--] {edition}: core {len(core)}語 / 課金なし（独自性は評価しない）")
            continue
        others = [e for e in editions if e != edition]
        leaked_any = set()
        pairs = []
        for other in others:
            overlap = core & index[other]["free"]
            if overlap:
                pairs.append((other, overlap))
                leaked_any |= overlap
        exclusive = len(core) - len(leaked_any)
        rate = exclusive / len(core) * 100
        target = TARGETS.get(edition, DEFAULT_TARGET)
        mark = "OK" if rate >= target else "NG"

        print(f"[{mark}] {edition}: core {len(core)}語 / 独自 {exclusive}語 "
              f"= 独自性 {rate:.1f}%（目標 {target}%）")
        for other, overlap in sorted(pairs, key=lambda p: -len(p[1])):
            print(f"       {other} の無料帯に {len(overlap)}語 "
                  f"({len(overlap) / len(core) * 100:.1f}%) が露出: "
                  f"{', '.join(sorted(overlap)[:5])} …")
        if not pairs:
            print("       他エディションの無料帯との重複なし")
        if rate < target:
            failed.append(edition)

    if failed:
        print()
        sys.stdout.flush()
        print(f"独自性が目標未達: {', '.join(failed)}", file=sys.stderr)
        print("→ core に当該級専用の語を追加するか、下位級 core の上位級無料帯への"
              "スライドを選抜に絞ること（docs/vocab-database-spec.md §4）", file=sys.stderr)
        return 1 if gate else 0
    return 0


def main():
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")

    parser = argparse.ArgumentParser()
    parser.add_argument("--gate", action="store_true",
                        help="目標値未達を exit 1 にする（CI 用）")
    args = parser.parse_args()

    master = load_master()
    index = index_by_edition(master["words"])
    if not index:
        print("error: 配置されたエディションがありません", file=sys.stderr)
        return 1
    return report(index, args.gate)


if __name__ == "__main__":
    sys.exit(main())
