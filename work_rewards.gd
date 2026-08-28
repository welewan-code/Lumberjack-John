extends Node

const LEVEL_XP: Array[int] = [0,100,250,450,700,1000,1400,1900,2500,3200,4000]
const JOB_ORDER: Array[String] = ["helper", "warehouse", "sawmill", "logger", "driver"]
const JOBS: Dictionary = {
	"helper": {
		"name": "Pomocník ve dřevárně",
		"desc": "Pomocné práce se dřevem.",
		"pay_min": 1, "pay_max": 3,
		"xp_min": 1, "xp_max": 5,
		"level": 0
	},
	"warehouse": {
		"name": "Skladník dřeva",
		"desc": "Práce ve skladu a manipulace se dřevem.",
		"pay_min": 4, "pay_max": 7,
		"xp_min": 3, "xp_max": 7,
		"level": 1
	},
	"sawmill": {
		"name": "Obsluha pily",
		"desc": "Řezání kulatiny a obsluha firemní pily.",
		"pay_min": 6, "pay_max": 9,
		"xp_min": 4, "xp_max": 8,
		"level": 2
	},
	"logger": {
		"name": "Dřevorubec",
		"desc": "Kácení a zpracování dřeva v lese.",
		"pay_min": 8, "pay_max": 12,
		"xp_min": 5, "xp_max": 9,
		"level": 3
	},
	"driver": {
		"name": "Řidič",
		"desc": "Rozvoz dřeva a práce s firemním vozidlem.",
		"pay_min": 10, "pay_max": 14,
		"xp_min": 6, "xp_max": 10,
		"level": 4
	}
}

var watched_button: Button = null
var watched_accept: Button = null
var reward_pending: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()

func _process(_delta: float) -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	var button = main.get("chop_button")
	if button is Button and button != watched_button:
		watched_button = button as Button
		if not watched_button.pressed.is_connected(_on_work_pressed):
			watched_button.pressed.connect(_on_work_pressed)
	_find_accept_button(main)
	_refresh_work_ui(main)

func _on_work_pressed() -> void:
	if reward_pending:
		return
	var main := get_tree().current_scene
	if main == null or bool(main.get("action_running")):
		return
	reward_pending = true
	var duration: float = float(main.call("axe_time"))
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
	reward_pending = false

func level_from_xp(xp: int) -> int:
	var result: int = 0
	for i in range(1, LEVEL_XP.size()):
		if xp >= LEVEL_XP[i]:
			result = i
	return mini(result, 10)

func _next_job_id(current_job: String) -> String:
	var index: int = JOB_ORDER.find(current_job)
	if index < 0:
		return "warehouse"
	if index >= JOB_ORDER.size() - 1:
		return ""
	return JOB_ORDER[index + 1]

func _find_accept_button(root: Node) -> void:
	for node in _all_nodes(root):
		if node is Button and (node as Button).text == "PŘIJMOUT PRÁCI":
			var b := node as Button
			if b != watched_accept:
				watched_accept = b
				if not b.pressed.is_connected(_accept_next_job):
					b.pressed.connect(_accept_next_job)
			return

func _accept_next_job() -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	var state_value = main.get("state")
	if not (state_value is Dictionary):
		return
	var state: Dictionary = state_value
	var current_id: String = str(state.get("current_job", "helper"))
	var next_id: String = _next_job_id(current_id)
	if next_id == "" or not JOBS.has(next_id):
		return
	var needed: int = int(JOBS[next_id]["level"])
	var level: int = level_from_xp(int(state.get("xp", 0)))
	state["level"] = level
	if level < needed:
		return
	state["current_job"] = next_id
	state["work_clicks"] = 0
	main.set("state", state)
	main.call("update_hud")
	main.call("save_game")
	_refresh_work_ui(main)

