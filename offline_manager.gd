extends Node

const OFFLINE_PATH: String = "user://drevo_tycoon_offline.json"
const HEARTBEAT_SECONDS: float = 5.0

const SPLITTER_WAGE: float = 2.0
const SAWYER_WAGE: float = 5.0
const SAW_M3: float = 0.010
const CHOP_IN_M3: float = 0.010
const CHOP_OUT_M3: float = 0.015
const STORAGE_CAPACITY: float = 10.0
const SPLITTER_TIME_WOODEN: float = 1.8
const SPLITTER_TIME_SHARPENED: float = 1.6
const SAWYER_TIME_FRAME: float = 3.0
const SAWYER_TIME_AKU: float = 1.5

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

	var state_value: Variant = game.get("state")
	if not (state_value is Dictionary):
		_write_last_seen()
		return
	var state: Dictionary = state_value as Dictionary

	var splitter_tool: String = str(state.get("splitter_tool", ""))
	var sawyer_tool: String = str(state.get("sawyer_tool", ""))
	var splitter_enabled: bool = bool(state.get("splitter_hired", false)) and bool(state.get("splitter_active", true))
	var sawyer_enabled: bool = bool(state.get("sawyer_hired", false)) and bool(state.get("sawyer_active", true))

	var split_cycle: float = 0.0
	if splitter_enabled:
		if splitter_tool == "sharpened":
			split_cycle = SPLITTER_TIME_SHARPENED
		elif splitter_tool == "wooden":
			split_cycle = SPLITTER_TIME_WOODEN

	var saw_cycle: float = 0.0
	if sawyer_enabled:
		if sawyer_tool == "frame_saw":
			saw_cycle = SAWYER_TIME_FRAME
		elif sawyer_tool == "aku_saw":
			saw_cycle = SAWYER_TIME_AKU

	if split_cycle <= 0.0 and saw_cycle <= 0.0:
		_write_last_seen()
		return

	var sentinel: float = 1.0e30
	var next_split: float = split_cycle if split_cycle > 0.0 else sentinel
	var next_saw: float = saw_cycle if saw_cycle > 0.0 else sentinel
	var split_count: int = 0
	var saw_count: int = 0
	var safety: int = 0

	while safety < 20000:
		safety += 1
		var next_event: float = minf(next_split, next_saw)
		if next_event > float(elapsed):
			break

		if next_saw <= next_split:
			if _do_sawyer_cycle(state):
				saw_count += 1
				next_saw += saw_cycle
			else:
				next_saw = sentinel
		else:
			if _do_splitter_cycle(state):
				split_count += 1
				next_split += split_cycle
			else:
				next_split = sentinel

		if next_split >= sentinel and next_saw >= sentinel:
			break

	if saw_count > 0 or split_count > 0:
		game.set("state", state)
		if game.has_method("save_game"):
			game.call("save_game")
		if game.has_method("update_hud"):
			game.call("update_hud")
		if game.has_method("show_tab"):
			game.call("show_tab", str(game.get("current_tab")))

	_write_last_seen()

func _do_sawyer_cycle(state: Dictionary) -> bool:
	if float(state.get("money", 0.0)) < SAWYER_WAGE:
		return false
	if float(state.get("logs_m3", 0.0)) + 0.0001 < SAW_M3:
		return false
	state["money"] = float(state.get("money", 0.0)) - SAWYER_WAGE
	state["logs_m3"] = maxf(0.0, float(state.get("logs_m3", 0.0)) - SAW_M3)
	state["roundwood_m3"] = float(state.get("roundwood_m3", 0.0)) + SAW_M3
	return true

func _do_splitter_cycle(state: Dictionary) -> bool:
	if float(state.get("money", 0.0)) < SPLITTER_WAGE:
		return false
	if float(state.get("roundwood_m3", 0.0)) + 0.0001 < CHOP_IN_M3:
		return false
	var net_growth: float = CHOP_OUT_M3 - CHOP_IN_M3
	if _storage_used(state) + net_growth > STORAGE_CAPACITY + 0.0001:
		return false
	state["money"] = float(state.get("money", 0.0)) - SPLITTER_WAGE
	state["roundwood_m3"] = maxf(0.0, float(state.get("roundwood_m3", 0.0)) - CHOP_IN_M3)
	state["split_m3"] = float(state.get("split_m3", 0.0)) + CHOP_OUT_M3
	return true

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
