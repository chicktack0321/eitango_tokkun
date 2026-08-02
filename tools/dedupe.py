#!/usr/bin/env python3
"""語彙ファイル間の重複を取り除く。

同じ語を複数の階層に書いてしまうと単語帳に二重に並び、4択のダミーも重複する。
Tier 3（試験の得点源）を優先して残し、より基礎側のファイルにある同じ語を落とす。
"""
import glob
import io
import os

ORDER = ["data/tier3*.txt", "data/idioms*.txt", "data/tier2*.txt", "data/tier1*.txt"]


def main() -> None:
    paths = [p for pattern in ORDER for p in sorted(glob.glob(pattern))]
    seen: set[str] = set()
    for path in paths:
        lines = io.open(path, encoding="utf-8").read().splitlines(True)
        kept, dropped = [], []
        for line in lines:
            text = line.strip()
            if not text or text.startswith("#"):
                kept.append(line)
                continue
            word = text.split("|")[0].strip().lower()
            if word in seen:
                dropped.append(word)
            else:
                seen.add(word)
                kept.append(line)
        if dropped:
            io.open(path, "w", encoding="utf-8", newline="").writelines(kept)
            print(f"{os.path.basename(path)}: 重複{len(dropped)}件を削除 -> {', '.join(dropped[:10])}")


if __name__ == "__main__":
    main()
