extends Node

const SAVE_PATH: String = "user://neighbor_contracts.json"
const OFFER_LIFETIME: int = 120
const ACTIVE_LIFETIME: int = 300
const DELIVERY_STEP_M3: float = 0.1

var current_offer: Dictionary = {}
var active_contracts: Array[Dictionary] = []
var next_offer_at: int = 0
var next_id: int = 1
var tick_elapsed: float = 0.0
var ui_signature: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_state()
	var now: int = _now()
	_cleanup_expired(now)
	if current_offer.is_empty() and next_offer_at <= 0:
		next_offer_at = now + 5
	_save_state()

func _process(delta: float) -> void:
	tick_elapsed += delta
	if tick_elapsed < 0.5:
		return
	tick_elapsed = 0.0
	var now: int = _now()
	var changed: bool = _cleanup_expired(now)
	if not current_offer.is_empty() and now >= int(current_offer.get("expires_at", 0)):
		current_offer = {}
		_schedule_next_offer(now)
		changed = true
	if current_offer.is_empty() and next_offer_at > 0 and now >= next_offer_at:
		_generate_offer(now)
		changed = true
	if changed:
		_save_state()
	var main: Node = get_tree().current_scene
	if main != null and str(main.get("current_tab")) == "FIRMA":
		_ensure_ui(main, now)

func has_active_contract() -> bool:
	_cleanup_expired(_now())
	return not active_contracts.is_empty()

func can_accept_delivery(amount: float = DELIVERY_STEP_M3) -> bool:
	_cleanup_expired(_now())
	for contract: Dictionary in active_contracts:
		var remaining: float = float(contract.get("volume_m3", 0.0)) - float(contract.get("delivered_m3", 0.0))
		if remaining + 0.0001 >= amount:
			return true
	return false

func register_delivery(main: Node, amount: float = DELIVERY_STEP_M3) -> Dictionary:
	_cleanup_expired(_now())
	for index: int in range(active_contracts.size()):
		var contract: Dictionary = active_contracts[index]
		var volume: float = float(contract.get("volume_m3", 0.0))
		var delivered: float = float(contract.get("delivered_m3", 0.0))
		if volume - delivered + 0.0001 < amount:
			continue
		contract["delivered_m3"] = snappedf(delivered + amount, 0.1)
		active_contracts[index] = contract
		var completed: bool = float(contract["delivered_m3"]) + 0.0001 >= volume
		var payout: float = 0.0
		if completed:
			payout = volume * float(contract.get("price_per_m3", 0.0))
			var state: Dictionary = _main_state(main)
			state["money"] = float(state.get("money", 0.0)) + payout
			state["xp"] = int(state.get("xp", 0)) + int(round(volume * 10.0))
			main.set("state", state)
			active_contracts.remove_at(index)
			if main.has_method("update_hud"):
				main.call("update_hud")
			if main.has_method("save_game"):
				main.call("save_game")
		_save_state()
		ui_signature = ""
		return {"ok": true, "completed": completed, "payout": payout, "volume_m3": volume}
	return {"ok": false, "completed": false, "payout": 0.0}

func _generate_offer(now: int) -> void:
	var volume: float = float(randi_range(1, 5)) / 10.0
	current_offer = {
		"id": next_id,
		"volume_m3": volume,
		"price_per_m3": _roll_price(),
		"expires_at": now + OFFER_LIFETIME
	}
	next_id += 1
	next_offer_at = 0
	ui_signature = ""

func _roll_price() -> int:
	var roll: int = randi_range(1, 100)
	if roll <= 25:
		return 1100
	if roll <= 45:
		return 1125
	if roll <= 62:
		return 1150
	if roll <= 76:
		return 1175
	if roll <= 87:
		return 1200
	if roll <= 95:
		return 1225
	return 1250

func _schedule_next_offer(now: int) -> void:
	if randf() < 0.35:
		next_offer_at = now + randi_range(60, 180)
	else:
		next_offer_at = now + randi_range(10, 30)
	ui_signature = ""

func _accept_offer() -> void:
	if current_offer.is_empty():
		return
	var now: int = _now()
	if now >= int(current_offer.get("expires_at", 0)):
		current_offer = {}
		_schedule_next_offer(now)
		_save_state()
		return
	var contract: Dictionary = current_offer.duplicate(true)
	contract["accepted_at"] = now
	contract["expires_at"] = now + ACTIVE_LIFETIME
	contract["delivered_m3"] = 0.0
	active_contracts.append(contract)
	current_offer = {}
	_schedule_next_offer(now)
	_save_state()
	ui_signature = ""

