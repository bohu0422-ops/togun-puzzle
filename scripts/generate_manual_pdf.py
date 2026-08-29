# -*- coding: utf-8 -*-
"""
TOGUN Puzzle 仕様書 兼 取扱説明書 のPDFを生成する。

使い方:
    python scripts/generate_manual_pdf.py
"""
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib import colors
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    HRFlowable, PageBreak, Image, KeepTogether
)
from reportlab.pdfbase.cidfonts import UnicodeCIDFont
from reportlab.pdfbase import pdfmetrics
import os

FONT = "HeiseiKakuGo-W5"
pdfmetrics.registerFont(UnicodeCIDFont(FONT))

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON_PATH = os.path.join(ROOT, "web", "icon_512.png")
OUT_PATH = os.path.join(ROOT, "TOGUNパズル_仕様書兼取扱説明書.pdf")

NAVY = colors.HexColor("#1e2837")
BLUE = colors.HexColor("#4c7df0")
GREEN = colors.HexColor("#3fbf7f")
GRAY = colors.HexColor("#666666")
LIGHTBG = colors.HexColor("#f6f8fb")
BORDER = colors.HexColor("#d8dee6")

styles = {
    "title": ParagraphStyle("title", fontName=FONT, fontSize=22, leading=28,
                             textColor=NAVY, alignment=TA_CENTER, spaceAfter=4),
    "subtitle": ParagraphStyle("subtitle", fontName=FONT, fontSize=11, leading=16,
                                textColor=GRAY, alignment=TA_CENTER, spaceAfter=14),
    "h1": ParagraphStyle("h1", fontName=FONT, fontSize=15, leading=20,
                          textColor=colors.white, backColor=NAVY,
                          leftIndent=8, spaceBefore=4, spaceAfter=10,
                          borderPadding=(6, 6, 6, 6)),
    "h2": ParagraphStyle("h2", fontName=FONT, fontSize=12, leading=17,
                          textColor=NAVY, spaceBefore=10, spaceAfter=6),
    "body": ParagraphStyle("body", fontName=FONT, fontSize=10, leading=16,
                            textColor=colors.HexColor("#222222"), spaceAfter=6),
    "note": ParagraphStyle("note", fontName=FONT, fontSize=9, leading=14,
                            textColor=GRAY, spaceAfter=6),
    "cell": ParagraphStyle("cell", fontName=FONT, fontSize=9.5, leading=14,
                            textColor=colors.HexColor("#222222")),
    "cellHead": ParagraphStyle("cellHead", fontName=FONT, fontSize=9.5, leading=14,
                                textColor=colors.white),
}


def h1(text):
    return Paragraph(text, styles["h1"])


def h2(text):
    return Paragraph(text, styles["h2"])


def body(text):
    return Paragraph(text, styles["body"])


def note(text):
    return Paragraph(text, styles["note"])


def make_table(header, rows, col_widths, header_bg=BLUE):
    data = [[Paragraph(h, styles["cellHead"]) for h in header]]
    for r in rows:
        data.append([Paragraph(str(c), styles["cell"]) for c in r])
    t = Table(data, colWidths=col_widths, repeatRows=1)
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), header_bg),
        ("BACKGROUND", (0, 1), (-1, -1), colors.white),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, LIGHTBG]),
        ("GRID", (0, 0), (-1, -1), 0.5, BORDER),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
    ]))
    return t


story = []

# ===== 表紙 =====
if os.path.exists(ICON_PATH):
    story.append(Spacer(1, 30))
    story.append(Image(ICON_PATH, width=32 * mm, height=32 * mm, hAlign="CENTER"))
    story.append(Spacer(1, 10))
story.append(Paragraph("TOGUNパズル", styles["title"]))
story.append(Paragraph("仕様書 兼 取扱説明書", styles["subtitle"]))
story.append(HRFlowable(width="100%", thickness=1, color=BORDER, spaceAfter=16))

story.append(h2("概要"))
story.append(body(
    "TOGUNパズルは、標準的なテトリスと同じ落ち物パズルに、T・O・G・U・N の文字を組み合わせた"
    "独自ルールを加えたブロックゲームです。横1列を埋めて消すだけでなく、消える列の文字を左から"
    "読んだときに「TOGUN」と並んでいると特大ボーナスが発生します。"
))
story.append(body(
    "Webブラウザで動作し、iPhoneのSafariから「ホーム画面に追加」することで、オフラインでも"
    "アプリのように遊べます。"
))

