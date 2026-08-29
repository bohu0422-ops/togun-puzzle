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
# タップボタンの並び順の保存先
const BUTTON_ORDER_PATH = "user://buttonorder.save"

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

# 回転時の壁蹴りオフセット（この順に試し、置ける位置が見つかったら採用する）
const WALL_KICK_OFFSETS = [
	Vector2i(0, 0),
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(-2, 0),
	Vector2i(2, 0),
	Vector2i(0, -1),
]

# =====================================================
#  効果音（音声ファイルを使わず、コードで波形を生成する）
#  BGM本体は実際のオーケストラ録音（assets/audio/）を使用
# =====================================================
const AUDIO_MIX_RATE = 22050
const C4_FREQ = 261.63
const MAJOR_SCALE_SEMITONES = [0, 2, 4, 5, 7, 9, 11]  # 1=ド 2=レ 3=ミ 4=ファ 5=ソ 6=ラ 7=シ

const SFX_POOL_SIZE = 3

# BGM音量（タイトル画面は控えめ、ゲーム開始で少し上げる。同じ曲を鳴らし続けるので継ぎ目なし）
const TITLE_BGM_VOLUME_DB = -16.0
const GAMEPLAY_BGM_VOLUME_DB = -4.0

var board = []            # board[行][列] = {"letter": "T"} または null（空マス）
var current_piece = []    # 現在落下中のブロックの各マス座標（相対位置）
var current_letters = []  # 各マスに割り当てられた文字
var current_pos = Vector2i(3, 0)

var score = 0
var lines_cleared_total = 0
var drop_timer = 0.0
var drop_interval = 0.8
var game_over = false

var title_active = true  # タイトル画面を表示中かどうか

var high_score = 0             # 端末に保存された最高得点
var high_score_updated = false # 今回のプレイで記録を更新したか

var bonus_active = false  # TOGUNボーナス演出中かどうか
var bonus_timer = 0.0

var paused = false  # 一時停止中かどうか

var next_piece_cells = []  # 次に出てくるブロックの形（プレビュー表示用）
var next_letters = []      # 次に出てくるブロックの文字

var button_order = [0, 1, 2, 3, 4]  # TOUCH_BUTTON_DEFSの並び順（インデックス）
var rearrange_mode = false          # ボタンの並び替えモード中かどうか
var rearrange_selected = -1         # 並び替え中に選択済みのボタン位置（-1で未選択）

var touch_buttons = []    # [{"rect": Rect2, "action": String, "label": String}, ...]
var pause_button_rect = Rect2()
var rearrange_button_rect = Rect2()
var rearrange_reset_rect = Rect2()
var truck_texture = preload("res://assets/togun_truck.jpg")
var game_font = preload("res://assets/fonts/NotoSansJP.ttf")  # 日本語表示用（Godot内蔵フォントには日本語が無いため）

var bgm_player: AudioStreamPlayer
var sfx_pool = []
var sfx_pool_index = 0
var sfx_landing
var sfx_line_clear
var sfx_bonus
var sfx_gameover


func _ready():
	randomize()
	_load_high_score()
	_load_button_order()
	_init_board()
	_roll_next_piece()
	_spawn_piece()
	_setup_touch_buttons()
	_setup_audio()


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


func _load_button_order():
	if not FileAccess.file_exists(BUTTON_ORDER_PATH):
		return
	var f = FileAccess.open(BUTTON_ORDER_PATH, FileAccess.READ)
	if f == null:
		return
	var line = f.get_line()
	f.close()
	var parts = line.split(",")
	if parts.size() != TOUCH_BUTTON_DEFS.size():
		return
	var order = []
	for p in parts:
		if not p.is_valid_int():
			return
		order.append(int(p))
	order.sort()
	for i in range(order.size()):
		if order[i] != i:
			return  # 0..4が過不足なく揃っていない場合は不正なデータとして無視
	var parsed = []
	for p in parts:
		parsed.append(int(p))
	button_order = parsed


func _save_button_order():
	var f = FileAccess.open(BUTTON_ORDER_PATH, FileAccess.WRITE)
	if f == null:
		return
	var strs = []
	for i in button_order:
		strs.append(str(i))
	f.store_line(",".join(strs))
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
	for idx in button_order:
		var d = TOUCH_BUTTON_DEFS[idx]
		var rect = Rect2(x, TOUCH_BTN_Y, btn_w, TOUCH_BTN_H)
		touch_buttons.append({"rect": rect, "action": d["action"], "label": d["label"], "def_index": idx})
		x += btn_w + TOUCH_BTN_GAP

	var info_x = BOARD_OFFSET_X + COLS * CELL_SIZE + 20
	pause_button_rect = Rect2(viewport_w - 40, HEADER_STRIPE_H + 6, 28, 28)
	rearrange_button_rect = Rect2(info_x, BOARD_OFFSET_Y + 400, 100, 26)
	rearrange_reset_rect = Rect2(info_x, BOARD_OFFSET_Y + 432, 100, 26)


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
		if bgm_player != null:
			bgm_player.stop()
		_play_sfx(sfx_gameover)
		if score > high_score:
			high_score = score
			high_score_updated = true
			_save_high_score()


