#!/usr/bin/env python3
"""
Main.gd で使っている日本語文字だけを含む軽量フォントを作り直す。

なぜ必要か:
  Godot の内蔵フォントには日本語が入っていないため、Noto Sans JP を同梱している。
  ただしフォント全体は約10MBあり、そのまま入れるとWeb版が重くなり
  描画が崩れたりWebGLがクラッシュしたりする。そのため「実際に画面に出す文字」
  だけを抜き出した数十KBのフォントに絞り込んでいる。

いつ実行するか:
  **Main.gd に新しい日本語の文言を追加・変更したら必ず実行する。**
  実行を忘れると、新しく足した文字だけが豆腐（□）になる。

前提:
  - pip install fonttools
  - tools/font-source/NotoSansJP-Bold-static.ttf（元フォント）が存在すること
    無い場合は下記URLから可変フォントを取得し、wght=700 で静的化して置く:
      https://github.com/google/fonts/tree/main/ofl/notosansjp
    （ライセンス: SIL Open Font License 1.1 / assets/fonts/OFL-NotoSansJP.txt）

使い方（プロジェクトルートで実行）:
    python scripts/rebuild_font_subset.py
"""
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "Main.gd"
FONT_DIR = ROOT / "assets" / "fonts"
# 元フォントは tools/ 以下に置く（.gdignore があるのでゲーム本体には含まれない）
SOURCE_FONT = ROOT / "tools" / "font-source" / "NotoSansJP-Bold-static.ttf"
OUTPUT_FONT = FONT_DIR / "NotoSansJP.ttf"


def main():
    if not SCRIPT.exists():
        print(f"見つかりません: {SCRIPT}")
        sys.exit(1)
    if not SOURCE_FONT.exists():
        print(f"元フォントが見つかりません: {SOURCE_FONT}")
        print("（docstring の手順で用意してください）")
        sys.exit(1)

    text = SCRIPT.read_text(encoding="utf-8")
    chars = sorted({ch for ch in text if ord(ch) > 0x7E})
    print(f"必要な非ASCII文字: {len(chars)}種")

    with tempfile.NamedTemporaryFile(
        mode="w", encoding="utf-8", suffix=".txt", delete=False
    ) as tf:
        tf.write("".join(chars))
        charfile = tf.name

    cmd = [
        sys.executable, "-m", "fontTools.subset", str(SOURCE_FONT),
        f"--output-file={OUTPUT_FONT}",
        f"--text-file={charfile}",
        "--unicodes=U+0020-007E",  # 半角英数記号は全部残す
        "--glyph-names", "--symbol-cmap", "--legacy-cmap",
        "--notdef-glyph", "--notdef-outline", "--recommended-glyphs",
        "--name-IDs=*", "--name-legacy", "--name-languages=*",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    Path(charfile).unlink(missing_ok=True)

    if result.returncode != 0:
        print("フォントの生成に失敗しました:")
        print(result.stderr)
        sys.exit(1)

    size_kb = OUTPUT_FONT.stat().st_size / 1024
    print(f"生成完了: {OUTPUT_FONT} ({size_kb:.0f} KB)")
    print("→ このあとGodotで再エクスポートしてください。")


if __name__ == "__main__":
    main()
