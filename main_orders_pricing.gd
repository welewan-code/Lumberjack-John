extends "res://main_career.gd"

const ORDER_SOFTWOOD_MIN_PRICE: int = 900
const ORDER_SOFTWOOD_MAX_PRICE: int = 1450
const ORDER_SOFTWOOD_PRICE_STEP: int = 50
const ORDER_DELIVERY_MIN_PRICE: int = 0
const ORDER_DELIVERY_MAX_PRICE: int = 30
const ORDER_DELIVERY_PRICE_STEP: int = 5
const ORDER_MAX_PENDING: int = 3
const ORDER_MIN_VOLUME_M3: int = 1
const ORDER_MAX_VOLUME_M3: int = 6
const ORDER_MIN_DISTANCE_KM: int = 5
const ORDER_MAX_DISTANCE_KM: int = 30
const ORDER_MIN_LIFETIME_DAYS: int = 1
const ORDER_MAX_LIFETIME_DAYS: int = 3

var order_tick_elapsed: float = 0.0

func _ready() -> void:
	if not state.has("order_softwood_price_per_m3"):
		state["order_softwood_price_per_m3"] = 1250
	if not state.has("order_delivery_price_per_km"):
		state["order_delivery_price_per_km"] = 10
	if not state.has("self_pickup_reserve_m3"):
		state["self_pickup_reserve_m3"] = 0.0
	if not state.has("customer_order_offers"):
		state["customer_order_offers"] = []
	if not state.has("customer_order_next_at"):
		state["customer_order_next_at"] = 0
	if not state.has("customer_order_next_id"):
		state["customer_order_next_id"] = 1
	super._ready()
	_normalize_customer_orders()
	_process_customer_orders(true)

func _process(delta: float) -> void:
	super._process(delta)
	order_tick_elapsed += delta
	if order_tick_elapsed < 1.0:
		return
	order_tick_elapsed = 0.0
	_process_customer_orders(false)

func _normalize_customer_orders() -> void:
	var raw: Variant = state.get("customer_order_offers", [])
	var normalized: Array = []
	if raw is Array:
		for item: Variant in raw:
			if item is Dictionary:
				normalized.append((item as Dictionary).duplicate(true))
	state["customer_order_offers"] = normalized
	state["customer_order_next_id"] = maxi(1, int(state.get("customer_order_next_id", 1)))

func _process_customer_orders(startup: bool) -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var offers: Array = state.get("customer_order_offers", []) as Array
	var kept: Array = []
	var changed: bool = false
	for item: Variant in offers:
		if item is Dictionary:
			var order: Dictionary = item as Dictionary
			if now < int(order.get("expires_at", 0)):
				kept.append(order)
			else:
				changed = true
	offers = kept

	var next_at: int = int(state.get("customer_order_next_at", 0))
	if next_at <= 0:
		next_at = now + _roll_customer_order_wait_seconds()
		changed = true

	var safety: int = 0
	while offers.size() < ORDER_MAX_PENDING and now >= next_at and safety < ORDER_MAX_PENDING:
		safety += 1
		offers.append(_make_customer_order(next_at))
		next_at += _roll_customer_order_wait_seconds()
		changed = true

	state["customer_order_offers"] = offers
	state["customer_order_next_at"] = next_at
	if changed:
		save_game()
		if not startup and current_tab == "PODNIKATEL" and entrepreneur_section == "OBJEDNÁVKY":
			show_tab("PODNIKATEL")

func _make_customer_order(created_at: int) -> Dictionary:
	var volume: int = randi_range(ORDER_MIN_VOLUME_M3, ORDER_MAX_VOLUME_M3)
	var distance: int = randi_range(ORDER_MIN_DISTANCE_KM, ORDER_MAX_DISTANCE_KM)
	var wood_price: int = int(state.get("order_softwood_price_per_m3", 1250))
	var delivery_price: int = int(state.get("order_delivery_price_per_km", 10))
	var total_price: int = volume * wood_price + distance * delivery_price
	var lifetime_days: int = randi_range(ORDER_MIN_LIFETIME_DAYS, ORDER_MAX_LIFETIME_DAYS)
	var next_id: int = int(state.get("customer_order_next_id", 1))
	state["customer_order_next_id"] = next_id + 1
	return {
		"id": next_id,
		"volume_m3": volume,
		"distance_km": distance,
		"wood_price_per_m3": wood_price,
		"delivery_price_per_km": delivery_price,
		"total_price": total_price,
		"created_at": created_at,
		"expires_at": created_at + lifetime_days * 86400
	}

