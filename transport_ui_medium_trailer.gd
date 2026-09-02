extends "res://transport_ui.gd"

const MEDIUM_TRAILER_ID: String = "medium_trailer"
const MEDIUM_TRAILER_AMOUNT_M3: float = 1.0
const MEDIUM_TRAILER_COST_PER_KM: float = 3.0

func _try_start_customer_order(main: Node) -> void:
	var tool: String = get_selected_transport_tool(main)
	if tool != "small_trailer" and tool != MEDIUM_TRAILER_ID:
		return
	if _owned_transport(tool) <= 0:
		return
	if not main.has_method("get_customer_order_delivery_amount") or not main.has_method("get_customer_order_distance_km"):
		return
	var capacity: float = _transport_capacity(tool)
	var delivery_amount: float = float(main.call("get_customer_order_delivery_amount", capacity))
	if delivery_amount <= 0.0:
		return
	var state: Dictionary = _state(main)
	if float(state.get("split_m3", 0.0)) + 0.0001 < delivery_amount:
		return
	var distance_km: float = maxf(0.0, float(main.call("get_customer_order_distance_km")))
	var trip_cost: float = distance_km * _customer_order_cost_per_km(tool)
	if float(state.get("money", 0.0)) + 0.0001 < trip_cost:
		return
	transport_running = true
	transport_running_kind = "customer"
	transport_running_tool = tool
	transport_delivery_amount = delivery_amount
	transport_trip_cost = trip_cost
	transport_duration = maxf(0.1, distance_km * CUSTOMER_ORDER_SECONDS_PER_KM)
	transport_elapsed = 0.0

func _transport_capacity(tool_id: String) -> float:
	if tool_id == MEDIUM_TRAILER_ID:
		return MEDIUM_TRAILER_AMOUNT_M3
	return super._transport_capacity(tool_id)

func _transport_name(tool_id: String) -> String:
	if tool_id == MEDIUM_TRAILER_ID:
		return "STŘEDNÍ VOZÍK"
	return super._transport_name(tool_id)

func _customer_order_cost_per_km(tool_id: String) -> float:
	if tool_id == MEDIUM_TRAILER_ID:
		return MEDIUM_TRAILER_COST_PER_KM
	return SMALL_TRAILER_COST_PER_KM

func get_selected_transport_capacity(main: Node = null) -> float:
	return _transport_capacity(get_selected_transport_tool(main))

func get_selected_customer_order_cost_per_km(main: Node = null) -> float:
	return _customer_order_cost_per_km(get_selected_transport_tool(main))
