extends "res://contract_manager.gd"

const PICKUP_SAVE_PATH: String = "user://neighbor_pickup.json"
const PICKUP_MIN_M3: float = 0.1
const PICKUP_MAX_M3: float = 1.0
const PICKUP_STEP_M3: float = 0.1

var neighbor_self_pickup_enabled: bool = false

func _ready() -> void:
	_load_pickup_setting()
	super._ready()

func _process(delta: float) -> void:
	super._process(delta)
	if startup_pending or not neighbor_self_pickup_enabled:
		return
	var main: Node = get_tree().current_scene
	if main == null:
		return
	_process_self_pickup_offer(main, _now())

func _finish_startup(main: Node) -> void:
	var last_seen: int = offline_last_seen
	super._finish_startup(main)
	if neighbor_self_pickup_enabled:
		_apply_offline_self_pickup(main, last_seen, _now())
		_process_self_pickup_offer(main, _now())

func _offer_volumes_for_tool(tool_id: String) -> Array[float]:
	var source: Array[float] = super._offer_volumes_for_tool(tool_id)
	var limited: Array[float] = []
	for volume: float in source:
		if volume <= PICKUP_MAX_M3 + 0.0001:
			limited.append(volume)
	return limited

func _generate_offer(now: int, main: Node) -> void:
	if not neighbor_self_pickup_enabled:
		super._generate_offer(now, main)
		return
	var steps: int = int(round(PICKUP_MAX_M3 / PICKUP_STEP_M3))
	var volume: float = float(randi_range(1, steps)) * PICKUP_STEP_M3
	current_offer = {
		"id": next_id,
		"volume_m3": volume,
		"price_per_m3": _roll_price(),
		"transport_tool": "",
		"expires_at": now + OFFER_LIFETIME
	}
	next_id += 1
	next_offer_at = 0
	ui_signature = ""

func _reserved_split_stock(state: Dictionary) -> float:
	return maxf(0.0, float(state.get("self_pickup_reserve_m3", 0.0)))

func _can_self_pickup(state: Dictionary, volume: float) -> bool:
	var available: float = float(state.get("split_m3", 0.0))
	var reserve: float = _reserved_split_stock(state)
	return available - volume + 0.0001 >= reserve

func _process_self_pickup_offer(main: Node, now: int) -> bool:
	if not neighbor_self_pickup_enabled or current_offer.is_empty():
		return false
	if now >= int(current_offer.get("expires_at", 0)):
		return false
	var volume: float = clampf(float(current_offer.get("volume_m3", 0.0)), PICKUP_MIN_M3, PICKUP_MAX_M3)
	var state: Dictionary = _main_state(main)
	if not _can_self_pickup(state, volume):
		return false
	var price: float = float(current_offer.get("price_per_m3", 0.0))
	state["split_m3"] = maxf(0.0, float(state.get("split_m3", 0.0)) - volume)
	state["money"] = float(state.get("money", 0.0)) + volume * price
	state["xp"] = int(state.get("xp", 0)) + _contract_xp(volume)
	main.set("state", state)
	current_offer = {}
	_schedule_next_offer(now)
	_save_state()
	ui_signature = ""
	if main.has_method("save_game"):
		main.call("save_game")
	if main.has_method("update_hud"):
		main.call("update_hud")
	return true

func _apply_offline_self_pickup(main: Node, last_seen: int, now: int) -> void:
	if last_seen <= 0 or now <= last_seen:
		return
	var state: Dictionary = _main_state(main)
	var cursor: int = last_seen
	var changed: bool = false
	var safety: int = 0
	while cursor < now and safety < 5000:
		safety += 1
		var wait_seconds: int = _roll_pickup_wait_seconds()
		cursor += wait_seconds
		if cursor > now:
			break
		var steps: int = int(round(PICKUP_MAX_M3 / PICKUP_STEP_M3))
		var volume: float = float(randi_range(1, steps)) * PICKUP_STEP_M3
		if not _can_self_pickup(state, volume):
			continue
		var price: float = float(_roll_price())
		state["split_m3"] = maxf(0.0, float(state.get("split_m3", 0.0)) - volume)
		state["money"] = float(state.get("money", 0.0)) + volume * price
		state["xp"] = int(state.get("xp", 0)) + _contract_xp(volume)
		changed = true
	if changed:
		main.set("state", state)
		ui_signature = ""
		if main.has_method("save_game"):
			main.call("save_game")
		if main.has_method("update_hud"):
			main.call("update_hud")

func _roll_pickup_wait_seconds() -> int:
	if randf() < 0.35:
		return randi_range(60, 180)
	return randi_range(10, 30)

func _ensure_ui(main: Node, now: int) -> void:
	super._ensure_ui(main, now)
	var box: VBoxContainer = _jobs_box(main)
	if box == null:
		return
	var panel: Node = box.get_node_or_null("NeighborContractsPanel")
	if panel == null:
		return
	var existing: Node = panel.find_child("NeighborSelfPickupButton", true, false)
	if existing is Button:
		_update_pickup_button(existing as Button)
		return
	var content: VBoxContainer = _neighbor_content(panel)
	if content == null:
		return
	var separator: HSeparator = HSeparator.new()
	separator.name = "NeighborSelfPickupSeparator"
	content.add_child(separator)
	var hint: Label = _label(main, "Sousedé si hotové dřevo vyzvednou sami. Prodej probíhá automaticky i offline.", 11)
	hint.name = "NeighborSelfPickupHint"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 0
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(hint)
	var button: Button = Button.new()
	button.name = "NeighborSelfPickupButton"
	button.custom_minimum_size = Vector2(0, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 11)
	button.pressed.connect(_toggle_neighbor_self_pickup.bind(button))
	content.add_child(button)
	_update_pickup_button(button)

func _neighbor_content(panel: Node) -> VBoxContainer:
	if panel.get_child_count() == 0:
		return null
	var margin: Node = panel.get_child(0)
	if not (margin is MarginContainer) or margin.get_child_count() == 0:
		return null
	var content: Node = margin.get_child(0)
	if content is VBoxContainer:
		return content as VBoxContainer
	return null

func _toggle_neighbor_self_pickup(button: Button) -> void:
	neighbor_self_pickup_enabled = not neighbor_self_pickup_enabled
	_save_pickup_setting()
	ui_signature = ""
	if neighbor_self_pickup_enabled:
		var now: int = _now()
		if current_offer.is_empty():
			next_offer_at = mini(next_offer_at if next_offer_at > 0 else now + 1, now + 1)
		_save_state()
	_update_pickup_button(button)

func _update_pickup_button(button: Button) -> void:
	if neighbor_self_pickup_enabled:
		button.text = "VLASTNÍ ODBĚR SOUSEDŮ:\nPOVOLEN"
		button.tooltip_text = "Sousedé automaticky kupují hotové dřevo do 1 m³, ale nesmí sáhnout do rezervy nastavené ve skladu."
	else:
		button.text = "POVOLIT SOUSEDŮM VLASTNÍ\nODBĚR DŘEVA"
		button.tooltip_text = "Kliknutím povolíš automatický vlastní odběr sousedů."

func _save_pickup_setting() -> void:
	var file: FileAccess = FileAccess.open(PICKUP_SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"enabled": neighbor_self_pickup_enabled}))

func _load_pickup_setting() -> void:
	if not FileAccess.file_exists(PICKUP_SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(PICKUP_SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		neighbor_self_pickup_enabled = bool((parsed as Dictionary).get("enabled", false))

func is_neighbor_self_pickup_enabled() -> bool:
	return neighbor_self_pickup_enabled