func _roll_customer_order_wait_seconds() -> int:
	var effective_price: float = _representative_effective_price()
	var wait_minutes: Vector2 = _wait_range_for_effective_price(effective_price)
	var min_seconds: int = int(round(wait_minutes.x * 60.0))
	var max_seconds: int = int(round(wait_minutes.y * 60.0))
	return randi_range(min_seconds, maxi(min_seconds, max_seconds))

func _representative_effective_price() -> float:
	var wood_price: float = float(state.get("order_softwood_price_per_m3", 1250))
	var delivery_price: float = float(state.get("order_delivery_price_per_km", 10))
	# Průměrný zákazník: 3,5 m³ ve vzdálenosti 17,5 km.
	return wood_price + (17.5 * delivery_price) / 3.5

func _wait_range_for_effective_price(price: float) -> Vector2:
	var anchors: Array[Dictionary] = [
		{"price":900.0, "min":5.0, "max":10.0},
		{"price":1000.0, "min":8.0, "max":15.0},
		{"price":1100.0, "min":12.0, "max":20.0},
		{"price":1200.0, "min":20.0, "max":30.0},
		{"price":1300.0, "min":30.0, "max":50.0},
		{"price":1400.0, "min":60.0, "max":90.0},
		{"price":1450.0, "min":60.0, "max":120.0},
		{"price":1600.0, "min":90.0, "max":150.0}
	]
	if price <= float(anchors[0]["price"]):
		return Vector2(float(anchors[0]["min"]), float(anchors[0]["max"]))
	for i: int in range(anchors.size() - 1):
		var a: Dictionary = anchors[i]
		var b: Dictionary = anchors[i + 1]
		var a_price: float = float(a["price"])
		var b_price: float = float(b["price"])
		if price <= b_price:
			var t: float = inverse_lerp(a_price, b_price, price)
			return Vector2(
				lerpf(float(a["min"]), float(b["min"]), t),
				lerpf(float(a["max"]), float(b["max"]), t)
			)
	var last: Dictionary = anchors[anchors.size() - 1]
	return Vector2(float(last["min"]), float(last["max"]))

func _render_orders_draft(box: VBoxContainer) -> void:
	var header:=HBoxContainer.new()
	header.add_theme_constant_override("separation",10)
	box.add_child(header)

	var h:=make_label("OBJEDNÁVKY",24)
	h.add_theme_color_override("font_color",Color("#ffca42"))
	h.custom_minimum_size.x=210
	header.add_child(h)

	var wood_label:=make_label("Cena za m³ měkké",14)
	wood_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	header.add_child(wood_label)
	var wood_price:=OptionButton.new()
	wood_price.custom_minimum_size=Vector2(135,36)
	wood_price.add_theme_font_size_override("font_size",14)
	var current_wood:int=int(state.get("order_softwood_price_per_m3",1250))
	for price:int in range(ORDER_SOFTWOOD_MIN_PRICE, ORDER_SOFTWOOD_MAX_PRICE + 1, ORDER_SOFTWOOD_PRICE_STEP):
		wood_price.add_item("%d Kč/m³" % price)
		wood_price.set_item_metadata(wood_price.item_count - 1, price)
		if price == current_wood:
			wood_price.select(wood_price.item_count - 1)
	wood_price.item_selected.connect(_on_softwood_price_selected.bind(wood_price))
	header.add_child(wood_price)

	var delivery_label:=make_label("Cena za km",14)
	delivery_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	header.add_child(delivery_label)
	var delivery_price:=OptionButton.new()
	delivery_price.custom_minimum_size=Vector2(120,36)
	delivery_price.add_theme_font_size_override("font_size",14)
	var current_delivery:int=int(state.get("order_delivery_price_per_km",10))
	for price:int in range(ORDER_DELIVERY_MIN_PRICE, ORDER_DELIVERY_MAX_PRICE + 1, ORDER_DELIVERY_PRICE_STEP):
		delivery_price.add_item("%d Kč/km" % price)
		delivery_price.set_item_metadata(delivery_price.item_count - 1, price)
		if price == current_delivery:
			delivery_price.select(delivery_price.item_count - 1)
	delivery_price.item_selected.connect(_on_delivery_price_selected.bind(delivery_price))
	header.add_child(delivery_price)

	var help:=Button.new()
	help.text="?"
	help.custom_minimum_size=Vector2(36,36)
	help.add_theme_font_size_override("font_size",16)
	help.tooltip_text="Cena dřeva a dopravy společně ovlivňují, jak často budou přicházet větší objednávky. Nižší celková cena zvyšuje poptávku, vyšší ji snižuje. Vzdálenost zákazníků je 5–30 km, takže dražší sazba za km se projeví hlavně u vzdálenějších objednávek. Velikost objednávky také ovlivní, jak výrazně se doprava promítne do výsledné ceny na m³."
	help.pressed.connect(_show_order_pricing_help)
	header.add_child(help)

	box.add_child(make_label("Poptávky zákazníků",15))
	var offers: Array = state.get("customer_order_offers", []) as Array
	if offers.is_empty():
		box.add_child(make_label("Zatím žádná objednávka.",14))
		return
	var now: int = int(Time.get_unix_time_from_system())
	for item: Variant in offers:
		if item is Dictionary:
			_add_customer_order_card(box, item as Dictionary, now)

