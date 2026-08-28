#!/usr/bin/env python3
"""
Godotがエクスポートのたびに docs/index.service.worker.js を再生成すると、
self.skipWaiting() / self.clients.claim() の追記が失われる。
そのため、エクスポート後に毎回これを実行して「新しいバージョンをすぐに
有効化する」パッチを当て直す。

使い方（プロジェクトルートで実行）:
    python scripts/patch_service_worker.py
"""
import re
import sys
from pathlib import Path

SW_PATH = Path(__file__).resolve().parent.parent / "docs" / "index.service.worker.js"

INSTALL_MARK = "self.skipWaiting();"
ACTIVATE_MARK = "self.clients.claim();"


def main():
    if not SW_PATH.exists():
        print(f"見つかりません: {SW_PATH}（先にGodotでエクスポートしてください）")
        sys.exit(1)

    text = SW_PATH.read_text(encoding="utf-8")

    if INSTALL_MARK in text and ACTIVATE_MARK in text:
        print("既にパッチ済みです。何もしません。")
        return

    # install ハンドラの直前で addAll した直後に skipWaiting を追加
    text, n1 = re.subn(
        r"(self\.addEventListener\('install', \(event\) => \{\s*\n\s*event\.waitUntil\(caches\.open\(CACHE_NAME\)\.then\(\(cache\) => cache\.addAll\(CACHED_FILES\)\)\);\n)(\}\);)",
        r"\1\t// 新しいバージョンをすぐに有効化する（タブを閉じるまで待たない）\n\tself.skipWaiting();\n\2",
        text,
        count=1,
    )

    # activate ハンドラの Promise チェーンの末尾に clients.claim() を追加
    text, n2 = re.subn(
        r"(return \('navigationPreload' in self\.registration\) \? self\.registration\.navigationPreload\.enable\(\) : Promise\.resolve\(\);\n\t\}\))(\)\);)",
        r"\1.then(function () {\n\t\t// 開いているタブの制御もすぐに引き継ぐ\n\t\treturn self.clients.claim();\n\t})\2",
        text,
        count=1,
    )

    if n1 == 0 or n2 == 0:
        print("警告: パターンが一致しませんでした（Godotのテンプレートが変わった可能性）。手動確認してください。")
        sys.exit(1)

    SW_PATH.write_text(text, encoding="utf-8")
    print(f"パッチ適用完了: {SW_PATH}")


if __name__ == "__main__":
    main()