info_rows = [
    ["公開URL", "https://bohu0422-ops.github.io/togun-puzzle/"],
    ["リポジトリ", "https://github.com/bohu0422-ops/togun-puzzle"],
    ["開発環境", "Godot Engine 4.7（HTML5 / Webエクスポート）"],
    ["対応環境", "PCブラウザ（マウス・キーボード）／スマートフォン（タップ）"],
]
story.append(Spacer(1, 6))
story.append(make_table(["項目", "内容"], info_rows, [35 * mm, 120 * mm]))

story.append(PageBreak())

# ===== 1. 基本仕様 =====
story.append(h1("1. 基本仕様"))

spec_rows = [
    ["盤面サイズ", "横10マス × 縦20マス（標準テトリス仕様）"],
    ["ブロック形状", "7種類（I・O・T・S・Z・J・L の標準テトリミノ）"],
    ["マスの文字", "各マスに T・O・G・U・N のいずれかがランダムに1つ割り当てられる"],
    ["文字の色分け", "T=青／O=オレンジ／G=緑／U=紫／N=赤（アイコンと共通の配色）"],
    ["落下速度", "初期0.8秒／マス。列を消すごとに加速し、最速0.15秒／マスまで上昇"],
    ["回転方式", "90度回転。盤面の端では自動的に位置をずらす「壁蹴り」に対応"],
]
story.append(make_table(["項目", "内容"], spec_rows, [35 * mm, 120 * mm]))

story.append(h2("得点表（通常の列消去）"))
score_rows = [
    ["1列", "100点"],
    ["2列同時", "300点"],
    ["3列同時", "500点"],
    ["4列同時", "800点"],
]
story.append(make_table(["同時に消えた列数", "得点"], score_rows, [50 * mm, 50 * mm]))

story.append(h2("TOGUNボーナス（独自ルール）"))
story.append(body(
    "横1列が完全に埋まって消える際、その列の文字を左から読んだ文字列の中に「TOGUN」という"
    "並びが含まれていた場合、以下が同時に発生します。"
))
bonus_rows = [
    ["追加得点", "+3,000点（通常の列消去得点に加算）"],
    ["盤面の変化", "盤面が丸ごと全消しになる"],
    ["演出", "「TOGUN BONUS!」の表示とトラックのイラストが3秒間表示される"],
    ["演出中の操作", "操作不可。3秒後に自動的にゲームを再開"],
]
story.append(make_table(["内容", "詳細"], bonus_rows, [35 * mm, 120 * mm]))
story.append(note(
    "※ 縦方向に文字を並べても消去・ボーナスの対象にはなりません（本作は横一列の消去のみに対応）。"
))

story.append(h2("ハイスコア"))
story.append(body(
    "ゲームオーバー時のスコアが保存済みの記録を上回った場合、端末（ブラウザの保存領域）に"
    "自動で記録されます。記録を更新した場合はゲームオーバー画面に「ハイスコア更新！」と表示されます。"
))

story.append(PageBreak())

# ===== 2. 操作方法 =====
story.append(h1("2. 操作方法"))

story.append(h2("キーボード操作（PC）"))
key_rows = [
    ["← →", "左右に移動"],
    ["↑", "回転（壁際では自動で位置調整）"],
    ["↓", "1マス下へ移動（ソフトドロップ）"],
    ["SPACE（空白）", "一気に下まで落とす（ハードドロップ）"],
    ["P", "一時停止／再開"],
    ["R", "ゲームオーバー画面での再スタート"],
    ["T", "ゲームオーバー画面でタイトル画面に戻る"],
]
story.append(make_table(["キー", "動作"], key_rows, [45 * mm, 110 * mm]))

story.append(h2("タップ操作（スマートフォン）／マウス操作（PC）"))
story.append(body(
    "画面下部に5つの操作ボタン（左・右・回転・下・落下）が表示されます。PC版でも"
    "マウスクリックで同じボタンを操作できます。"
))
touch_rows = [
    ["左／右", "1マスずつ左右へ移動"],
    ["回転", "ブロックを90度回転"],
    ["下", "1マス下へ移動（ソフトドロップ）"],
    ["落下", "一気に下まで落とす（ハードドロップ）"],
]
story.append(make_table(["ボタン", "動作"], touch_rows, [30 * mm, 125 * mm]))

story.append(h2("一時停止"))
story.append(body(
    "画面右上の「| |」ボタンをタップ（またはPキー）すると一時停止します。画面全体が白く"
    "覆われて「一時停止中」と表示され、BGMも停止します。もう一度同じボタンで再開します。"
))

story.append(h2("ゲームオーバー画面の操作"))
story.append(body(
    "ゲームオーバー時は画面中央に「もう一度」「タイトルへ」の2つのボタンが表示されます。"
    "「もう一度」（Rキー）はそのままゲームを再スタート、「タイトルへ」（Tキー）はスコア・"
    "盤面をリセットしてタイトル画面に戻ります。タイトル画面は初回起動時だけでなく、"
    "ゲームオーバーになるたびに何度でも表示できます。"
))

