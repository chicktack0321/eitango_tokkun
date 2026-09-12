"""G4（英検4級）と G3（英検3級）の placement を vocab/master.json に反映する。

設計は docs/vocab-database-spec.md §3。下位2級は同じ母体（2級アプリの基礎1,512語）を
帯の切り方だけ変えて使うため、1本のスクリプトで両方を作る。ここを分けると
「4級の core と3級の bridge が食い違う」状態が静かに生まれる。

母体の分け方:

    G2 tier1（1,512語・中学〜高校基礎）
      ├─ 3級帯 626語 …… vocab/gp2_bridge_words.txt（準2級の設計で選定済み）
      └─ 〜4級帯 886語
           ├─ 既習 297語 …… vocab/g4_basic_words.txt + どちらのリストにも無い語
           └─ 学習対象 589語 …… vocab/g4_core_words.txt

帯の割り当て:

    G4  basic(1) = 既習297 / bridge(2) = 学習対象のうち category A / core(3) = 同 B・C
    G3  basic(1) = 既習297 / bridge(2) = 学習対象589 全部  / core(3) = 3級帯626

G4 の bridge と core を頻出度（category）で割るのは、2級過去問での頻度が高い語ほど
早い級で出会うという関係を使った機械的な切り分け。手で線を引くと根拠が残らない。
**G4・G3 は無料アプリ**なので、この線引きは表示ラベルと既定の出題範囲にしか影響せず、
課金の境界にはならない（docs/vocab-database-spec.md §4 の「無料エディション」）。

例文（core・bridge は100%必須。仕様書§6）:
- vocab/jhs_band_examples.txt    学習対象589語。G4 の bridge/core と G3 の bridge に使う
- vocab/gp2_bridge_examples.txt  3級帯626語。準2級用に書いたものを G3 の core に流用する

いずれも **canonical ではなく editions.<ID>.example に入れる**。canonical に書くと
公開中の2級アプリの同梱 seed が変わり、再現一致ゲートが落ちる（仕様書§5）。

再実行してよい（毎回計算し直して上書きする）。
"""
import collections
import io
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MASTER = ROOT / "vocab/master.json"

BAND3_LIST = ROOT / "vocab/gp2_bridge_words.txt"
BAND3_EXAMPLES = ROOT / "vocab/gp2_bridge_examples.txt"
G4_BASIC_LIST = ROOT / "vocab/g4_basic_words.txt"
G4_STUDY_LIST = ROOT / "vocab/g4_core_words.txt"
JHS_EXAMPLES = ROOT / "vocab/jhs_band_examples.txt"
G3_EXTRA_LIST = ROOT / "vocab/g3_extra_core_words.txt"
G4_EXTRA_LIST = ROOT / "vocab/g4_extra_core_words.txt"

# レビュー用に書き出す（仕様書§9: 配置の根拠を人が確認できる形で残す）
G4_BRIDGE_REVIEW = ROOT / "vocab/g4_bridge_words.txt"

# G4 で bridge に残す頻出度ランク。残りが core になる
G4_BRIDGE_CATEGORIES = {"A"}

# 品詞を補うために2級アプリの架け橋帯から持ってこられる頻出度ランク。
# category A は準2級アプリの課金対象なので、無料アプリに入れてはならない
# （入れると準2級の売り物が無料で配られる。仕様書§4 ルールA）
EXTRA_SOURCE_CATEGORIES = {"B", "C"}


def read_word_list(path):
    if not path.exists():
        raise SystemExit(f"error: {path} がありません")
    return [
        line.strip()
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.startswith("#")
    ]


def read_pairs(path, label):
    """`左 | 右` のテキストを dict で返す。空行と # 始まりは無視する。"""
    if not path.exists():
        raise SystemExit(f"error: {path} がありません")
    out = {}
    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip() or line.startswith("#"):
            continue
        cells = line.split("|")
        if len(cells) != 2:
            raise SystemExit(f"{path.name}:{lineno}: 列数が {len(cells)}（期待 2）: {line[:60]}")
        left, right = cells[0].strip(), cells[1].strip()
        if left in out:
            raise SystemExit(f"{path.name}:{lineno}: {label} が重複: {left}")
        out[left] = right
    return out


