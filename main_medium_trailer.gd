extends "res://main_stats_live.gd"

const MEDIUM_TRAILER_ID: String = "medium_trailer"

func _active_order_transport_text(order: Dictionary) -> String:
	var transport: Node = get_node_or_null("/root/TransportUI")
	var selected: String = str(state.get("transport_tool", ""))
	if transport != null and transport.has_method("get_selected_transport_tool"):
		selected = str(transport.call("get_selected_transport_tool", self))
	if selected != "small_trailer" and selected != MEDIUM_TRAILER_ID:
		return "Čeká na vozík za auto."
	if float(state.get("split_m3", 0.0)) <= 0.0001:
		return "Čeká na štípané dřevo."
	if selected == MEDIUM_TRAILER_ID:
		return "Střední vozík odváží automaticky • 1,0 m³/cesta • 10 s/km • náklad 3 Kč/km."
	return "Vozík odváží automaticky • 0,5 m³/cesta • 10 s/km • náklad 2 Kč/km."

func _active_order_remaining_seconds(order: Dictionary) -> float:
	var volume: float = float(order.get("volume_m3", 0.0))
	var delivered: float = clampf(float(order.get("delivered_m3", 0.0)), 0.0, volume)
	var remaining_volume: float = maxf(0.0, volume - delivered)
	if remaining_volume <= 0.0001:
		return 0.0
	var distance: float = maxf(0.0, float(order.get("distance_km", 0.0)))
	var trip_seconds: float = distance * CUSTOMER_ORDER_SECONDS_PER_KM
	var capacity: float = CUSTOMER_ORDER_TRAILER_CAPACITY_M3
	var transport: Node = get_node_or_null("/root/TransportUI")
	if transport != null and transport.has_method("get_selected_transport_capacity"):
		capacity = maxf(0.001, float(transport.call("get_selected_transport_capacity", self)))
	var trips: int = int(ceil(remaining_volume / capacity))
	var total: float = float(trips) * trip_seconds
	var active: Array = _active_orders()
	if not active.is_empty() and active[0] is Dictionary and int((active[0] as Dictionary).get("id", 0)) == int(order.get("id", 0)):
		if transport != null and transport.has_method("is_customer_order_transport_running") and bool(transport.call("is_customer_order_transport_running")):
			if transport.has_method("get_customer_order_transport_remaining_seconds"):
				var current_remaining: float = maxf(0.0, float(transport.call("get_customer_order_transport_remaining_seconds")))
				return current_remaining + float(maxi(0, trips - 1)) * trip_seconds
	return total
