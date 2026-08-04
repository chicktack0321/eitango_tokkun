"""焼き込まれた角丸・白い余白・影を取り除き、端まで塗られた正方形のアイコン素材を作る。

App Store のアイコンは Apple 側が角丸マスクをかけるため、素材側に角丸があってはいけない。
またアプリ内ロゴは cornerRadius: 10 の浅いクリップなので、角の残りがそのまま見える。

背景は縦方向のグラデーションなので、絵柄の無い列から地の色を行ごとに実測し、
角丸の外側（白い余白と、その内側の影）をその色で塗り直す。

使い方: リポジトリのどこからでも `python scripts/make_app_icon.py`
必要なもの: Pillow
"""
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "docs/assets/eitango-tokkun-logo-02.png"
ASSETS = ROOT / "EitangoApp/Resources/Assets.xcassets"
OUT_ICON = ASSETS / "AppIcon.appiconset/AppIcon-1024.png"
OUT_LOGO_DIR = ASSETS / "AppLogo.imageset"

LIGHT_MIN = 150      # これより明るければ角丸の外側の余白とみなす
EDGE_MARGIN = 26     # 境界から内側へこの幅ぶん余計に塗り、影とアンチエイリアスを消す
BG_COLUMN = 50       # 地の色を採る列（文字も月桂樹もかからない）
BG_SAFE = 220        # 角丸の弧が終わる位置。この範囲の行だけ地の色の標本に使う


def is_light(p):
    return min(p[0], p[1], p[2]) > LIGHT_MIN


def sample_background(im):
    """地の色を行ごとに実測する。

    グラデーションは直線ではないため、一次近似すると上端で色がずれる。
    標本を移動平均でならし、弧の外側（標本の取れない上下端）は
    最も近い行の色をそのまま延長する。
    """
    px = im.load()
    W, H = im.size
    lo, hi = BG_SAFE, H - BG_SAFE
    raw = [px[BG_COLUMN, y] for y in range(lo, hi)]

    half = 15
    smooth = []
    for i in range(len(raw)):
        a, b = max(0, i - half), min(len(raw), i + half + 1)
        window = raw[a:b]
        smooth.append(tuple(round(sum(p[ch] for p in window) / len(window)) for ch in range(3)))

    def bg(y):
        return smooth[min(max(y - lo, 0), len(smooth) - 1)]

    return bg


def flatten_edges(im, bg):
    im = im.convert("RGB").copy()
    W, H = im.size
    px = im.load()
    hlimit, vlimit = W // 4, H // 4

    for y in range(H):
        c = bg(y)
        x = 0
        while x < hlimit and is_light(px[x, y]):
            x += 1
        end = hlimit if x >= hlimit else x + EDGE_MARGIN
        for i in range(min(end, W)):
            px[i, y] = c
        x = W - 1
        while x > W - 1 - hlimit and is_light(px[x, y]):
            x -= 1
        start = W - 1 - hlimit if x <= W - 1 - hlimit else x - EDGE_MARGIN
        for i in range(max(start, 0), W):
            px[i, y] = c

    # 行方向だけでは、行全体が明るい上下端（弧の外側）が残る
    for x in range(W):
        y = 0
        while y < vlimit and is_light(px[x, y]):
            y += 1
        if y:
            for i in range(min(y + EDGE_MARGIN, H)):
                px[x, i] = bg(i)
        y = H - 1
        while y > H - 1 - vlimit and is_light(px[x, y]):
            y -= 1
        if y < H - 1:
            for i in range(max(y - EDGE_MARGIN, 0), H):
                px[x, i] = bg(i)
    return im


def to_square(im, trim=4):
    W, H = im.size
    im = im.crop((trim, trim, W - trim, H - trim))
    W, H = im.size
    s = min(W, H)
    return im.crop(((W - s) // 2, (H - s) // 2, (W - s) // 2 + s, (H - s) // 2 + s))


def main():
    src = Image.open(SRC).convert("RGB")
    print("source:", src.size)

    bg = sample_background(src)
    print("bg(top)=%s bg(mid)=%s bg(bottom)=%s" % (bg(0), bg(src.size[1] // 2), bg(src.size[1] - 1)))

    square = to_square(flatten_edges(src, bg))
    print("squared:", square.size)

    icon = square.resize((1024, 1024), Image.LANCZOS)
    icon.save(OUT_ICON, "PNG", optimize=True)
    print("wrote AppIcon-1024.png", icon.size, icon.mode)

    for name, size in [("AppLogo.png", 80), ("AppLogo@2x.png", 160), ("AppLogo@3x.png", 240)]:
        square.resize((size, size), Image.LANCZOS).save(OUT_LOGO_DIR / name, "PNG", optimize=True)
        print("wrote", name, size)


if __name__ == "__main__":
    sys.exit(main())
