extends Node

const LEVEL_TOTAL_XP: Array[int] = [0, 0, 100, 250, 500, 900, 1550, 2550, 4050, 6250, 9450]
const JOB_ORDER: Array[String] = ["helper", "warehouse", "sawmill", "logger", "driver"]
const OFFER_DURATION: float = 60.0

const JOBS: Dictionary = {
	"helper": {"name":"Pomocník ve dřevárně","desc":"Pomocné práce se dřevem.","pay_min":1,"pay_max":3,"xp_min":1,"xp_max":5,"level":1},
	"warehouse": {"name":"Skladník dřeva","desc":"Práce ve skladu a manipulace se dřevem.","pay_min":4,"pay_max":7,"xp_min":3,"xp_max":7,"level":1},
	"sawmill": {"name":"Obsluha pily","desc":"Řezání kulatiny a obsluha firemní pily.","pay_min":6,"pay_max":9,"xp_min":4,"xp_max":8,"level":2},
	"logger": {"name":"Dřevorubec","desc":"Kácení a zpracování dřeva v lese.","pay_min":8,"pay_max":12,"xp_min":5,"xp_max":9,"level":3},
	"driver": {"name":"Řidič","desc":"Rozvoz dřeva a práce s firemním vozidlem.","pay_min":10,"pay_max":14,"xp_min":6,"xp_max":10,"level":4}
}

var watched_button: Button = null
var watched_accept: Button = null
var reward_pending: bool = false
var offer_job_id: String = ""
var offer_time_left: float = OFFER_DURATION
var offer_timer_label: Label = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()

func _process(delta: float) -> void:
	var main := get_tree().current_scene
	if main == null:
		return

	var button = main.get("chop_button")
	if button is Button and button != watched_button:
		watched_button = button as Button
		if not watched_button.pressed.is_connected(_on_work_pressed):
			watched_button.pressed.connect(_on_work_pressed)

	_find_accept_button(main)
	_ensure_offer(main)
	offer_time_left -= delta
	if offer_time_left <= 0.0:
		_roll_offer(main)

	_refresh_work_ui(main)
	_refresh_xp_bar(main)

func _on_work_pressed() -> void:
	if reward_pending:
		return
	var main := get_tree().current_scene
	if main == null:
		return

	reward_pending = true
	var duration: float = float(main.call("axe_time"))
	_play_chop_animation(main, duration)
	await get_tree().create_timer(duration + 0.05).timeout

	main = get_tree().current_scene
	if main != null:
		var state_value = main.get("state")
		if state_value is Dictionary:
			var state: Dictionary = state_value
			var job_id: String = str(state.get("current_job", "helper"))
			if not JOBS.has(job_id):
				job_id = "helper"
			var job: Dictionary = JOBS[job_id]
			var pay: int = randi_range(int(job["pay_min"]), int(job["pay_max"]))
			var xp_gain: int = randi_range(int(job["xp_min"]), int(job["xp_max"]))
			state["money"] = float(state.get("money", 0.0)) + pay
			state["xp"] = int(state.get("xp", 0)) + xp_gain
			state["work_clicks"] = int(state.get("work_clicks", 0)) + 1
			state["level"] = level_from_xp(int(state["xp"]))
			main.set("state", state)
			main.call("update_hud")
			main.call("save_game")
			_refresh_xp_bar(main)
			_refresh_work_ui(main)
			_spawn_reward_feedback(main, pay, xp_gain)
	reward_pending = false

func _play_chop_animation(main: Node, duration: float) -> void:
	var player := _find_player_texture(main)
	if player == null:
		return

	var prefix: String = "player_wood_"
	var state_value = main.get("state")
	if state_value is Dictionary and str((state_value as Dictionary).get("equipped_axe", "wooden")) == "sharpened":
		prefix = "player_sharp_"

	var frames: Array[Texture2D] = []
	for i in range(1, 5):
		var path: String = "res://assets/characters/%s%d.png" % [prefix, i]
		if ResourceLoader.exists(path):
			var resource := ResourceLoader.load(path)
			if resource is Texture2D:
				frames.append(resource as Texture2D)

	if frames.size() < 2:
		return

	player.texture = frames[mini(1, frames.size() - 1)]
	await get_tree().create_timer(duration * 0.32).timeout
	if not is_instance_valid(player):
		return
	player.texture = frames[mini(2, frames.size() - 1)]
	await get_tree().create_timer(duration * 0.28).timeout
	if not is_instance_valid(player):
		return
	player.texture = frames[mini(3, frames.size() - 1)]
	await get_tree().create_timer(duration * 0.40).timeout
	if is_instance_valid(player):
		player.texture = frames[0]

func _find_player_texture(root: Node) -> TextureRect:
	for node in _all_nodes(root):
		if node is TextureRect:
			var texture_rect := node as TextureRect
			if texture_rect.texture != null:
				var path: String = texture_rect.texture.resource_path
				if path.contains("player_wood_") or path.contains("player_sharp_"):
					return texture_rect
	return null

