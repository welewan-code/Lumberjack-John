extends Node

const OFFLINE_PATH: String = "user://drevo_tycoon_offline.json"
const HEARTBEAT_SECONDS: float = 5.0

const SPLITTER_WAGE: float = 2.0
const SAWYER_WAGE: float = 5.0
const SAW_IN_M3: float = 0.025
const SAW_OUT_M3: float = 0.033
const CHOP_IN_M3: float = 0.010
const CHOP_OUT_M3: float = 0.015
const STORAGE_CAPACITY: float = 10.0
const SPLITTER_TIME_WOODEN: float = 1.8
const SPLITTER_TIME_SHARPENED: float = 1.6
const SPLITTER_TIME_CHECHT: float = 1.5
const SAWYER_TIME_FRAME: float = 20.0
const SAWYER_TIME_AKU: float = 14.0
const SLOT_COUNT: int = 3
const SENTINEL: float = 1.0e30

const CYCLE_SUCCESS: int = 0
const CYCLE_NO_MONEY: int = 1
const CYCLE_NO_INPUT: int = 2
const CYCLE_STORAGE_FULL: int = 3
const CYCLE_INVALID: int = 4

var heartbeat: float = 0.0

func _ready() -> void:
	call_deferred("_apply_offline_progress")

func _process(delta: float) -> void:
	heartbeat += delta
	if heartbeat >= HEARTBEAT_SECONDS:
		heartbeat = 0.0
		_write_last_seen()

func _exit_tree() -> void:
	_write_last_seen()

func _apply_offline_progress() -> void:
	var game: Node = get_parent()
	if game == null:
		return

	var now: int = int(Time.get_unix_time_from_system())
	var last_seen: int = _read_last_seen()
	if last_seen <= 0:
		_write_last_seen()
		return

	var elapsed: int = maxi(0, now - last_seen)
	if elapsed < 2:
		_write_last_seen()
		return

	var company: Node = get_node_or_null("/root/CompanyUI")
	if company != null and company.has_method("validate_work_slots"):
		company.call("validate_work_slots", game, true)

	var state_value: Variant = game.get("state")
	if not (state_value is Dictionary):
		_write_last_seen()
		return
	var state: Dictionary = state_value as Dictionary
	var slots: Array = _work_slots(state)

	var tools: Array[String] = ["", "", ""]
	var cycles: Array[float] = [0.0, 0.0, 0.0]
	var next_events: Array[float] = [SENTINEL, SENTINEL, SENTINEL]
	var has_active_worker: bool = false

	for slot_index in range(SLOT_COUNT):
		var slot: Dictionary = slots[slot_index] as Dictionary
		if str(slot.get("mode", "player")) != "employee" or not bool(slot.get("active", false)):
			continue
		var tool_id: String = str(slot.get("tool", ""))
		var cycle_time: float = _tool_cycle_time(tool_id)
		if cycle_time <= 0.0:
			continue
		tools[slot_index] = tool_id
		cycles[slot_index] = cycle_time
		next_events[slot_index] = cycle_time
		has_active_worker = true

	if not has_active_worker:
		_write_last_seen()
		return

	var changed: bool = false
	var safety: int = 0
	while safety < 200000:
		safety += 1
		var slot_index: int = _next_event_slot(next_events)
		if slot_index < 0:
			break
		var event_time: float = next_events[slot_index]
		if event_time > float(elapsed):
			break

		var tool_id: String = tools[slot_index]
		var result: int = _try_tool_cycle(state, tool_id)
		next_events[slot_index] += cycles[slot_index]

		if result == CYCLE_SUCCESS:
			changed = true
		elif result == CYCLE_STORAGE_FULL:
			# Sklad se offline nemůže uvolnit, ale menší čistý přírůstek jiného nástroje se ještě může vejít.
			next_events[slot_index] = SENTINEL
		elif result == CYCLE_NO_MONEY or result == CYCLE_INVALID:
			next_events[slot_index] = SENTINEL
		elif result == CYCLE_NO_INPUT:
			if _tool_role(tool_id) == "sawyer":
				next_events[slot_index] = SENTINEL
			elif not _has_future_saw_event(next_events, tools, float(elapsed)):
				next_events[slot_index] = SENTINEL

		if _next_event_slot(next_events) < 0:
			break

	if changed:
		game.set("state", state)
		if game.has_method("save_game"):
			game.call("save_game")
		if game.has_method("update_hud"):
			game.call("update_hud")
		if game.has_method("show_tab"):
			game.call("show_tab", str(game.get("current_tab")))

	_write_last_seen()

