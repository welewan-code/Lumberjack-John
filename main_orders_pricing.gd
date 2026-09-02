extends "res://main_career.gd"

const ORDER_SOFTWOOD_MIN_PRICE: int = 900
const ORDER_SOFTWOOD_MAX_PRICE: int = 1450
const ORDER_SOFTWOOD_PRICE_STEP: int = 50
const ORDER_DELIVERY_MIN_PRICE: int = 0
const ORDER_DELIVERY_MAX_PRICE: int = 30
const ORDER_DELIVERY_PRICE_STEP: int = 5

func _ready() -> void:
	if not state.has("order_softwood_price_per_m3"):
		state["order_softwood_price_per_m3"] = 1250
	if not state.has("order_delivery_price_per_km"):
		state["order_delivery_price_per_km"] = 10
	super._ready()

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
	help.tooltip_text="Cena dřeva a dopravy společně ovlivňují, jak často budou přicházet větší objednávky. Nižší celková cena zvyšuje poptávku, vyšší ji snižuje. Vzdálenost zákazníků bude 5–30 km, takže dražší sazba za km se projeví hlavně u vzdálenějších objednávek. Velikost objednávky také ovlivní, jak výrazně se doprava promítne do výsledné ceny na m³."
	help.pressed.connect(_show_order_pricing_help)
	header.add_child(help)

	box.add_child(make_label("Poptávky zákazníků",15))
	var orders: Array[Dictionary] = [
		{"name":"Rodinný dům – Kladno","amount":"3,0 m³ štípaného dřeva","price":"6 300 Kč","term":"Termín: 3 dny"},
		{"name":"Chata – okolí Kladna","amount":"1,5 m³ štípaného dřeva","price":"3 300 Kč","term":"Termín: 2 dny"},
		{"name":"Menší odběr","amount":"0,5 m³ štípaného dřeva","price":"1 150 Kč","term":"Termín: 1 den"}
	]
	for order:Dictionary in orders:
		var card:=PanelContainer.new()
		card.add_theme_stylebox_override("panel",panel_style("#1a1714","#8a572b",6,1))
		box.add_child(card)
		var m:=MarginContainer.new()
		m.add_theme_constant_override("margin_left",14)
		m.add_theme_constant_override("margin_right",14)
		m.add_theme_constant_override("margin_top",10)
		m.add_theme_constant_override("margin_bottom",10)
		card.add_child(m)
		var row:=HBoxContainer.new()
		m.add_child(row)
		var info:=VBoxContainer.new()
		info.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var name_label:=make_label(str(order["name"]),18)
		name_label.add_theme_color_override("font_color",Color("#ffca42"))
		info.add_child(name_label)
		info.add_child(make_label(str(order["amount"]),15))
		info.add_child(make_label(str(order["term"]),13))
		var price:=make_label(str(order["price"]),18)
		price.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		row.add_child(price)

func _on_softwood_price_selected(index: int, selector: OptionButton) -> void:
	state["order_softwood_price_per_m3"] = int(selector.get_item_metadata(index))
	save_game()

func _on_delivery_price_selected(index: int, selector: OptionButton) -> void:
	state["order_delivery_price_per_km"] = int(selector.get_item_metadata(index))
	save_game()

func _show_order_pricing_help() -> void:
	var dialog:=AcceptDialog.new()
	dialog.title="Ceník a poptávka"
	dialog.dialog_text="Cena dřeva a dopravy se posuzují dohromady.\n\nNižší celková cena = vyšší šance na objednávku.\nVyšší celková cena = nižší šance na objednávku.\n\nZákazníci budou vzdálení 5–30 km. Vzdálenost sama o sobě poptávku nesnižuje, ale zvyšuje výslednou cenu dopravy. U větších objednávek se doprava lépe rozpočítá na více m³, u malých vzdálených objednávek bude mít na rozhodnutí zákazníka větší vliv."
	dialog.ok_button_text="ROZUMÍM"
	dialog.min_size=Vector2i(560,300)
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.popup_centered()
