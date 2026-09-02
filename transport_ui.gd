extends Node

const TRANSPORT_SAVE_PATH: String = "user://transport_state.json"
const WHEELBARROW_AMOUNT_M3: float = 0.1
const HANDCART_AMOUNT_M3: float = 0.2
const SMALL_TRAILER_AMOUNT_M3: float = 0.5
const TRANSPORT_WAGE: float = 5.0
const TRANSPORT_TIME: float = 5.0
const SMALL_TRAILER_COST_PER_KM: float = 2.0
const CUSTOMER_ORDER_SECONDS_PER_KM: float = 10.0
const UI_REFRESH_INTERVAL: float = 0.25

var transport_running: bool = false
var transport_elapsed: float = 0.0
var transport_running_tool: String = ""
var transport_running_kind: String = ""
var transport_duration: float = TRANSPORT_TIME
var transport_delivery_amount: float = 0.0
var transport_trip_cost: float = 0.0
var transport_button: Button = null
var ui_refresh_elapsed: float = 0.0
var saved_transport_tool: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_transport_state()

func _process(delta: float) -> void:
	var main: Node = get_tree().current_scene
	if main == null:
		return
	_restore_saved_tool(main)
	_process_transport(main, delta)

	ui_refresh_elapsed += delta
	if ui_refresh_elapsed < UI_REFRESH_INTERVAL:
		return
	ui_refresh_elapsed = 0.0

	# Výběr dopravy je nově v levém firemním menu, starý prostřední slot nepoužíváme.
	if str(main.get("current_tab")) == "FIRMA":
		_remove_slot(main)
	if not transport_running:
		_try_auto_start(main)

func get_selected_transport_tool(main: Node = null) -> String:
	if main != null:
		var state: Dictionary = _state(main)
		var state_tool: String = str(state.get("transport_tool", ""))
		if state_tool != "":
			return state_tool
	return saved_transport_tool

func is_customer_order_transport_running() -> bool:
	return transport_running and transport_running_kind == "customer"

func get_customer_order_transport_remaining_seconds() -> float:
	if not is_customer_order_transport_running():
		return 0.0
	return maxf(0.0, transport_duration - transport_elapsed)

func get_customer_order_transport_delivery_amount() -> float:
	if not is_customer_order_transport_running():
		return 0.0
	return transport_delivery_amount

func _restore_saved_tool(main: Node) -> void:
	if saved_transport_tool == "":
		return
	var state: Dictionary = _state(main)
	if str(state.get("transport_tool", "")) == saved_transport_tool:
		return
	state["transport_tool"] = saved_transport_tool
	main.set("state", state)

func _try_auto_start(main: Node) -> void:
	# Přijatá velká zákaznická objednávka má přednost před starými malými zakázkami.
	if main.has_method("has_active_customer_order") and bool(main.call("has_active_customer_order")):
		_try_start_customer_order(main)
		return
	_try_start_legacy_contract(main)

func _try_start_customer_order(main: Node) -> void:
	var tool: String = get_selected_transport_tool(main)
	if tool != "small_trailer" or _owned_transport(tool) <= 0:
		return
	if not main.has_method("get_customer_order_delivery_amount") or not main.has_method("get_customer_order_distance_km"):
		return
	var capacity: float = SMALL_TRAILER_AMOUNT_M3
	var delivery_amount: float = float(main.call("get_customer_order_delivery_amount", capacity))
	if delivery_amount <= 0.0:
		return
	var state: Dictionary = _state(main)
	if float(state.get("split_m3", 0.0)) + 0.0001 < delivery_amount:
		return
	var distance_km: float = maxf(0.0, float(main.call("get_customer_order_distance_km")))
	var trip_cost: float = distance_km * SMALL_TRAILER_COST_PER_KM
	if float(state.get("money", 0.0)) + 0.0001 < trip_cost:
		return
	transport_running = true
	transport_running_kind = "customer"
	transport_running_tool = tool
	transport_delivery_amount = delivery_amount
	transport_trip_cost = trip_cost
	transport_duration = maxf(0.1, distance_km * CUSTOMER_ORDER_SECONDS_PER_KM)
	transport_elapsed = 0.0

func _try_start_legacy_contract(main: Node) -> void:
	var state: Dictionary = _state(main)
	var tool: String = get_selected_transport_tool(main)
	var capacity: float = _transport_capacity(tool)
	if capacity <= 0.0 or _owned_transport(tool) <= 0:
		return
	var delivery_amount: float = _contract_delivery_amount(capacity)
	if delivery_amount <= 0.0:
		return
	if float(state.get("split_m3", 0.0)) + 0.0001 < delivery_amount:
		return
	if float(state.get("money", 0.0)) < TRANSPORT_WAGE:
		return
	transport_running = true
	transport_running_kind = "legacy"
	transport_running_tool = tool
	transport_delivery_amount = delivery_amount
	transport_trip_cost = TRANSPORT_WAGE
	transport_duration = TRANSPORT_TIME
	transport_elapsed = 0.0

