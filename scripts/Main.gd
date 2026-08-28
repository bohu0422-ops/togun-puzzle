extends Node2D

# =====================================================
#  TOGUNパズル（テトリス風ブロックゲーム）
#  ・標準テトリス仕様：横10マス × 縦20マス
#  ・各ブロック片にT/O/G/U/Nいずれかの文字がランダムに1つ入る
#  ・横1列が埋まると消える（通常のテトリスと同じ）
#  ・消えた列の文字が左から "TOGUN" と連続で並んでいたら
#    特大ボーナス得点＋盤面全消し＋演出画像を表示
# =====================================================

const COLS = 10
const ROWS = 20
const CELL_SIZE = 32
const BOARD_OFFSET_X = 40
const BOARD_OFFSET_Y = 60

# 画面上部の斜めストライプ帯
const HEADER_STRIPE_H = 24
const HEADER_SLANT = 14
const STRIPE_COLORS = [
	Color(0.576, 0.745, 0.341),
	Color(0.314, 0.639, 0.784),
	Color(0.588, 0.800, 0.863),
	Color(0.776, 0.773, 0.871),
]

# 配色（背景は白ベース、文字ごとに色分け）
const BG_COLOR = Color(1, 1, 1)
const DARK_TEXT = Color(0.118, 0.157, 0.216)
const GRID_LINE = Color(0.871, 0.886, 0.910)
const BOARD_BORDER = Color(0.235, 0.275, 0.353)
const BTN_BG = Color(0.922, 0.941, 0.965)
const BTN_BORDER = Color(0.745, 0.784, 0.831)

const LETTER_COLORS = {
	"T": Color(0.298, 0.490, 0.941),
	"O": Color(0.910, 0.569, 0.227),
	"G": Color(0.247, 0.749, 0.498),
	"U": Color(0.753, 0.361, 0.878),
	"N": Color(0.878, 0.333, 0.373),
}

# スマホ用タップボタンのレイアウト（盤面の下に横並びで配置）
const TOUCH_BTN_Y = BOARD_OFFSET_Y + ROWS * CELL_SIZE + 8
const TOUCH_BTN_H = 44
const TOUCH_BTN_MARGIN = 10
const TOUCH_BTN_GAP = 6
const TOUCH_BUTTON_DEFS = [
	{"label": "左", "action": "left"},
	{"label": "右", "action": "right"},
	{"label": "回転", "action": "rotate"},
	{"label": "下", "action": "soft_drop"},
	{"label": "落下", "action": "hard_drop"},
]

const LETTERS = ["T", "O", "G", "U", "N"]
const TOGUN_SEQUENCE = "TOGUN"

# TOGUNボーナス関連
const TOGUN_BONUS_SCORE = 3000
const BONUS_DISPLAY_SECONDS = 3.0

# ハイスコアの保存先（Web版ではブラウザの保存領域に記録される）
const HIGH_SCORE_PATH = "user://highscore.save"

# 7種類のブロック形状（回転前の基準形）
const SHAPES = {
	"I": [Vector2i(0,1), Vector2i(1,1), Vector2i(2,1), Vector2i(3,1)],
	"O": [Vector2i(1,0), Vector2i(2,0), Vector2i(1,1), Vector2i(2,1)],
	"T": [Vector2i(1,0), Vector2i(0,1), Vector2i(1,1), Vector2i(2,1)],
	"S": [Vector2i(1,0), Vector2i(2,0), Vector2i(0,1), Vector2i(1,1)],
	"Z": [Vector2i(0,0), Vector2i(1,0), Vector2i(1,1), Vector2i(2,1)],
	"J": [Vector2i(0,0), Vector2i(0,1), Vector2i(1,1), Vector2i(2,1)],
	"L": [Vector2i(2,0), Vector2i(0,1), Vector2i(1,1), Vector2i(2,1)],
}

var board = []            # board[行][列] = {"letter": "T"} または null（空マス）
var current_piece = []    # 現在落下中のブロックの各マス座標（相対位置）
var current_letters = []  # 各マスに割り当てられた文字
var current_pos = Vector2i(3, 0)

var score = 0
var lines_cleared_total = 0
var drop_timer = 0.0
var drop_interval = 0.8
var game_over = false

var high_score = 0             # 端末に保存された最高得点
var high_score_updated = false # 今回のプレイで記録を更新したか

var bonus_active = false  # TOGUNボーナス演出中かどうか
var bonus_timer = 0.0

var next_piece_cells = []  # 次に出てくるブロックの形（プレビュー表示用）
var next_letters = []      # 次に出てくるブロックの文字

var touch_buttons = []    # [{"rect": Rect2, "action": String, "label": String}, ...]
var truck_texture = preload("res://assets/togun_truck.jpg")
var game_font = preload("res://assets/fonts/NotoSansJP.ttf")  # 日本語表示用（Godot内蔵フォントには日本語が無いため）