func _process(delta):
	if title_active:
		queue_redraw()
		return

	if game_over:
		queue_redraw()
		return

	if paused:
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
	if title_active:
		if (event is InputEventScreenTouch and event.pressed) or (event is InputEventKey and event.pressed):
			title_active = false
			if bgm_player != null:
				bgm_player.volume_db = GAMEPLAY_BGM_VOLUME_DB
		return

	if event is InputEventScreenTouch and event.pressed:
		_handle_touch(event.position)
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_P and not bonus_active and not game_over:
			_toggle_pause()
			return
		if paused or bonus_active:
			return
		if game_over:
			if event.keycode == KEY_R:
				_restart()
			return
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


func _toggle_pause():
	paused = not paused
	if bgm_player != null:
		bgm_player.stream_paused = paused


func _handle_touch(pos: Vector2):
	if game_over:
		_restart()
		return

	if not bonus_active and pause_button_rect.has_point(pos):
		_toggle_pause()
		return

	if paused or bonus_active:
		return

	if rearrange_button_rect.has_point(pos):
		rearrange_mode = not rearrange_mode
		rearrange_selected = -1
		return

	if rearrange_mode and rearrange_reset_rect.has_point(pos):
		button_order = [0, 1, 2, 3, 4]
		_save_button_order()
		_setup_touch_buttons()
		rearrange_selected = -1
		return

	for i in range(touch_buttons.size()):
		var btn = touch_buttons[i]
		if btn["rect"].has_point(pos):
			if rearrange_mode:
				_handle_rearrange_tap(i)
			else:
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


func _handle_rearrange_tap(index: int):
	if rearrange_selected == -1:
		rearrange_selected = index
	elif rearrange_selected == index:
		rearrange_selected = -1
	else:
		var tmp = button_order[rearrange_selected]
		button_order[rearrange_selected] = button_order[index]
		button_order[index] = tmp
		_save_button_order()
		_setup_touch_buttons()
		rearrange_selected = -1


func _restart():
	score = 0
	lines_cleared_total = 0
	drop_interval = 0.8
	game_over = false
	bonus_active = false
	bonus_timer = 0.0
	paused = false
	high_score_updated = false
	_init_board()
	_roll_next_piece()
	_spawn_piece()
	if bgm_player != null:
		bgm_player.stream_paused = false
		bgm_player.play()


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
	# 4x4の枠内での90度回転＋壁蹴り。
	# そのままの位置で置けなければ、左右にずらした位置でも試す
	# （盤面の端でブロックが回転できなくなるのを防ぐ）
	var rotated = []
	for cell in current_piece:
		rotated.append(Vector2i(3 - cell.y, cell.x))

	for offset in WALL_KICK_OFFSETS:
		var new_pos = current_pos + offset
		if not _check_collision(rotated, new_pos):
			current_piece = rotated
			current_pos = new_pos
			return


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

	_play_sfx(sfx_landing)
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
		_play_sfx(sfx_bonus)
		return

	_play_sfx(sfx_line_clear)

	rows_to_clear.sort()
	for r in rows_to_clear:
		board.remove_at(r)
		var empty_row = []
		for c in range(COLS):
			empty_row.append(null)
		board.insert(0, empty_row)

	# 10列消すごとに落下速度を少し上げる（最速0.15秒まで）
	drop_interval = max(0.15, 0.8 - float(lines_cleared_total / 10) * 0.1)


# ---- ここから効果音・BGM ----

func _setup_audio():
	bgm_player = AudioStreamPlayer.new()
	add_child(bgm_player)
	# 実際のオーケストラ録音（YouTubeオーディオライブラリ、帰属表示不要）を使用。
	# タイトル画面では静かに、ゲーム開始で音量を上げる（同じ曲を鳴らし続けるので継ぎ目なし）
	var real_bgm = load("res://assets/audio/carmen_toreadors.mp3")
	real_bgm.loop = true
	bgm_player.stream = real_bgm
	bgm_player.volume_db = TITLE_BGM_VOLUME_DB
	bgm_player.play()

	for i in range(SFX_POOL_SIZE):
		var p = AudioStreamPlayer.new()
		add_child(p)
		sfx_pool.append(p)

	sfx_landing = _generate_landing_sfx()
	sfx_line_clear = _generate_line_clear_sfx()
	sfx_bonus = _generate_bonus_sfx()
	sfx_gameover = _generate_gameover_sfx()


