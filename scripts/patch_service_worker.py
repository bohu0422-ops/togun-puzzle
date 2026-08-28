#!/usr/bin/env python3
"""
Godotがエクスポートのたびに docs/index.service.worker.js を再生成すると、
self.skipWaiting() / self.clients.claim() の追記が失われる。
そのため、エクスポート後に毎回これを実行して「新しいバージョンをすぐに
有効化する」パッチを当て直す。

使い方（プロジェクトルートで実行）:
    python scripts/patch_service_worker.py
"""
import sys
from pathlib import Path

SW_PATH = Path(__file__).resolve().parent.parent / "docs" / "index.service.worker.js"

INSTALL_OLD = (
    "self.addEventListener('install', (event) => {\n"
    "\tevent.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(CACHED_FILES)));\n"
    "});\n"
)
INSTALL_NEW = (
    "self.addEventListener('install', (event) => {\n"
    "\tevent.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(CACHED_FILES)));\n"
    "\t// 新しいバージョンをすぐに有効化する（タブを閉じるまで待たない）\n"
    "\tself.skipWaiting();\n"
    "});\n"
)

ACTIVATE_OLD = (
    "\t\treturn ('navigationPreload' in self.registration) ? self.registration.navigationPreload.enable() : Promise.resolve();\n"
    "\t}));\n"
    "});\n"
)
ACTIVATE_NEW = (
    "\t\treturn ('navigationPreload' in self.registration) ? self.registration.navigationPreload.enable() : Promise.resolve();\n"
    "\t}).then(function () {\n"
    "\t\t// 開いているタブの制御もすぐに引き継ぐ\n"
    "\t\treturn self.clients.claim();\n"
    "\t}));\n"
    "});\n"
)


def main():
    if not SW_PATH.exists():
        print(f"見つかりません: {SW_PATH}（先にGodotでエクスポートしてください）")
        sys.exit(1)

    text = SW_PATH.read_text(encoding="utf-8")
    already_patched = "self.skipWaiting();" in text.split("self.addEventListener('activate'")[0] \
        and "self.clients.claim();" in text.split("self.addEventListener('activate'")[1].split("});")[0]

    if already_patched:
        print("既にパッチ済みです。何もしません。")
        return

    if INSTALL_OLD not in text or ACTIVATE_OLD not in text:
        print("警告: Godotのテンプレートが想定と異なります。手動でファイルを確認してください。")
        print(f"  INSTALL_OLD 一致: {INSTALL_OLD in text}")
        print(f"  ACTIVATE_OLD 一致: {ACTIVATE_OLD in text}")
        sys.exit(1)

    text = text.replace(INSTALL_OLD, INSTALL_NEW, 1)
    text = text.replace(ACTIVATE_OLD, ACTIVATE_NEW, 1)

    SW_PATH.write_text(text, encoding="utf-8")
    print(f"パッチ適用完了: {SW_PATH}")


if __name__ == "__main__":
    main()