func _spawn_reward_feedback(main: Node, pay: int, xp_gain: int) -> void:
	if not (main is Control):
		return
	var root := main as Control
	var viewport_size: Vector2 = root.get_viewport().get_visible_rect().size
	var base_pos := Vector2(viewport_size.x * 0.50, viewport_size.y * 0.37)

	_spawn_float_label(root, "+%d Kč" % pay, base_pos + Vector2(-70, 0), Color("#ffd24a"))
	_spawn_float_label(root, "+%d XP" % xp_gain, base_pos + Vector2(55, 0), Color("#9ddf52"))

	_pulse_label(main.get("money_label"))
	_pulse_label(main.get("xp_label"))

func _spawn_float_label(parent: Control, text_value: String, start_pos: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = text_value
	label.position = start_pos
	label.z_index = 100
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)

	var tween := parent.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", start_pos + Vector2(0, -75), 0.90).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.90).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

func _pulse_label(value) -> void:
	if not (value is Control):
		return
	var control := value as Control
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween()
	tween.tween_property(control, "scale", Vector2(1.10, 1.10), 0.10)
	tween.tween_property(control, "scale", Vector2.ONE, 0.16)

func level_from_xp(xp: int) -> int:
	var result: int = 1
	for level in range(2, 11):
		if xp >= LEVEL_TOTAL_XP[level]:
			result = level
	return result

func _ensure_offer(main: Node) -> void:
	if offer_job_id == "" or not JOBS.has(offer_job_id):
		_roll_offer(main)

func _roll_offer(main: Node) -> void:
	var state_value = main.get("state")
	if not (state_value is Dictionary):
		return
	var current_job: String = str((state_value as Dictionary).get("current_job", "helper"))
	var candidates: Array[String] = []
	for job_id in JOB_ORDER:
		if job_id != current_job:
			candidates.append(job_id)
	if candidates.is_empty():
		offer_job_id = ""
	else:
		offer_job_id = candidates[randi_range(0, candidates.size() - 1)]
	offer_time_left = OFFER_DURATION

func _find_accept_button(root: Node) -> void:
	for node in _all_nodes(root):
		if node is Button:
			var b := node as Button
			if b.text == "PŘIJMOUT PRÁCI" or b.text.begins_with("LVL ") or b.text == "NEJVYŠŠÍ POZICE":
				if b != watched_accept:
					watched_accept = b
					if not b.pressed.is_connected(_accept_offer):
						b.pressed.connect(_accept_offer)
				return

func _accept_offer() -> void:
	var main := get_tree().current_scene
	if main == null or offer_job_id == "" or not JOBS.has(offer_job_id):
		return
	var state_value = main.get("state")
	if not (state_value is Dictionary):
		return
	var state: Dictionary = state_value
	var level: int = level_from_xp(int(state.get("xp", 0)))
	var needed: int = int(JOBS[offer_job_id]["level"])
	if level < needed:
		return
	state["current_job"] = offer_job_id
	state["work_clicks"] = 0
	state["level"] = level
	main.set("state", state)
	main.call("update_hud")
	main.call("save_game")
	_roll_offer(main)
	_refresh_work_ui(main)

func _refresh_xp_bar(main: Node) -> void:
	var state_value = main.get("state")
	if not (state_value is Dictionary):
		return
	var state: Dictionary = state_value
	var total_xp: int = int(state.get("xp", 0))
	var level: int = level_from_xp(total_xp)
	state["level"] = level
	main.set("state", state)
	var xp_label_node = main.get("xp_label")
	if not (xp_label_node is Label):
		return
	var xp_label: Label = xp_label_node as Label
	var parent := xp_label.get_parent()
	var xp_bar: ProgressBar = null
	if parent != null:
		for child in parent.get_children():
			if child is ProgressBar:
				xp_bar = child as ProgressBar
				break

	if xp_bar != null:
		xp_bar.custom_minimum_size.y = 14
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color("#0f0d0b")
		bg.border_color = Color("#5b422c")
		bg.set_border_width_all(1)
		bg.set_corner_radius_all(6)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("#86ad28")
		fill.set_corner_radius_all(6)
		xp_bar.add_theme_stylebox_override("background", bg)
		xp_bar.add_theme_stylebox_override("fill", fill)

	if level >= 10:
		xp_label.text = "%d XP  •  LVL 10 MAX" % total_xp
		if xp_bar != null:
			xp_bar.min_value = 0.0
			xp_bar.max_value = 1.0
			xp_bar.value = 1.0
		return

	var current_floor: int = LEVEL_TOTAL_XP[level]
	var next_total: int = LEVEL_TOTAL_XP[level + 1]
	var gained_this_level: int = total_xp - current_floor
	var needed_this_level: int = next_total - current_floor
	xp_label.text = "%d / %d XP do LVL %d" % [gained_this_level, needed_this_level, level + 1]
	if xp_bar != null:
		xp_bar.min_value = 0.0
		xp_bar.max_value = float(needed_this_level)
		xp_bar.value = float(gained_this_level)