func _play_sfx(stream):
	if stream == null or sfx_pool.is_empty():
		return
	var player = sfx_pool[sfx_pool_index]
	sfx_pool_index = (sfx_pool_index + 1) % sfx_pool.size()
	player.stream = stream
	player.play()


func _semitone_freq(base_freq: float, semitones: float) -> float:
	return base_freq * pow(2.0, semitones / 12.0)


func _degree_freq(degree: int, octave_shift: int) -> float:
	# degree: 1〜6（ド〜ラ）。オクターブ違いは octave_shift（+1で1オクターブ上）
	var semis = MAJOR_SCALE_SEMITONES[degree - 1] + octave_shift * 12
	return _semitone_freq(C4_FREQ, semis)


func _mix_tone(buf: PackedFloat32Array, start_sample: int, freq: float, duration_sec: float, volume: float, waveform: String, duty: float = 0.5):
	var n = int(duration_sec * AUDIO_MIX_RATE)
	var fade = min(0.006 * AUDIO_MIX_RATE, n / 4.0)
	for i in range(n):
		var idx = start_sample + i
		if idx < 0 or idx >= buf.size():
			continue
		var t = float(i) / AUDIO_MIX_RATE
		var phase = fmod(t * freq, 1.0)
		var raw = 0.0
		if waveform == "square":
			raw = 1.0 if phase < duty else -1.0
		else:  # "triangle"
			raw = 4.0 * abs(phase - 0.5) - 1.0
		var env = 1.0
		if fade > 0.0:
			if i < fade:
				env = i / fade
			elif i > n - fade:
				env = (n - i) / fade
		buf[idx] += raw * volume * env


func _scale_degree_freq(degree_from_1: int, octave_shift: int) -> float:
	# 1以上の任意の度数を受け取り、6音スケールを折り返しながら周波数を返す
	# （例：度数8 → 1オクターブ上の度数2）。ハモリ音の計算に使う
	var size = MAJOR_SCALE_SEMITONES.size()
	var idx = (degree_from_1 - 1) % size
	var extra_octaves = int((degree_from_1 - 1) / float(size))
	return _degree_freq(idx + 1, octave_shift + extra_octaves)


func _float_buffer_to_pcm16(buf: PackedFloat32Array) -> PackedByteArray:
	var bytes = PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in range(buf.size()):
		var v = clamp(buf[i], -1.0, 1.0)
		var s = int(v * 32767.0)
		bytes[i * 2] = s & 0xFF
		bytes[i * 2 + 1] = (s >> 8) & 0xFF
	return bytes