story.append(h2("操作ボタンの並び替え"))
story.append(body(
    "情報欄の「並び替え」ボタンをタップすると並び替えモードになります。入れ替えたい2つの"
    "ボタンを順にタップすると位置が入れ替わります。「元に戻す」で初期の並び順"
    "（左・右・回転・下・落下）に戻せます。設定した並び順は端末に保存され、次回起動時も"
    "引き継がれます。"
))

story.append(PageBreak())

# ===== 3. 画面の流れ =====
story.append(h1("3. 画面の流れ"))

flow_rows = [
    ["① タイトル画面", "ロゴ・トラックのイラスト・あそびかたの説明・ハイスコアを表示。画面タップ"
                        "またはキー入力でゲーム開始"],
    ["② ゲーム画面", "盤面、次のブロックのプレビュー、スコア・ハイスコア・消去列数、操作ボタンを表示"],
    ["③ 一時停止画面", "「一時停止中」を表示。再開ボタンで②へ戻る"],
    ["④ ボーナス演出", "TOGUNボーナス発生時に3秒間表示。自動的に②へ戻る"],
    ["⑤ ゲームオーバー画面", "「GAME OVER」を表示。ハイスコア更新時は専用メッセージも表示。"
                              "「もう一度」ボタン（Rキー）で②から再スタート、「タイトルへ」ボタン"
                              "（Tキー）で①のタイトル画面に戻る。タイトル画面は接続後何度でも"
                              "表示できる"],
]
story.append(make_table(["画面", "内容"], flow_rows, [35 * mm, 120 * mm]))

story.append(PageBreak())

# ===== 4. BGM・効果音 =====
story.append(h1("4. BGM・効果音"))

story.append(h2("BGM"))
bgm_rows = [
    ["曲名", "歌劇「カルメン」第1幕への前奏曲（闘牛士）"],
    ["作曲", "ジョルジュ・ビゼー（1875年没・パブリックドメイン）"],
    ["入手元", "YouTube オーディオ ライブラリ（帰属表示不要ライセンス）"],
    ["再生の流れ", "タイトル画面では控えめな音量、ゲーム開始で音量が上がる（同じ曲がそのまま"
                    "続くため曲の切れ目はなし）"],
]
story.append(make_table(["項目", "内容"], bgm_rows, [35 * mm, 120 * mm]))

story.append(h2("効果音"))
story.append(body(
    "以下の効果音は音声ファイルを使わず、すべてプログラムで波形を生成しています。"
))
sfx_rows = [
    ["ブロック着地音", "ブロックが盤面に固定されるたびに再生"],
    ["列消去音", "通常の列消去時に再生"],
    ["TOGUNボーナス音", "TOGUNボーナス発生時に再生"],
    ["ゲームオーバー音", "ゲームオーバー時に再生（同時にBGMは停止）"],
]
story.append(make_table(["効果音", "再生タイミング"], sfx_rows, [40 * mm, 115 * mm]))

story.append(PageBreak())

# ===== 5. ホーム画面への追加（iPhone） =====
story.append(h1("5. iPhoneでの使い方（ホーム画面に追加）"))
story.append(body(
    "本作はPWA（Progressive Web App）に対応しており、ホーム画面に追加することで"
    "アプリのように起動でき、オフラインでも遊べます。"
))
install_rows = [
    ["①", "iPhoneのSafariで公開URLを開く（https://bohu0422-ops.github.io/togun-puzzle/）"],
    ["②", "画面下の共有ボタン（四角に上矢印のマーク）をタップ"],
    ["③", "「ホーム画面に追加」を選択"],
    ["④", "「追加」をタップすると、ホーム画面にTOGUNパズルのアイコンが追加される"],
    ["⑤", "追加後は一度起動しておけば、以降オフラインでも起動・プレイが可能"],
]
story.append(make_table(["手順", "内容"], install_rows, [15 * mm, 140 * mm]))

story.append(Spacer(1, 20))
story.append(HRFlowable(width="100%", thickness=0.5, color=BORDER, spaceAfter=8))
story.append(note("本書はTOGUNパズルの実装内容に基づいて作成しています。"))

doc = SimpleDocTemplate(
    OUT_PATH, pagesize=A4,
    topMargin=20 * mm, bottomMargin=18 * mm,
    leftMargin=20 * mm, rightMargin=20 * mm,
    title="TOGUNパズル 仕様書兼取扱説明書",
)
doc.build(story)
print(f"生成完了: {OUT_PATH}")