func _refresh_work_ui(main: Node) -> void:
	var state_value = main.get("state")
	if not (state_value is Dictionary):
		return
	var state: Dictionary = state_value
	var job_id: String = str(state.get("current_job", "helper"))
	if not JOBS.has(job_id):
		job_id = "helper"
	var job: Dictionary = JOBS[job_id]
	var next_id: String = _next_job_id(job_id)
	var level: int = level_from_xp(int(state.get("xp", 0)))
	state["level"] = level
	main.set("state", state)

	# Horní role.
	var role = main.get("role_label")
	if role is Label:
		(role as Label).text = str(job["name"])

	var labels: Array[Label] = []
	for node in _all_nodes(main):
		if node is Label:
			labels.append(node as Label)

	# Pravý panel aktuální práce — přepisujeme známé texty bez zásahu do layoutu.
	var found_current_name := false
	var found_current_desc := false
	var found_pay := false
	var found_xp := false
	var found_shift := false
	for label in labels:
		if label.text in ["Pomocník ve dřevárně", "Skladník dřeva", "Obsluha pily", "Dřevorubec", "Řidič"] and not found_current_name:
			label.text = str(job["name"])
			found_current_name = true
		elif label.text.begins_with("Pomocné práce") or label.text.begins_with("Práce ve skladu") or label.text.begins_with("Řezání kulatiny") or label.text.begins_with("Kácení a zpracování") or label.text.begins_with("Rozvoz dřeva"):
			if not found_current_desc:
				label.text = str(job["desc"])
				found_current_desc = true
		elif label.text.begins_with("Mzda:") and not found_pay:
			label.text = "Mzda: %d–%d Kč / sek" % [int(job["pay_min"]), int(job["pay_max"])]
			found_pay = true
		elif label.text.begins_with("XP:") and not found_xp:
			label.text = "XP: %d–%d XP / sek" % [int(job["xp_min"]), int(job["xp_max"])]
			found_xp = true
		elif label.text.begins_with("Směna:") and not found_shift:
			label.text = "Směna: %d/8" % int(state.get("work_clicks", 0))
			found_shift = true

	# Nabídka další práce.
	if next_id != "" and JOBS.has(next_id):
		var next_job: Dictionary = JOBS[next_id]
		var offer_name_done := false
		var offer_desc_done := false
		var req_done := false
		var pay_count := 0
		var xp_count := 0
		for label in labels:
			if label.text in ["Skladník dřeva", "Obsluha pily", "Dřevorubec", "Řidič"] and not offer_name_done and label.text != str(job["name"]):
				label.text = str(next_job["name"])
				offer_name_done = true
			elif label.text.begins_with("Práce ve skladu") or label.text.begins_with("Řezání kulatiny") or label.text.begins_with("Kácení a zpracování") or label.text.begins_with("Rozvoz dřeva"):
				if found_current_desc and not offer_desc_done and label.text != str(job["desc"]):
					label.text = str(next_job["desc"])
					offer_desc_done = true
			elif label.text.begins_with("Požadovaný level:") and not req_done:
				label.text = "Požadovaný level: %d" % int(next_job["level"])
				req_done = true
			elif label.text.begins_with("Mzda:"):
				pay_count += 1
				if pay_count >= 2:
					label.text = "Mzda: %d–%d Kč" % [int(next_job["pay_min"]), int(next_job["pay_max"])]
			elif label.text.begins_with("XP:"):
				xp_count += 1
				if xp_count >= 2:
					label.text = "XP: %d–%d XP" % [int(next_job["xp_min"]), int(next_job["xp_max"])]
		if watched_accept != null:
			watched_accept.disabled = level < int(next_job["level"])
			watched_accept.text = "PŘIJMOUT PRÁCI" if not watched_accept.disabled else "LVL %d POTŘEBA" % int(next_job["level"])
	else:
		if watched_accept != null:
			watched_accept.disabled = true
			watched_accept.text = "NEJVYŠŠÍ POZICE"

func _all_nodes(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		result.append(current)
		for child in current.get_children():
			stack.append(child)
	return result