func _make_wav(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = AUDIO_MIX_RATE
	stream.stereo = false
	stream.data = _float_buffer_to_pcm16(buf)
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = buf.size()
	return stream


func _generate_landing_sfx() -> AudioStreamWAV:
	# ブロック着地音：短く低めの「ポン」
	var notes = [{"freq": 440.0, "dur": 0.05}, {"freq": 300.0, "dur": 0.06}]
	return _build_note_sequence(notes, "square", 0.22)


func _generate_line_clear_sfx() -> AudioStreamWAV:
	# 列消去音：明るく駆け上がる「ピロン」
	var degrees = [3, 5, 6, 8]
	var notes = []
	for d in degrees:
		notes.append({"freq": _scale_degree_freq(d, 1), "dur": 0.06})
	return _build_note_sequence(notes, "square", 0.24)


func _generate_bonus_sfx() -> AudioStreamWAV:
	# TOGUNボーナス音：華やかに駆け上がって和音で締める
	var run_degrees = [1, 3, 5, 8, 10]
	var notes = []
	for d in run_degrees:
		notes.append({"freq": _scale_degree_freq(d, 1), "dur": 0.07})

	var total_time = 0.0
	for n in notes:
		total_time += n["dur"]
	total_time += 0.35

	var buf = PackedFloat32Array()
	buf.resize(int(total_time * AUDIO_MIX_RATE) + AUDIO_MIX_RATE)

	var cursor = 0
	for n in notes:
		_mix_tone(buf, cursor, n["freq"], n["dur"], 0.26, "square")
		cursor += int(n["dur"] * AUDIO_MIX_RATE)

	# 締めの和音（オクターブ違いの2音を同時に鳴らす）
	_mix_tone(buf, cursor, _degree_freq(1, 2), 0.35, 0.24, "square")
	_mix_tone(buf, cursor, _degree_freq(3, 2), 0.35, 0.20, "triangle")
	cursor += int(0.35 * AUDIO_MIX_RATE)

	buf.resize(max(cursor, 1))
	return _make_wav(buf, false)


func _generate_gameover_sfx() -> AudioStreamWAV:
	# ゲームオーバー音：下降する4音
	var notes = [
		{"freq": _degree_freq(5, 1), "dur": 0.14},
		{"freq": _degree_freq(3, 1), "dur": 0.14},
		{"freq": _degree_freq(1, 1), "dur": 0.14},
		{"freq": _degree_freq(5, 0), "dur": 0.22},
	]
	return _build_note_sequence(notes, "triangle", 0.26)


func _build_note_sequence(notes: Array, waveform: String, volume: float) -> AudioStreamWAV:
	var total_time = 0.0
	for n in notes:
		total_time += n["dur"]
	total_time += 0.1

	var buf = PackedFloat32Array()
	buf.resize(int(total_time * AUDIO_MIX_RATE) + AUDIO_MIX_RATE)

	var cursor = 0
	for n in notes:
		_mix_tone(buf, cursor, n["freq"], n["dur"], volume, waveform)
		cursor += int(n["dur"] * AUDIO_MIX_RATE)

	buf.resize(max(cursor, 1))
	return _make_wav(buf, false)


func _draw():
	draw_rect(Rect2(0, 0, get_viewport_rect().size.x, get_viewport_rect().size.y), BG_COLOR, true)

	if title_active:
		_draw_title_screen()
		return

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

	_draw_pause_button()

	if paused:
		_draw_pause_overlay()
		return

	_draw_rearrange_controls()
	_draw_touch_buttons()


func _draw_pause_button():
	var r = pause_button_rect
	draw_rect(r, BTN_BG, true)
	draw_rect(r, BTN_BORDER, false, 1.5)
	var label = ">" if paused else "||"
	var fs = 14
	var ts = game_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(game_font, Vector2(r.position.x + (r.size.x - ts.x) / 2.0, r.position.y + r.size.y / 2.0 + ts.y / 3.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, DARK_TEXT)


func _draw_pause_overlay():
	var viewport_w = get_viewport_rect().size.x
	var viewport_h = get_viewport_rect().size.y
	draw_rect(Rect2(0, 0, viewport_w, viewport_h), Color(1, 1, 1, 0.75), true)

	var title = "一時停止中"
	var ts = game_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28)
	draw_string(game_font, Vector2((viewport_w - ts.x) / 2.0, viewport_h / 2.0 - 10), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, DARK_TEXT)

	var hint = "右上のボタンをタップして再開"
	var hs = game_font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	draw_string(game_font, Vector2((viewport_w - hs.x) / 2.0, viewport_h / 2.0 + 22), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.4, 0.44, 0.5))