func _cleanup_expired(now: int) -> bool:
	var changed: bool = false
	var kept: Array[Dictionary] = []
	for contract: Dictionary in active_contracts:
		if now < int(contract.get("expires_at", 0)):
			kept.append(contract)
		else:
			changed = true
	if changed:
		active_contracts = kept
		ui_signature = ""
	return changed

func _ensure_ui(main: Node, now: int) -> void:
	var box: VBoxContainer = _jobs_box(main)
	if box == null:
		return
	var signature: String = _make_signature()
	var existing: Node = box.get_node_or_null("NeighborContractsPanel")
	if existing != null and signature == ui_signature:
		_refresh_countdowns(existing, now)
		return
	if existing != null:
		existing.queue_free()
		ui_signature = ""
		return

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "NeighborContractsPanel"
	panel.add_theme_stylebox_override("panel", _style(main, "#171411", "#79512e", 7, 1))
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	margin.add_child(content)

	var title: Label = _label(main, "SOUSEDI", 16)
	title.add_theme_color_override("font_color", Color("#ffca42"))
	content.add_child(title)

	var offer_panel: PanelContainer = PanelContainer.new()
	offer_panel.name = "NeighborOfferPanel"
	offer_panel.add_theme_stylebox_override("panel", _style(main, "#211b15", "#9b6a36", 6, 1))
	var offer_margin: MarginContainer = MarginContainer.new()
	offer_margin.add_theme_constant_override("margin_left", 8)
	offer_margin.add_theme_constant_override("margin_right", 8)
	offer_margin.add_theme_constant_override("margin_top", 6)
	offer_margin.add_theme_constant_override("margin_bottom", 6)
	offer_panel.add_child(offer_margin)
	var offer_content: VBoxContainer = VBoxContainer.new()
	offer_content.add_theme_constant_override("separation", 4)
	offer_margin.add_child(offer_content)
	content.add_child(offer_panel)

	if current_offer.is_empty():
		offer_content.add_child(_label(main, "Teď nikdo nic nechce.", 12))
		var wait_label: Label = _label(main, "", 11)
		wait_label.name = "NeighborWaitLabel"
		offer_content.add_child(wait_label)
	else:
		var volume: float = float(current_offer.get("volume_m3", 0.0))
		var price: int = int(current_offer.get("price_per_m3", 0))
		var total: float = volume * float(price)
		offer_content.add_child(_label(main, "%.1f m³ štípaného • %d Kč/m³" % [volume, price], 12))
		var offer_timer: Label = _label(main, "", 11)
		offer_timer.name = "NeighborOfferTimer"
		offer_timer.set_meta("total", total)
		offer_content.add_child(offer_timer)
		var accept: Button = Button.new()
		accept.text = "VZÍT ZAKÁZKU"
		accept.custom_minimum_size.y = 30
		accept.pressed.connect(_accept_offer)
		offer_content.add_child(accept)

	if not active_contracts.is_empty():
		var active_title: Label = _label(main, "VZATÉ ZAKÁZKY", 12)
		active_title.add_theme_color_override("font_color", Color("#d7b17a"))
		content.add_child(active_title)
		for contract: Dictionary in active_contracts:
			var id: int = int(contract.get("id", 0))
			var contract_panel: PanelContainer = PanelContainer.new()
			contract_panel.name = "ActiveContractPanel_%d" % id
			contract_panel.add_theme_stylebox_override("panel", _style(main, "#121716", "#4f7b66", 6, 1))
			var contract_margin: MarginContainer = MarginContainer.new()
			contract_margin.add_theme_constant_override("margin_left", 8)
			contract_margin.add_theme_constant_override("margin_right", 8)
			contract_margin.add_theme_constant_override("margin_top", 6)
			contract_margin.add_theme_constant_override("margin_bottom", 6)
			contract_panel.add_child(contract_margin)
			var contract_content: VBoxContainer = VBoxContainer.new()
			contract_content.add_theme_constant_override("separation", 2)
			contract_margin.add_child(contract_content)

			var contract_volume: float = float(contract.get("volume_m3", 0.0))
			var contract_price: int = int(contract.get("price_per_m3", 0))
			var contract_total: float = contract_volume * float(contract_price)
			contract_content.add_child(_label(main, "Zakázka #%d • %.1f m³" % [id, contract_volume], 12))
			contract_content.add_child(_label(main, "%d Kč/m³ • celkem %.0f Kč" % [contract_price, contract_total], 11))
			var active_label: Label = _label(main, "", 11)
			active_label.name = "ContractTimer_%d" % id
			active_label.set_meta("volume", contract_volume)
			active_label.set_meta("delivered", float(contract.get("delivered_m3", 0.0)))
			active_label.set_meta("expires_at", int(contract.get("expires_at", 0)))
			contract_content.add_child(active_label)
			content.add_child(contract_panel)

	box.add_child(panel)
	box.move_child(panel, mini(1, box.get_child_count() - 1))
	ui_signature = signature
	_refresh_countdowns(panel, now)