func _process_transport(main: Node, delta: float) -> void:
	if not transport_running:
		return
	transport_elapsed += delta
	if transport_elapsed < transport_duration:
		return

	var kind: String = transport_running_kind
	var delivery_amount: float = transport_delivery_amount
	var trip_cost: float = transport_trip_cost
	transport_running = false
	transport_elapsed = 0.0
	transport_running_kind = ""
	transport_running_tool = ""
	transport_delivery_amount = 0.0
	transport_trip_cost = 0.0
	transport_duration = TRANSPORT_TIME

	var state: Dictionary = _state(main)
	if delivery_amount <= 0.0 or float(state.get("split_m3", 0.0)) + 0.0001 < delivery_amount:
		return

	state["split_m3"] = maxf(0.0, float(state.get("split_m3", 0.0)) - delivery_amount)
	state["money"] = float(state.get("money", 0.0)) - trip_cost
	main.set("state", state)

	if kind == "customer":
		if main.has_method("register_customer_order_delivery"):
			main.call("register_customer_order_delivery", delivery_amount)
	else:
		_register_delivery(main, delivery_amount)

	if main.has_method("update_hud"):
		main.call("update_hud")
	if main.has_method("save_game"):
		main.call("save_game")

func _contract_bool(method_name: String, args: Array = []) -> bool:
	var contracts: Node = get_node_or_null("/root/ContractManager")
	if contracts == null or not contracts.has_method(method_name):
		return false
	var value: Variant
	if args.is_empty():
		value = contracts.call(method_name)
	else:
		value = contracts.callv(method_name, args)
	if value is bool:
		return value as bool
	return false

func _contract_delivery_amount(max_amount: float) -> float:
	var contracts: Node = get_node_or_null("/root/ContractManager")
	if contracts == null:
		return 0.0
	if contracts.has_method("get_delivery_amount"):
		var value: Variant = contracts.call("get_delivery_amount", max_amount)
		if value is float or value is int:
			return float(value)
	if _contract_bool("can_accept_delivery", [max_amount]):
		return max_amount
	return 0.0

func _register_delivery(main: Node, amount: float) -> Dictionary:
	var contracts: Node = get_node_or_null("/root/ContractManager")
	if contracts == null or not contracts.has_method("register_delivery"):
		return {"ok": false, "completed": false, "payout": 0.0}
	var value: Variant = contracts.call("register_delivery", main, amount)
	if value is Dictionary:
		return value as Dictionary
	return {"ok": false, "completed": false, "payout": 0.0}

func _transport_capacity(tool_id: String) -> float:
	if tool_id == "wheelbarrow":
		return WHEELBARROW_AMOUNT_M3
	if tool_id == "handcart":
		return HANDCART_AMOUNT_M3
	if tool_id == "small_trailer":
		return SMALL_TRAILER_AMOUNT_M3
	return 0.0

func _transport_name(tool_id: String) -> String:
	if tool_id == "wheelbarrow":
		return "KOLEČKO"
	if tool_id == "handcart":
		return "TRAKAŘ"
	if tool_id == "small_trailer":
		return "MALÝ VOZÍK"
	return "DOPRAVA"

func _remove_slot(main: Node) -> void:
	var scene: Control = _company_scene(main)
	if scene == null:
		return
	var existing: Node = scene.get_node_or_null("TransportSlot")
	if existing != null:
		existing.queue_free()
	transport_button = null

func _company_scene(main: Node) -> Control:
	var host_value: Variant = main.get("content_host")
	if not (host_value is MarginContainer):
		return null
	var host: MarginContainer = host_value as MarginContainer
	if host.get_child_count() == 0:
		return null
	var row: Node = host.get_child(0)
	if not (row is HBoxContainer) or row.get_child_count() < 2:
		return null
	var center: Node = row.get_child(1)
	if not (center is PanelContainer) or center.get_child_count() == 0:
		return null
	var scene: Node = center.get_child(0)
	if scene is Control:
		return scene as Control
	return null

func _owned_transport(item_id: String) -> int:
	var shop: Node = get_node_or_null("/root/ShopUI")
	if shop == null:
		return 0
	var value: Variant = shop.get("inventory")
	if value is Dictionary:
		return int((value as Dictionary).get(item_id, 0))
	return 0

func _state(main: Node) -> Dictionary:
	var value: Variant = main.get("state")
	if value is Dictionary:
		return value as Dictionary
	return {}

func _save_transport_state() -> void:
	var file: FileAccess = FileAccess.open(TRANSPORT_SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"transport_tool": saved_transport_tool}))

func _load_transport_state() -> void:
	if not FileAccess.file_exists(TRANSPORT_SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(TRANSPORT_SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		saved_transport_tool = str((parsed as Dictionary).get("transport_tool", ""))