func _refresh_work_ui(main: Node) -> void:
	var state_value = main.get("state")
	if not (state_value is Dictionary):
		return
	var state: Dictionary = state_value
	var job_id: String = str(state.get("current_job", "helper"))
	if not JOBS.has(job_id):
		job_id = "helper"
	var job: Dictionary = JOBS[job_id]
	var level: int = level_from_xp(int(state.get("xp", 0)))
	state["level"] = level
	main.set("state", state)

	var role = main.get("role_label")
	if role is Label:
		(role as Label).text = "%s  •  LVL %d" % [str(job["name"]), level]

	var labels: Array[Label] = []
	for node in _all_nodes(main):
		if node is Label:
			labels.append(node as Label)

	var current_name_done := false
	var current_desc_done := false
	var current_pay_done := false
	var current_xp_done := false
	var shift_done := false
	for label in labels:
		if label.text in ["Pomocník ve dřevárně", "Skladník dřeva", "Obsluha pily", "Dřevorubec", "Řidič"] and not current_name_done:
			label.text = str(job["name"])
			current_name_done = true
		elif _is_job_desc(label.text) and not current_desc_done:
			label.text = str(job["desc"])
			current_desc_done = true
		elif label.text.begins_with("Mzda:") and not current_pay_done:
			label.text = "Mzda: %d–%d Kč / sek" % [int(job["pay_min"]), int(job["pay_max"])]
			current_pay_done = true
		elif label.text.begins_with("XP:") and not current_xp_done:
			label.text = "XP: %d–%d XP / sek" % [int(job["xp_min"]), int(job["xp_max"])]
			current_xp_done = true
		elif label.text.begins_with("Směna:") and not shift_done:
			label.text = "Směna: %d/8" % int(state.get("work_clicks", 0))
			shift_done = true

	if offer_job_id != "" and JOBS.has(offer_job_id):
		var offer: Dictionary = JOBS[offer_job_id]
		var offer_name_done := false
		var offer_desc_done := false
		var req_done := false
		var pay_seen := 0
		var xp_seen := 0
		for label in labels:
			if label.text in ["Pomocník ve dřevárně", "Skladník dřeva", "Obsluha pily", "Dřevorubec", "Řidič"] and not offer_name_done and label.text != str(job["name"]):
				label.text = str(offer["name"])
				offer_name_done = true
			elif _is_job_desc(label.text) and label.text != str(job["desc"]) and not offer_desc_done:
				label.text = str(offer["desc"])
				offer_desc_done = true
			elif label.text.begins_with("Požadovaný level:") and not req_done:
				label.text = "Požadovaný level: %d" % int(offer["level"])
				req_done = true
			elif label.text.begins_with("Mzda:"):
				pay_seen += 1
				if pay_seen >= 2:
					label.text = "Mzda: %d–%d Kč" % [int(offer["pay_min"]), int(offer["pay_max"])]
			elif label.text.begins_with("XP:"):
				xp_seen += 1
				if xp_seen >= 2:
					label.text = "XP: %d–%d XP" % [int(offer["xp_min"]), int(offer["xp_max"])]
		_update_offer_timer_label(main)
		if watched_accept != null:
			watched_accept.disabled = level < int(offer["level"])
			watched_accept.text = "PŘIJMOUT PRÁCI" if not watched_accept.disabled else "LVL %d POTŘEBA" % int(offer["level"])

func _update_offer_timer_label(main: Node) -> void:
	if offer_timer_label == null or not is_instance_valid(offer_timer_label):
		for node in _all_nodes(main):
			if node is Label and (node as Label).text == "NABÍDKA PRÁCE":
				var parent := node.get_parent()
				if parent != null:
					offer_timer_label = Label.new()
					offer_timer_label.add_theme_font_size_override("font_size", 14)
					offer_timer_label.add_theme_color_override("font_color", Color("#d6c4aa"))
					parent.add_child(offer_timer_label)
				break
	if offer_timer_label != null and is_instance_valid(offer_timer_label):
		offer_timer_label.text = "Nová nabídka za %d s" % maxi(0, int(ceil(offer_time_left)))

func _is_job_desc(text: String) -> bool:
	return text.begins_with("Pomocné práce") or text.begins_with("Práce ve skladu") or text.begins_with("Řezání kulatiny") or text.begins_with("Kácení a zpracování") or text.begins_with("Rozvoz dřeva")

func _all_nodes(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		result.append(current)
		for child in current.get_children():
			stack.append(child)
	return result