def main():
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")

    master = json.loads(MASTER.read_text(encoding="utf-8"))
    words = master["words"]
    by_word = {}
    for entry in words:
        by_word.setdefault(entry["word"], entry)

    jhs = [e for e in words if (e["editions"].get("G2") or {}).get("tier") == 1]
    jhs_words = {e["word"] for e in jhs}
    print(f"母体（G2 tier1）: {len(jhs)}語")

    problems = []

    def resolve(names, label):
        keys = set()
        for name in names:
            entry = by_word.get(name)
            if entry is None:
                problems.append(f"{label}: master に無い語 '{name}'")
                continue
            if name not in jhs_words:
                problems.append(f"{label}: 母体（G2 tier1）の外の語 '{name}'")
                continue
            keys.add(entry["key"])
        return keys

    # 品詞を補うための追加語。母体（G2 tier1）の外から採るので resolve は使わない
    def resolve_extra(names, label):
        keys = set()
        for name in names:
            entry = by_word.get(name)
            if entry is None:
                problems.append(f"{label}: master に無い語 '{name}'")
                continue
            if (entry["editions"].get("G2") or {}).get("tier") != 2:
                problems.append(f"{label}: 2級アプリの架け橋帯の外の語 '{name}'")
                continue
            if entry["category"] not in EXTRA_SOURCE_CATEGORIES:
                problems.append(
                    f"{label}: category {entry['category']} は準2級の課金対象。"
                    f"無料アプリに入れられない '{name}'"
                )
                continue
            if not entry["example"]:
                problems.append(f"{label}: 例文が無い '{name}'")
                continue
            keys.add(entry["key"])
        return keys

    band3 = resolve(read_word_list(BAND3_LIST), "3級帯リスト")
    lower = {e["key"] for e in jhs} - band3

    g4_basic_named = resolve(read_word_list(G4_BASIC_LIST), "既習リスト")
    g4_study = resolve(read_word_list(G4_STUDY_LIST), "学習対象リスト")

    overlap = g4_basic_named & g4_study
    if overlap:
        problems.append(f"既習リストと学習対象リストに重複が {len(overlap)}語: "
                        + ", ".join(sorted(overlap)[:5]))
    outside = (g4_basic_named | g4_study) - lower
    if outside:
        problems.append(f"〜4級帯の外を指しているリスト項目が {len(outside)}語: "
                        + ", ".join(sorted(outside)[:5]))

    # どちらのリストにも無い語は既習に落とす。取りこぼしても
    # 「知らない語が出題されない」だけで済み、逆より安全
    leftover = lower - g4_basic_named - g4_study
    g4_basic = g4_basic_named | leftover

    jhs_examples = read_pairs(JHS_EXAMPLES, "見出し語")
    band3_examples = read_pairs(BAND3_EXAMPLES, "key")

    by_key = {e["key"]: e for e in words}
    example_by_key = {}
    for name, sentence in jhs_examples.items():
        entry = by_word.get(name)
        if entry is None:
            problems.append(f"例文ファイル: master に無い語 '{name}'")
            continue
        example_by_key[entry["key"]] = sentence
    for key, sentence in band3_examples.items():
        if key not in by_key:
            problems.append(f"3級帯の例文ファイル: master に無い key '{key}'")
            continue
        example_by_key[key] = sentence

    g3_extra = resolve_extra(read_word_list(G3_EXTRA_LIST), "3級の品詞補充リスト")
    g4_extra = resolve_extra(read_word_list(G4_EXTRA_LIST), "4級の品詞補充リスト")
    if g4_extra - g3_extra:
        problems.append(
            "4級の品詞補充リストは3級のリストの部分集合であること。"
            f"3級に無い語が {len(g4_extra - g3_extra)}語"
        )

    g4_bridge = {k for k in g4_study if by_key[k]["category"] in G4_BRIDGE_CATEGORIES}
    g4_core = (g4_study - g4_bridge) | g4_extra

    placements = {
        "G4": {1: g4_basic, 2: g4_bridge, 3: g4_core},
        "G3": {1: g4_basic, 2: g4_study, 3: band3 | g3_extra},
    }

    # 例文の取りこぼしは build_seed.py でも落ちるが、そこでは
    # 「どのリストに足せばよいか」が分からないのでここで具体的に言う
    for edition, bands in placements.items():
        for tier in (2, 3):
            missing = sorted(k for k in bands[tier]
                             if not (example_by_key.get(k) or by_key[k]["example"]))
            if missing:
                problems.append(
                    f"{edition} tier{tier}: 例文が無い語が {len(missing)}語 "
                    f"({', '.join(missing[:5])} …)"
                )

    if problems:
        for p in problems[:10]:
            print(f"error: {p}", file=sys.stderr)
        if len(problems) > 10:
            print(f"error: …ほか {len(problems) - 10}件", file=sys.stderr)
        return 1

    for edition, bands in placements.items():
        for entry in words:
            entry["editions"].pop(edition, None)
        for tier, keys in bands.items():
            for key in keys:
                placement = {"tier": tier}
                # 母体の語は2級では basic で例文を持たないので override を与える。
                # 品詞補充で持ってきた語は canonical に例文があるのでそのまま使う
                if tier in (2, 3) and key in example_by_key:
                    placement["example"] = example_by_key[key]
                by_key[key]["editions"][edition] = placement
        counts = {t: len(bands[t]) for t in (1, 2, 3)}
        pos = collections.Counter(
            by_key[k]["partOfSpeech"] for t in (2, 3) for k in bands[t]
        )
        total = sum(pos.values())
        mix = " / ".join(f"{name} {100 * pos[name] / total:.0f}%"
                         for name in ("noun", "verb", "adjective"))
        print(f"{edition}: {sum(counts.values())}語 "
              f"(basic {counts[1]} / bridge {counts[2]} / core {counts[3]})  出題対象の品詞 {mix}")

    MASTER.write_text(
        json.dumps(master, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"wrote {MASTER}")

    G4_BRIDGE_REVIEW.write_text(
        "# G4（英検4級）の bridge（5級帯）に落ちた語。\n"
        "#\n"
        "# **このファイルは scripts/apply_lower_grades_placement.py が生成する。**\n"
        "# 手で編集しても次回の実行で消える。語を動かすときは g4_basic_words.txt か\n"
        "# g4_core_words.txt を直すこと。\n"
        "#\n"
        "# 学習対象589語のうち category が A（2級過去問で最頻出）のもの。\n"
        "# 帯の切り分けが妥当かはこの一覧で確認する（仕様書§9）。\n"
        + "\n".join(sorted(by_key[k]["word"] for k in g4_bridge)) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {G4_BRIDGE_REVIEW}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