func _refresh_countdowns(panel: Node, now: int) -> void:
	var wait_node: Node = panel.find_child("NeighborWaitLabel", true, false)
	if wait_node is Label:
		var wait_seconds: int = maxi(0, next_offer_at - now)
		(wait_node as Label).text = "Další možnost asi za %s" % _time_text(wait_seconds)
	var offer_node: Node = panel.find_child("NeighborOfferTimer", true, false)
	if offer_node is Label and not current_offer.is_empty():
		var offer_left: int = maxi(0, int(current_offer.get("expires_at", 0)) - now)
		var total: float = float(offer_node.get_meta("total", 0.0))
		(offer_node as Label).text = "Celkem %.0f Kč • nabídka %s" % [total, _time_text(offer_left)]
	for contract: Dictionary in active_contracts:
		var id: int = int(contract.get("id", 0))
		var node: Node = panel.find_child("ContractTimer_%d" % id, true, false)
		if node is Label:
			var volume: float = float(contract.get("volume_m3", 0.0))
			var delivered: float = float(contract.get("delivered_m3", 0.0))
			var left: int = maxi(0, int(contract.get("expires_at", 0)) - now)
			(node as Label).text = "Odvezeno %.1f/%.1f m³ • zbývá %s" % [delivered, volume, _time_text(left)]

func _make_signature() -> String:
	var offer_part: String = "none:%d" % next_offer_at
	if not current_offer.is_empty():
		offer_part = "offer:%s" % str(current_offer.get("id", 0))
	var active_part: String = ""
	for contract: Dictionary in active_contracts:
		active_part += "%s:%.1f|" % [str(contract.get("id", 0)), float(contract.get("delivered_m3", 0.0))]
	return offer_part + "/" + active_part

func _jobs_box(main: Node) -> VBoxContainer:
	var host_value: Variant = main.get("content_host")
	if not (host_value is MarginContainer):
		return null
	var host: MarginContainer = host_value as MarginContainer
	if host.get_child_count() == 0:
		return null
	var row: Node = host.get_child(0)
	if not (row is HBoxContainer) or row.get_child_count() < 3:
		return null
	var right: Node = row.get_child(2)
	if not (right is PanelContainer) or right.get_child_count() == 0:
		return null
	var margin: Node = right.get_child(0)
	if not (margin is MarginContainer) or margin.get_child_count() == 0:
		return null
	var box: Node = margin.get_child(0)
	if box is VBoxContainer:
		return box as VBoxContainer
	return null

func _time_text(seconds: int) -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60]

func _now() -> int:
	return int(Time.get_unix_time_from_system())

func _main_state(main: Node) -> Dictionary:
	var value: Variant = main.get("state")
	if value is Dictionary:
		return value as Dictionary
	return {}

func _save_state() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({
			"current_offer": current_offer,
			"active_contracts": active_contracts,
			"next_offer_at": next_offer_at,
			"next_id": next_id
		}))

func _load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	var data: Dictionary = parsed as Dictionary
	var offer_value: Variant = data.get("current_offer", {})
	if offer_value is Dictionary:
		current_offer = offer_value as Dictionary
	var active_value: Variant = data.get("active_contracts", [])
	if active_value is Array:
		active_contracts.clear()
		var loaded_array: Array = active_value as Array
		for item: Variant in loaded_array:
			if item is Dictionary:
				active_contracts.append(item as Dictionary)
	next_offer_at = int(data.get("next_offer_at", 0))
	next_id = maxi(1, int(data.get("next_id", 1)))

func _label(main: Node, text_value: String, size: int) -> Label:
	var value: Variant = main.call("make_label", text_value, size)
	if value is Label:
		return value as Label
	var label: Label = Label.new()
	label.text = text_value
	return label

func _style(main: Node, bg: String, border: String, radius: int, width: int) -> StyleBoxFlat:
	var value: Variant = main.call("panel_style", bg, border, radius, width)
	if value is StyleBoxFlat:
		return value as StyleBoxFlat
	return StyleBoxFlat.new()