func _next_event_slot(next_events: Array[float]) -> int:
	var best_index: int = -1
	var best_time: float = SENTINEL
	for slot_index in range(SLOT_COUNT):
		var event_time: float = next_events[slot_index]
		if event_time < best_time:
			best_time = event_time
			best_index = slot_index
	if best_time >= SENTINEL:
		return -1
	return best_index

func _has_future_saw_event(next_events: Array[float], tools: Array[String], elapsed: float) -> bool:
	for slot_index in range(SLOT_COUNT):
		if _tool_role(tools[slot_index]) == "sawyer" and next_events[slot_index] <= elapsed:
			return true
	return false

func _try_tool_cycle(state: Dictionary, tool_id: String) -> int:
	var role: String = _tool_role(tool_id)
	if role == "sawyer":
		return _try_saw_cycle(state)
	if role == "splitter":
		return _try_split_cycle(state)
	return CYCLE_INVALID

func _try_saw_cycle(state: Dictionary) -> int:
	if float(state.get("money", 0.0)) < SAWYER_WAGE:
		return CYCLE_NO_MONEY
	if float(state.get("logs_m3", 0.0)) + 0.0001 < SAW_IN_M3:
		return CYCLE_NO_INPUT
	var net_growth: float = SAW_OUT_M3 - SAW_IN_M3
	if _storage_used(state) + net_growth > STORAGE_CAPACITY + 0.0001:
		return CYCLE_STORAGE_FULL
	state["money"] = float(state.get("money", 0.0)) - SAWYER_WAGE
	state["logs_m3"] = maxf(0.0, float(state.get("logs_m3", 0.0)) - SAW_IN_M3)
	state["roundwood_m3"] = float(state.get("roundwood_m3", 0.0)) + SAW_OUT_M3
	return CYCLE_SUCCESS

func _try_split_cycle(state: Dictionary) -> int:
	if float(state.get("money", 0.0)) < SPLITTER_WAGE:
		return CYCLE_NO_MONEY
	if float(state.get("roundwood_m3", 0.0)) + 0.0001 < CHOP_IN_M3:
		return CYCLE_NO_INPUT
	var net_growth: float = CHOP_OUT_M3 - CHOP_IN_M3
	if _storage_used(state) + net_growth > STORAGE_CAPACITY + 0.0001:
		return CYCLE_STORAGE_FULL
	state["money"] = float(state.get("money", 0.0)) - SPLITTER_WAGE
	state["roundwood_m3"] = maxf(0.0, float(state.get("roundwood_m3", 0.0)) - CHOP_IN_M3)
	state["split_m3"] = float(state.get("split_m3", 0.0)) + CHOP_OUT_M3
	return CYCLE_SUCCESS

func _work_slots(state: Dictionary) -> Array:
	var result: Array = []
	var raw_value: Variant = state.get("work_slots", [])
	var raw: Array = []
	if raw_value is Array:
		raw = raw_value as Array
	for slot_index in range(SLOT_COUNT):
		var mode: String = "player"
		var tool_id: String = ""
		var active: bool = false
		if slot_index < raw.size() and raw[slot_index] is Dictionary:
			var source: Dictionary = raw[slot_index] as Dictionary
			mode = "employee" if str(source.get("mode", "player")) == "employee" else "player"
			if mode == "employee":
				tool_id = str(source.get("tool", ""))
				active = bool(source.get("active", false))
		result.append({"mode":mode, "tool":tool_id, "active":active})
	return result

func _tool_role(tool_id: String) -> String:
	match tool_id:
		"frame_saw", "aku_saw": return "sawyer"
		"wooden_axe", "sharpened_axe", "checht_axe": return "splitter"
		_: return ""

func _tool_cycle_time(tool_id: String) -> float:
	match tool_id:
		"frame_saw": return SAWYER_TIME_FRAME
		"aku_saw": return SAWYER_TIME_AKU
		"wooden_axe": return SPLITTER_TIME_WOODEN
		"sharpened_axe": return SPLITTER_TIME_SHARPENED
		"checht_axe": return SPLITTER_TIME_CHECHT
		_: return 0.0

func _storage_used(state: Dictionary) -> float:
	return float(state.get("logs_m3", 0.0)) + float(state.get("roundwood_m3", 0.0)) + float(state.get("split_m3", 0.0))

func _read_last_seen() -> int:
	if not FileAccess.file_exists(OFFLINE_PATH):
		return 0
	var file: FileAccess = FileAccess.open(OFFLINE_PATH, FileAccess.READ)
	if file == null:
		return 0
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		var parsed_dict: Dictionary = parsed
		return int(parsed_dict.get("last_seen", 0))
	return 0

func _write_last_seen() -> void:
	var file: FileAccess = FileAccess.open(OFFLINE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"last_seen": int(Time.get_unix_time_from_system())}))
