"""級ごとのアイコン元画像を描き起こす。

2級の元画像（`docs/assets/eitango-tokkun-logo-03.png`）は手作業で作ったもので、
公開済みのアプリがそれを使っている。シリーズを増やすたびに同じ手作業を繰り返すと、
級ごとに配色や字面の位置が微妙にずれて「同じシリーズに見えない」状態になるため、
2級以外はここでレイアウトを決め打ちにして機械的に生成する。

2級の元画像は**再生成しない**（公開済みのアイコンを描き直さない）。配色と余白は
その画像から実測した値をそのまま使うので、並べたときに同じシリーズとして見える。

使い方:
    python scripts/make_edition_logo.py --edition GP2
    python scripts/make_app_icon.py --edition GP2   # ← 続けてこちらでアイコン一式に変換

出力: docs/assets/eitango-tokkun-logo-<小文字ID>.png（1024×1024・アルファなし）
必要なもの: Pillow
"""
import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent

# 配色と背景グラデーションの実測元。2級の元画像に合わせる
REFERENCE = ROOT / "docs/assets/eitango-tokkun-logo-03.png"

SIZE = 1024

# 太いゴシック。Windows標準で、日本語のウェイトが十分あるものを使う
FONT_PATH = Path("C:/Windows/Fonts/BIZ-UDGothicB.ttc")

WHITE = (255, 255, 255)
YELLOW = (254, 217, 104)
SHADOW = (20, 18, 70)
SHADOW_OFFSET = 9

# 級の表記。lead は数字の上に載せる「準」（無い級は None）
GRADES = {
    "G4": {"lead": None, "number": "4"},
    "G3": {"lead": None, "number": "3"},
    "GP2": {"lead": "準", "number": "2"},
    "GP1": {"lead": "準", "number": "1"},
    "G1": {"lead": None, "number": "1"},
}


def gradient_background(reference):
    """背景は2級の元画像の左端1列をそのまま縦に伸ばす。

    近い色を目分量で置くと、ホーム画面に2つ並べたときに違う青に見える。
    実測値を使えばシリーズとしての一貫性が保証される。
    """
    bg = Image.new("RGB", (SIZE, SIZE))
    draw = ImageDraw.Draw(bg)
    for y in range(SIZE):
        draw.line([(0, y), (SIZE, y)], fill=reference.getpixel((2, y)))
    return bg


def render(grade):
    reference = Image.open(REFERENCE).convert("RGB")
    if reference.size != (SIZE, SIZE):
        raise SystemExit(f"error: 実測元が {SIZE}×{SIZE} ではありません（{reference.size}）")

    image = gradient_background(reference)
    draw = ImageDraw.Draw(image)

    def text(xy, body, size, fill, anchor="la"):
        font = ImageFont.truetype(str(FONT_PATH), size)
        x, y = xy
        # 影は本体と同じ字を少しずらして先に描く。濃紺の背景に黄色を置くと
        # 縁が甘くなり、小さいサイズで字が溶ける
        draw.text((x + SHADOW_OFFSET, y + SHADOW_OFFSET), body, font=font, fill=SHADOW, anchor=anchor)
        draw.text((x, y), body, font=font, fill=fill, anchor=anchor)

    # 共通のブランド部分（全級で同じ位置・同じ大きさ）
    text((512, 16), "英単語", 300, WHITE, "ma")
    text((26, 730), "英検", 208, WHITE, "la")
    text((450, 722), "\u00ae", 85, WHITE, "la")

    if grade["lead"]:
        # 「準」がある級は、数字の上に載せて 準→数字→級 の順に読ませる。
        # 横に3文字並べると数字が小さくなり、ホーム画面で級が読めなくなる
        text((26, 330), "特訓", 268, YELLOW, "la")
        text((820, 318), grade["lead"], 210, YELLOW, "ma")
        text((640, 540), grade["number"], 380, YELLOW, "la")
        text((840, 745), "級", 152, YELLOW, "la")
    else:
        # 2級の元画像と同じ組み方
        text((26, 330), "特訓", 300, YELLOW, "la")
        text((620, 300), grade["number"], 620, YELLOW, "la")
        text((855, 760), "級", 150, YELLOW, "la")

    return image


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--edition", required=True, help="エディション識別子（GP2 など）")
    args = parser.parse_args()

    if args.edition == "G2":
        print("error: 2級の元画像は手作業で作ったもので、公開済みのアイコンです。生成しません",
              file=sys.stderr)
        return 1
    grade = GRADES.get(args.edition)
    if grade is None:
        print(f"error: {args.edition} の級表記が GRADES に未登録です", file=sys.stderr)
        return 1
    if not FONT_PATH.exists():
        print(f"error: フォントがありません: {FONT_PATH}", file=sys.stderr)
        return 1

    image = render(grade)
    out = ROOT / f"docs/assets/eitango-tokkun-logo-{args.edition.lower()}.png"
    # アルファを持たせない。透過つきのアイコンは審査で弾かれる
    image.convert("RGB").save(out, "PNG", optimize=True)
    print(f"wrote {out} {image.size}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
