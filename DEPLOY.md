# GitHub Pages デプロイガイド

TOGUN Puzzle を GitHub Pages で公開するための手順です。

## 前提条件

- GitHub アカウント（無料で作成可能）
- Git がインストールされていること
- Godot 4.3 で HTML5 エクスポート済み

## ステップ1：GitHub に新規リポジトリを作成

1. https://github.com/new にアクセス
2. **Repository name**: `togun-puzzle`
3. **Public** を選択（GitHub Pages で公開するため）
4. **Add a README file** はチェック不要（後で追加します）
5. **Create repository** をクリック

---

## ステップ2：ローカルリポジトリを初期化

```bash
cd C:\Users\user\Desktop\togun_puzzle

# 既に git リポジトリでなければ初期化
git init

# リモートを設定（USERNAME を自分のGitHub IDに置き換え）
git remote add origin https://github.com/USERNAME/togun-puzzle.git

# 初期コミット
git add .
git commit -m "Initial commit: TOGUN Puzzle project"

# GitHub に push
git branch -M main
git push -u origin main
```

---

## ステップ3：GitHub Pages の設定

1. GitHub リポジトリページへ移動
2. **Settings** タブをクリック
3. 左メニューから **Pages** を選択
4. **Source** で `main` ブランチ、`/docs` フォルダを選択
5. **Save** をクリック

→ 数秒後、`https://USERNAME.github.io/togun-puzzle` でゲームが公開されます

---

## ステップ4：Godot で HTML5 エクスポート

1. Godot で `Project` > `Export` を開く
2. **Web** を選択（すでに設定済み）
3. **Export Path**: `docs/index.html` を指定
4. **Export Project** をクリック

→ `docs/` フォルダに以下が生成されます：
- `index.html` ← メイン（自動生成）
- `index.js` ← ゲームロジック
- `index.pck` ← ゲームデータ
- `index.wasm` ← WebAssembly（ゲーム実行エンジン）

---

## ステップ5：変更を GitHub に反映

```bash
cd C:\Users\user\Desktop\togun_puzzle

git add docs/
git commit -m "Export game for web"
git push origin main
```

数分でゲームが公開されます。

---

## iPhone で「ホーム画面に追加」する手順

1. Safari で `https://USERNAME.github.io/togun-puzzle` を開く
2. 下のメニューバーの **共有** アイコンをタップ
3. **ホーム画面に追加** を選択
4. アプリ名は「TOGUN」のまま OK
5. **追加** をタップ

→ その後オフラインでも遊べます（キャッシュ済みファイルから読み込み）

---

## トラブルシューティング

### Q: ゲームが真っ黒で何も表示されない
**A**: 
- Service Worker が正しく登録されているか確認（ブラウザ開発ツール > Application > Service Workers）
- キャッシュをクリア（Ctrl+Shift+Delete）してリロード
- Godot エクスポートで `docs/` に `.pck` / `.wasm` ファイルが生成されているか確認

### Q: iPhone で「ホーム画面に追加」が表示されない
**A**:
- manifest.json が正しく読み込まれているか確認（ブラウザ開発ツール > Network タブで manifest.json を探す）
- iOS 16.4 以上が必要です

### Q: GitHub Pages の URL が違う
**A**: 
- リポジトリ名が `togun-puzzle` なら `https://USERNAME.github.io/togun-puzzle` です
- 同じユーザー名のサイトリポジトリ `USERNAME.github.io` なら `https://USERNAME.github.io` で公開できます（ただし要リポジトリ作成）

---

## キャッシュ戦略について

現在の `service-worker.js` は以下の戦略を使用：

1. **初回訪問**：ネットからダウンロード + キャッシュ保存
2. **2回目以降**：ネット接続があれば最新版をチェック、なければキャッシュ使用
3. **更新時**：新しい版をエクスポート＆プッシュ → 数分で自動更新

大きなファイル（`.wasm`, `.pck`）が多いため、初回ロード時は 30秒〜1分かかる場合があります。

---

## よくある質問

**Q: ゲームの変更を反映させたい**
```bash
# Godot で修正 → HTML5 エクスポート → git push
cd C:\Users\user\Desktop\togun_puzzle
git add docs/
git commit -m "Fix game bug / Add new feature"
git push origin main
```

**Q: バージョン管理はどうする？**
- `git tag` でバージョン打ちすることをお勧めします
- 例：`git tag v1.0 && git push origin v1.0`

**Q: リリース前に自分で確認したい**
- `docs/` をローカル Web サーバーで開く
  ```bash
  python -m http.server 8000 --directory docs
  # http://localhost:8000 で確認
  ```

---

## 参考リンク

- [Godot HTML5 Export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)
- [GitHub Pages](https://pages.github.com)
- [PWA (Progressive Web Apps)](https://developer.mozilla.org/docs/Web/Progressive_web_apps)
- [Service Workers](https://developer.mozilla.org/docs/Web/API/Service_Worker_API)