func _ready():
	randomize()
	_load_high_score()
	_init_board()
	_roll_next_piece()
	_spawn_piece()
	_setup_touch_buttons()


func _load_high_score():
	# user:// はWeb版ではブラウザの保存領域（IndexedDB）に対応する
	if not FileAccess.file_exists(HIGH_SCORE_PATH):
		high_score = 0
		return
	var f = FileAccess.open(HIGH_SCORE_PATH, FileAccess.READ)
	if f == null:
		high_score = 0
		return
	high_score = int(f.get_line())
	f.close()


func _save_high_score():
	var f = FileAccess.open(HIGH_SCORE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_line(str(high_score))
	f.close()


func _roll_next_piece():
	var keys = SHAPES.keys()
	var chosen_type = keys[randi() % keys.size()]
	next_piece_cells = SHAPES[chosen_type].duplicate(true)

	next_letters = []
	for i in range(next_piece_cells.size()):
		next_letters.append(LETTERS[randi() % LETTERS.size()])


func _setup_touch_buttons():
	touch_buttons.clear()
	var count = TOUCH_BUTTON_DEFS.size()
	var viewport_w = get_viewport_rect().size.x
	var total_w = viewport_w - TOUCH_BTN_MARGIN * 2 - TOUCH_BTN_GAP * (count - 1)
	var btn_w = total_w / count
	var x = TOUCH_BTN_MARGIN
	for d in TOUCH_BUTTON_DEFS:
		var rect = Rect2(x, TOUCH_BTN_Y, btn_w, TOUCH_BTN_H)
		touch_buttons.append({"rect": rect, "action": d["action"], "label": d["label"]})
		x += btn_w + TOUCH_BTN_GAP


func _init_board():
	board.clear()
	for r in range(ROWS):
		var row = []
		for c in range(COLS):
			row.append(null)
		board.append(row)


func _spawn_piece():
	current_piece = next_piece_cells.duplicate(true)
	current_letters = next_letters.duplicate()
	_roll_next_piece()

	current_pos = Vector2i(3, 0)

	if _check_collision(current_piece, current_pos):
		game_over = true
		if score > high_score:
			high_score = score
			high_score_updated = true
			_save_high_score()


func _process(delta):
	if game_over:
		queue_redraw()
		return

	if bonus_active:
		bonus_timer -= delta
		if bonus_timer <= 0.0:
			bonus_active = false
			_spawn_piece()
		queue_redraw()
		return

	drop_timer += delta
	if drop_timer >= drop_interval:
		drop_timer = 0.0
		_move_piece(Vector2i(0, 1))

	queue_redraw()


func _input(event):
	if bonus_active:
		return

	if event is InputEventScreenTouch and event.pressed:
		_handle_touch(event.position)
		return

	if game_over:
		if event is InputEventKey and event.pressed and event.keycode == KEY_R:
			_restart()
		return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT:
				_move_piece(Vector2i(-1, 0))
			KEY_RIGHT:
				_move_piece(Vector2i(1, 0))
			KEY_DOWN:
				_move_piece(Vector2i(0, 1))
			KEY_UP:
				_rotate_piece()
			KEY_SPACE:
				_hard_drop()


func _handle_touch(pos: Vector2):
	if game_over:
		_restart()
		return

	for btn in touch_buttons:
		if btn["rect"].has_point(pos):
			match btn["action"]:
				"left":
					_move_piece(Vector2i(-1, 0))
				"right":
					_move_piece(Vector2i(1, 0))
				"rotate":
					_rotate_piece()
				"soft_drop":
					_move_piece(Vector2i(0, 1))
				"hard_drop":
					_hard_drop()
			return


func _restart():
	score = 0
	lines_cleared_total = 0
	drop_interval = 0.8
	game_over = false
	bonus_active = false
	bonus_timer = 0.0
	high_score_updated = false
	_init_board()
	_roll_next_piece()
	_spawn_piece()


func _move_piece(delta: Vector2i) -> bool:
	var new_pos = current_pos + delta
	if not _check_collision(current_piece, new_pos):
		current_pos = new_pos
		return true
	else:
		if delta.y == 1:
			_lock_piece()
		return false


func _hard_drop():
	while _move_piece(Vector2i(0, 1)):
		pass


func _rotate_piece():
	# 4x4の枠内での簡易90度回転（プロトタイプ用のシンプル実装）
	var rotated = []
	for cell in current_piece:
		rotated.append(Vector2i(3 - cell.y, cell.x))
	if not _check_collision(rotated, current_pos):
		current_piece = rotated


func _check_collision(piece, pos: Vector2i) -> bool:
	for cell in piece:
		var bx = pos.x + cell.x
		var by = pos.y + cell.y
		if bx < 0 or bx >= COLS or by >= ROWS:
			return true
		if by >= 0 and board[by][bx] != null:
			return true
	return false


func _lock_piece():
	for i in range(current_piece.size()):
		var cell = current_piece[i]
		var bx = current_pos.x + cell.x
		var by = current_pos.y + cell.y
		if by >= 0 and by < ROWS and bx >= 0 and bx < COLS:
			board[by][bx] = {"letter": current_letters[i]}

	_check_lines()
	if not bonus_active:
		_spawn_piece()


func _check_lines():
	var rows_to_clear = []
	for r in range(ROWS):
		var full = true
		for c in range(COLS):
			if board[r][c] == null:
				full = false
				break
		if full:
			rows_to_clear.append(r)

	if rows_to_clear.size() == 0:
		return

	# 通常の列消去得点（同時消しほど得点が跳ね上がる、標準テトリス風）
	var base_points = [0, 100, 300, 500, 800]
	var n = min(rows_to_clear.size(), 4)
	score += base_points[n]

	# TOGUNボーナス判定：消える行の文字を左から並べて "TOGUN" が含まれるか
	var togun_triggered = false
	for r in rows_to_clear:
		var letters_in_row = ""
		for c in range(COLS):
			letters_in_row += board[r][c]["letter"]
		if letters_in_row.find(TOGUN_SEQUENCE) != -1:
			togun_triggered = true
			break

	lines_cleared_total += rows_to_clear.size()

	if togun_triggered:
		# 特大ボーナス：加点した上で盤面を丸ごと消し、演出を表示する
		score += TOGUN_BONUS_SCORE
		_init_board()
		bonus_active = true
		bonus_timer = BONUS_DISPLAY_SECONDS
		return

	rows_to_clear.sort()
	for r in rows_to_clear:
		board.remove_at(r)
		var empty_row = []
		for c in range(COLS):
			empty_row.append(null)
		board.insert(0, empty_row)

	# 10列消すごとに落下速度を少し上げる（最速0.15秒まで）
	drop_interval = max(0.15, 0.8 - float(lines_cleared_total / 10) * 0.1)


func _draw():
	draw_rect(Rect2(0, 0, get_viewport_rect().size.x, get_viewport_rect().size.y), BG_COLOR, true)
	_draw_header()

	if bonus_active:
		_draw_bonus_overlay()
		return

	# 盤面の枠とマス目
	draw_rect(Rect2(BOARD_OFFSET_X, BOARD_OFFSET_Y, COLS * CELL_SIZE, ROWS * CELL_SIZE), BOARD_BORDER, false, 2.0)
	for r in range(ROWS):
		for c in range(COLS):
			var x0 = BOARD_OFFSET_X + c * CELL_SIZE
			var y0 = BOARD_OFFSET_Y + r * CELL_SIZE
			draw_rect(Rect2(x0, y0, CELL_SIZE, CELL_SIZE), GRID_LINE, false, 1.0)
			if board[r][c] != null:
				var letter = board[r][c]["letter"]
				_draw_cell(c, r, letter, LETTER_COLORS[letter])

	if not game_over:
		for i in range(current_piece.size()):
			var cell = current_piece[i]
			var bx = current_pos.x + cell.x
			var by = current_pos.y + cell.y
			if by >= 0:
				var letter = current_letters[i]
				_draw_cell(bx, by, letter, LETTER_COLORS[letter])

	var info_x = BOARD_OFFSET_X + COLS * CELL_SIZE + 20
	draw_string(game_font, Vector2(info_x, BOARD_OFFSET_Y + 22), "スコア", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, DARK_TEXT)
	draw_string(game_font, Vector2(info_x, BOARD_OFFSET_Y + 46), "%d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, DARK_TEXT)
	draw_string(game_font, Vector2(info_x, BOARD_OFFSET_Y + 78), "ハイスコア", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, DARK_TEXT)
	draw_string(game_font, Vector2(info_x, BOARD_OFFSET_Y + 102), "%d" % high_score, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, DARK_TEXT)
	draw_string(game_font, Vector2(info_x, BOARD_OFFSET_Y + 134), "消去列数", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, DARK_TEXT)
	draw_string(game_font, Vector2(info_x, BOARD_OFFSET_Y + 158), "%d" % lines_cleared_total, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, DARK_TEXT)

	_draw_next_piece(info_x, BOARD_OFFSET_Y + 196)

	# キーボード操作の説明（情報欄の幅に収まるよう短く表記）
	draw_string(game_font, Vector2(info_x, BOARD_OFFSET_Y + 298), "キー操作", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, DARK_TEXT)
	draw_string(game_font, Vector2(info_x, BOARD_OFFSET_Y + 320), "←→ 移動", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DARK_TEXT)
	draw_string(game_font, Vector2(info_x, BOARD_OFFSET_Y + 340), "↑ 回転", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DARK_TEXT)
	draw_string(game_font, Vector2(info_x, BOARD_OFFSET_Y + 360), "↓ 下へ", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DARK_TEXT)
	draw_string(game_font, Vector2(info_x, BOARD_OFFSET_Y + 380), "空白 落下", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DARK_TEXT)

	if game_over:
		var go_y = BOARD_OFFSET_Y + ROWS * CELL_SIZE / 2
		draw_string(game_font, Vector2(BOARD_OFFSET_X + 10, go_y), "GAME OVER", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.85, 0.2, 0.25))
		if high_score_updated:
			draw_string(game_font, Vector2(BOARD_OFFSET_X + 10, go_y + 30), "ハイスコア更新！", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, LETTER_COLORS["G"])
			draw_string(game_font, Vector2(BOARD_OFFSET_X + 10, go_y + 58), "Rキーか画面タップで再開", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, DARK_TEXT)
		else:
			draw_string(game_font, Vector2(BOARD_OFFSET_X + 10, go_y + 30), "Rキーか画面タップで再開", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, DARK_TEXT)

	_draw_touch_buttons()


func _draw_header():
	var viewport_w = get_viewport_rect().size.x
	var n = STRIPE_COLORS.size()
	var band_w = viewport_w / float(n)
	for i in range(n):
		var x0 = i * band_w
		var pts = PackedVector2Array([
			Vector2(x0 + HEADER_SLANT, 0),
			Vector2(x0 + band_w + HEADER_SLANT, 0),
			Vector2(x0 + band_w - HEADER_SLANT, HEADER_STRIPE_H),
			Vector2(x0 - HEADER_SLANT, HEADER_STRIPE_H),
		])
		draw_colored_polygon(pts, STRIPE_COLORS[i])
	draw_string(game_font, Vector2(16, HEADER_STRIPE_H + 24), "TOGUN Puzzle", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, DARK_TEXT)


func _draw_bonus_overlay():
	var viewport_w = get_viewport_rect().size.x

	var msg = "TOGUN BONUS!"
	var font_size = 30
	var text_size = game_font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(game_font, Vector2((viewport_w - text_size.x) / 2.0, 110), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, LETTER_COLORS["N"])

	var sub = "+%d点 ボード全消し！" % TOGUN_BONUS_SCORE
	var sub_size = game_font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	draw_string(game_font, Vector2((viewport_w - sub_size.x) / 2.0, 150), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, DARK_TEXT)

	var tex_w = 360.0
	var tex_h = tex_w * float(truck_texture.get_height()) / float(truck_texture.get_width())
	var tx = (viewport_w - tex_w) / 2.0
	var ty = 200.0
	draw_texture_rect(truck_texture, Rect2(tx, ty, tex_w, tex_h), false)

	var foot = "まもなく再開します…"
	var foot_size = game_font.get_string_size(foot, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(game_font, Vector2((viewport_w - foot_size.x) / 2.0, ty + tex_h + 34), foot, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.53, 0.58))


func _draw_next_piece(info_x: float, top_y: float):
	draw_string(game_font, Vector2(info_x, top_y), "つぎのブロック", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DARK_TEXT)

	var cell = 18
	var grid_y = top_y + 24
	for i in range(next_piece_cells.size()):
		var c = next_piece_cells[i]
		var letter = next_letters[i]
		var x = info_x + c.x * cell
		var y = grid_y + c.y * cell
		draw_rect(Rect2(x, y, cell - 2, cell - 2), LETTER_COLORS[letter])
		draw_string(game_font, Vector2(x + 3, y + cell - 5), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1))


func _draw_touch_buttons():
	for btn in touch_buttons:
		var rect = btn["rect"]
		draw_rect(rect, BTN_BG, true)
		draw_rect(rect, BTN_BORDER, false, 1.5)
		var label = btn["label"]
		var font_size = 15
		var text_size = game_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var tx = rect.position.x + (rect.size.x - text_size.x) / 2.0
		var ty = rect.position.y + rect.size.y / 2.0 + text_size.y / 4.0
		draw_string(game_font, Vector2(tx, ty), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, DARK_TEXT)


func _draw_cell(col: int, row: int, letter: String, color: Color):
	var x = BOARD_OFFSET_X + col * CELL_SIZE
	var y = BOARD_OFFSET_Y + row * CELL_SIZE
	draw_rect(Rect2(x, y, CELL_SIZE - 2, CELL_SIZE - 2), color)
	draw_string(game_font, Vector2(x + 8, y + 22), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1))