func _draw_rearrange_controls():
	var r = rearrange_button_rect
	draw_rect(r, LETTER_COLORS["T"] if rearrange_mode else BTN_BG, true)
	draw_rect(r, BTN_BORDER, false, 1.5)
	var label = "並び替え中" if rearrange_mode else "並び替え"
	var fs = 12
	var ts = game_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var color = Color(1, 1, 1) if rearrange_mode else DARK_TEXT
	draw_string(game_font, Vector2(r.position.x + (r.size.x - ts.x) / 2.0, r.position.y + r.size.y / 2.0 + ts.y / 3.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

	if rearrange_mode:
		var rr = rearrange_reset_rect
		draw_rect(rr, BTN_BG, true)
		draw_rect(rr, BTN_BORDER, false, 1.5)
		var rlabel = "元に戻す"
		var rts = game_font.get_string_size(rlabel, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(game_font, Vector2(rr.position.x + (rr.size.x - rts.x) / 2.0, rr.position.y + rr.size.y / 2.0 + rts.y / 3.0), rlabel, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, DARK_TEXT)


func _draw_stripe_band(y0: float):
	var viewport_w = get_viewport_rect().size.x
	var n = STRIPE_COLORS.size()
	var band_w = viewport_w / float(n)
	for i in range(n):
		var x0 = i * band_w
		var pts = PackedVector2Array([
			Vector2(x0 + HEADER_SLANT, y0),
			Vector2(x0 + band_w + HEADER_SLANT, y0),
			Vector2(x0 + band_w - HEADER_SLANT, y0 + HEADER_STRIPE_H),
			Vector2(x0 - HEADER_SLANT, y0 + HEADER_STRIPE_H),
		])
		draw_colored_polygon(pts, STRIPE_COLORS[i])


func _draw_header():
	_draw_stripe_band(0)
	draw_string(game_font, Vector2(16, HEADER_STRIPE_H + 24), "TOGUN Puzzle", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, DARK_TEXT)


func _draw_title_tile(x: float, y: float, size: float, letter: String):
	draw_rect(Rect2(x, y, size, size), LETTER_COLORS[letter], true)
	var font_size = int(size * 0.5)
	var ts = game_font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(game_font, Vector2(x + (size - ts.x) / 2.0, y + size / 2.0 + ts.y / 3.0), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1))


func _draw_title_screen():
	var viewport_w = get_viewport_rect().size.x
	var viewport_h = get_viewport_rect().size.y

	_draw_stripe_band(0)

	# ロゴ：TO / GUN の2段タイル
	var s = 48.0
	var gap = 8.0
	var y1 = 70.0
	var x1 = (viewport_w - (2 * s + gap)) / 2.0
	for i in range(2):
		_draw_title_tile(x1 + i * (s + gap), y1, s, "TO"[i])
	var y2 = y1 + s + gap
	var x2 = (viewport_w - (3 * s + 2 * gap)) / 2.0
	for i in range(3):
		_draw_title_tile(x2 + i * (s + gap), y2, s, "GUN"[i])
	var logo_bottom = y2 + s

	var puzzle_text = "Puzzle"
	var pts = game_font.get_string_size(puzzle_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
	draw_string(game_font, Vector2((viewport_w - pts.x) / 2.0, logo_bottom + 40), puzzle_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, DARK_TEXT)

	# トラックのイラスト
	var truck_w = 250.0
	var truck_h = truck_w * float(truck_texture.get_height()) / float(truck_texture.get_width())
	var truck_x = (viewport_w - truck_w) / 2.0
	var truck_y = logo_bottom + 56.0
	draw_texture_rect(truck_texture, Rect2(truck_x, truck_y, truck_w, truck_h), false)

	# あそびかたカード
	var card_y = truck_y + truck_h + 14.0
	var card_h = 150.0
	var card_rect = Rect2(30, card_y, viewport_w - 60, card_h)
	draw_rect(card_rect, Color(0.965, 0.973, 0.984), true)
	draw_rect(card_rect, Color(0.847, 0.871, 0.902), false, 2.0)
	draw_string(game_font, Vector2(50, card_y + 26), "あそびかた", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, DARK_TEXT)
	var rule_lines = [
		"・横1列そろえると消えて得点",
		"・消えた列が TOGUN の並びなら",
		"　特大ボーナス＋全消し！",
		"・下のボタンで操作します",
	]
	for i in range(rule_lines.size()):
		draw_string(game_font, Vector2(50, card_y + 50 + i * 26), rule_lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.27, 0.31, 0.37))

	var start_text = "タップしてスタート"
	var sts = game_font.get_string_size(start_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	draw_string(game_font, Vector2((viewport_w - sts.x) / 2.0, card_y + card_h + 38), start_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, DARK_TEXT)

	var hs_text = "ハイスコア  %d" % high_score
	var hts = game_font.get_string_size(hs_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(game_font, Vector2((viewport_w - hts.x) / 2.0, card_y + card_h + 64), hs_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.53, 0.58))

	_draw_stripe_band(viewport_h - HEADER_STRIPE_H)


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
	for i in range(touch_buttons.size()):
		var btn = touch_buttons[i]
		var rect = btn["rect"]
		var is_selected = rearrange_mode and rearrange_selected == i
		draw_rect(rect, LETTER_COLORS["T"] if is_selected else BTN_BG, true)
		draw_rect(rect, LETTER_COLORS["N"] if rearrange_mode else BTN_BORDER, false, 1.5 if not rearrange_mode else 2.5)
		var label = btn["label"]
		var font_size = 15
		var text_size = game_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var tx = rect.position.x + (rect.size.x - text_size.x) / 2.0
		var ty = rect.position.y + rect.size.y / 2.0 + text_size.y / 4.0
		var text_color = Color(1, 1, 1) if is_selected else DARK_TEXT
		draw_string(game_font, Vector2(tx, ty), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)


func _draw_cell(col: int, row: int, letter: String, color: Color):
	var x = BOARD_OFFSET_X + col * CELL_SIZE
	var y = BOARD_OFFSET_Y + row * CELL_SIZE
	draw_rect(Rect2(x, y, CELL_SIZE - 2, CELL_SIZE - 2), color)
	draw_string(game_font, Vector2(x + 8, y + 22), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1))