func _add_customer_order_card(box: VBoxContainer, order: Dictionary, now: int) -> void:
	var card:=PanelContainer.new()
	card.add_theme_stylebox_override("panel",panel_style("#1a1714","#8a572b",6,1))
	box.add_child(card)
	var margin:=MarginContainer.new()
	margin.add_theme_constant_override("margin_left",14)
	margin.add_theme_constant_override("margin_right",14)
	margin.add_theme_constant_override("margin_top",10)
	margin.add_theme_constant_override("margin_bottom",10)
	card.add_child(margin)
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	margin.add_child(row)
	var info:=VBoxContainer.new()
	info.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var volume: int = int(order.get("volume_m3", 1))
	var distance: int = int(order.get("distance_km", 5))
	var title:=make_label("%d m³ měkkého dřeva" % volume,18)
	title.add_theme_color_override("font_color",Color("#ffca42"))
	info.add_child(title)
	info.add_child(make_label("%d km" % distance,14))
	info.add_child(make_label(_order_expiry_text(int(order.get("expires_at", now)), now),13))
	var total:=make_label("%d Kč" % int(order.get("total_price", 0)),18)
	total.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	row.add_child(total)

func _order_expiry_text(expires_at: int, now: int) -> String:
	var remaining: int = maxi(0, expires_at - now)
	var days: int = int(ceil(float(remaining) / 86400.0))
	return "Platí ještě %d d" % days

func _on_softwood_price_selected(index: int, selector: OptionButton) -> void:
	state["order_softwood_price_per_m3"] = int(selector.get_item_metadata(index))
	_reschedule_customer_order_search()
	save_game()

func _on_delivery_price_selected(index: int, selector: OptionButton) -> void:
	state["order_delivery_price_per_km"] = int(selector.get_item_metadata(index))
	_reschedule_customer_order_search()
	save_game()

func _reschedule_customer_order_search() -> void:
	state["customer_order_next_at"] = int(Time.get_unix_time_from_system()) + _roll_customer_order_wait_seconds()

func _show_order_pricing_help() -> void:
	var dialog:=AcceptDialog.new()
	dialog.title="Ceník a poptávka"
	dialog.dialog_text="Cena dřeva a dopravy se posuzují dohromady.\n\nNižší celková cena = vyšší šance na objednávku.\nVyšší celková cena = nižší šance na objednávku.\n\nZákazníci jsou vzdálení 5–30 km. Vzdálenost sama o sobě poptávku nesnižuje, ale zvyšuje výslednou cenu dopravy. U větších objednávek se doprava lépe rozpočítá na více m³, u malých vzdálených objednávek bude mít na rozhodnutí zákazníka větší vliv."
	dialog.ok_button_text="ROZUMÍM"
	dialog.min_size=Vector2i(560,300)
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.popup_centered()
