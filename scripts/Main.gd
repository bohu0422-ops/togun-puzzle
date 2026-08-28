extends Node2D

# =====================================================
#  TOGUNパズル（テトリス風ブロックゲーム） たたき台
#  ・標準テトリス仕様：横10マス × 縦20マス
#  ・各ブロック片にT/O/G/U/Nいずれかの文字がランダムに1つ入る
#  ・横1列が埋まると消える（通常のテトリスと同じ）
#  ・消えた列の文字が左から "TOGUN" と連続で並んでいたらボーナス得点
# =====================================================

const COLS = 10
const ROWS = 20
const CELL_SIZE = 32
const BOARD_OFFSET_X = 40
const BOARD_OFFSET_Y = 40

const LETTERS = ["T", "O", "G", "U", "N"]
const TOGUN_SEQUENCE = "TOGUN"

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


func _ready():
	randomize()
	_init_board()
	_spawn_piece()


func _init_board():
	board.clear()
	for r in range(ROWS):
		var row = []
		for c in range(COLS):
			row.append(null)
		board.append(row)


func _spawn_piece():
	var keys = SHAPES.keys()
	var chosen_type = keys[randi() % keys.size()]
	current_piece = SHAPES[chosen_type].duplicate(true)

	current_letters = []
	for i in range(current_piece.size()):
		current_letters.append(LETTERS[randi() % LETTERS.size()])

	current_pos = Vector2i(3, 0)

	if _check_collision(current_piece, current_pos):
		game_over = true


func _process(delta):
	if game_over:
		queue_redraw()
		return

	drop_timer += delta
	if drop_timer >= drop_interval:
		drop_timer = 0.0
		_move_piece(Vector2i(0, 1))

	queue_redraw()


func _input(event):
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


func _restart():
	score = 0
	lines_cleared_total = 0
	drop_interval = 0.8
	game_over = false
	_init_board()
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
	for r in rows_to_clear:
		var letters_in_row = ""
		for c in range(COLS):
			letters_in_row += board[r][c]["letter"]
		if letters_in_row.find(TOGUN_SEQUENCE) != -1:
			score += 1000

	rows_to_clear.sort()
	for r in rows_to_clear:
		board.remove_at(r)
		var empty_row = []
		for c in range(COLS):
			empty_row.append(null)
		board.insert(0, empty_row)

	lines_cleared_total += rows_to_clear.size()
	# 10列消すごとに落下速度を少し上げる（最速0.15秒まで）
	drop_interval = max(0.15, 0.8 - float(lines_cleared_total / 10) * 0.1)


func _draw():
	draw_rect(Rect2(BOARD_OFFSET_X, BOARD_OFFSET_Y, COLS * CELL_SIZE, ROWS * CELL_SIZE), Color(1, 1, 1), false, 2.0)

	for r in range(ROWS):
		for c in range(COLS):
			if board[r][c] != null:
				_draw_cell(c, r, board[r][c]["letter"], Color(0.3, 0.5, 0.9))

	if not game_over:
		for i in range(current_piece.size()):
			var cell = current_piece[i]
			var bx = current_pos.x + cell.x
			var by = current_pos.y + cell.y
			if by >= 0:
				_draw_cell(bx, by, current_letters[i], Color(0.9, 0.6, 0.2))

	var info_x = BOARD_OFFSET_X + COLS * CELL_SIZE + 20
	draw_string(ThemeDB.fallback_font, Vector2(info_x, 60), "スコア: %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	draw_string(ThemeDB.fallback_font, Vector2(info_x, 90), "消去列数: %d" % lines_cleared_total, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	draw_string(ThemeDB.fallback_font, Vector2(info_x, 130), "操作方法", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	draw_string(ThemeDB.fallback_font, Vector2(info_x, 150), "←→ : 移動", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(ThemeDB.fallback_font, Vector2(info_x, 168), "↑  : 回転", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(ThemeDB.fallback_font, Vector2(info_x, 186), "↓  : ソフトドロップ", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(ThemeDB.fallback_font, Vector2(info_x, 204), "SPACE : ハードドロップ", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)

	if game_over:
		draw_string(ThemeDB.fallback_font, Vector2(BOARD_OFFSET_X + 10, BOARD_OFFSET_Y + ROWS * CELL_SIZE / 2), "GAME OVER", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.3, 0.3))
		draw_string(ThemeDB.fallback_font, Vector2(BOARD_OFFSET_X + 10, BOARD_OFFSET_Y + ROWS * CELL_SIZE / 2 + 30), "Rキーでリスタート", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1))


func _draw_cell(col: int, row: int, letter: String, color: Color):
	var x = BOARD_OFFSET_X + col * CELL_SIZE
	var y = BOARD_OFFSET_Y + row * CELL_SIZE
	draw_rect(Rect2(x, y, CELL_SIZE - 2, CELL_SIZE - 2), color)
	draw_string(ThemeDB.fallback_font, Vector2(x + 8, y + 22), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1))
