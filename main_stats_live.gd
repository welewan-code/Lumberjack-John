extends "res://main_orders_pricing.gd"

const FIRST_PROPERTY_DEPOSIT: float = 10000.0
const FIRST_PROPERTY_DAILY_RENT: float = 2000.0
const FIRST_PROPERTY_RENT_INTERVAL: float = 86400.0

var stats_money_value_label: Label = null
var stats_split_value_label: Label = null
var stats_roundwood_value_label: Label = null
var property_rent_check_elapsed: float = 0.0

func _ready() -> void:
	_prepare_property_state_before_load()
	super._ready()
	call_deferred("_check_first_property_rent")

func _prepare_property_state_before_load() -> void:
	var legacy_entrepreneur_without_property_key: bool = false
	if FileAccess.file_exists(SAVE_PATH):
		var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				var saved: Dictionary = parsed as Dictionary
				legacy_entrepreneur_without_property_key = not saved.has("first_property_rented") and not saved.has("company_location") and not bool(saved.get("employed", true))

	if not state.has("first_property_rented"):
		state["first_property_rented"] = legacy_entrepreneur_without_property_key
	if not state.has("company_location"):
		state["company_location"] = "first_property" if legacy_entrepreneur_without_property_key else "home"
	if not state.has("first_property_last_rent_time"):
		state["first_property_last_rent_time"] = Time.get_unix_time_from_system() if legacy_entrepreneur_without_property_key else 0.0

func show_tab(tab: String) -> void:
	if tab == "STATISTIKY":
		achievements_section = "STATISTIKY"
		super.show_tab("ÚSPĚCHY")
		return
	super.show_tab(tab)

func _process(delta: float) -> void:
	super._process(delta)
	_refresh_statistics_values()
	property_rent_check_elapsed += delta
	if property_rent_check_elapsed >= 30.0:
		property_rent_check_elapsed = 0.0
		_check_first_property_rent()

func _render_statistics(box: VBoxContainer) -> void:
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	box.add_child(row)
	stats_money_value_label = _add_live_stat_card(row, "VYDĚLÁNO PENĚZ")
	stats_split_value_label = _add_live_stat_card(row, "VYROBENO ŠTÍPANÉHO DŘEVA")
	stats_roundwood_value_label = _add_live_stat_card(row, "VYROBENO ŠPALKŮ")
	_refresh_statistics_values()

func _add_live_stat_card(parent: HBoxContainer, label_text: String) -> Label:
	var card:=PanelContainer.new()
	card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.y=120
	card.add_theme_stylebox_override("panel",panel_style("#1a1714","#8a572b",6,1))
	parent.add_child(card)
	var margin:=MarginContainer.new()
	margin.add_theme_constant_override("margin_left",14)
	margin.add_theme_constant_override("margin_right",14)
	margin.add_theme_constant_override("margin_top",12)
	margin.add_theme_constant_override("margin_bottom",12)
	card.add_child(margin)
	var content:=VBoxContainer.new()
	content.alignment=BoxContainer.ALIGNMENT_CENTER
	margin.add_child(content)
	var label:=make_label(label_text,14)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(label)
	var value:=make_label("0",25)
	value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_color_override("font_color",Color("#ffca42"))
	content.add_child(value)
	return value

func _refresh_statistics_values() -> void:
	if is_instance_valid(stats_money_value_label):
		stats_money_value_label.text = "%.0f Kč" % float(state.get("stats_money_earned", 0.0))
	if is_instance_valid(stats_split_value_label):
		stats_split_value_label.text = "%.3f m³" % float(state.get("stats_split_produced", 0.0))
	if is_instance_valid(stats_roundwood_value_label):
		stats_roundwood_value_label.text = "%.3f m³" % float(state.get("stats_roundwood_produced", 0.0))

func _render_properties(box: VBoxContainer) -> void:
	var h:=make_label("NEMOVITOSTI",24)
	h.add_theme_color_override("font_color",Color("#ffca42"))
	box.add_child(h)
	box.add_child(make_label("Pronájmy a nabídky provozních pozemků a areálů.",15))
	var card:=PanelContainer.new()
	card.add_theme_stylebox_override("panel",panel_style("#1a1714","#8a572b",6,1))
	box.add_child(card)
	var m:=MarginContainer.new()
	m.add_theme_constant_override("margin_left",12)
	m.add_theme_constant_override("margin_right",12)
	m.add_theme_constant_override("margin_top",10)
	m.add_theme_constant_override("margin_bottom",10)
	card.add_child(m)
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",14)
	m.add_child(row)
	var preview:=PanelContainer.new()
	preview.custom_minimum_size=Vector2(150,82)
	preview.add_theme_stylebox_override("panel",panel_style("#2b241d","#6b4628",4,1))
	row.add_child(preview)
	var preview_label:=make_label("FIREMNÍ\nZÁZEMÍ",15)
	preview_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	preview_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	preview_label.add_theme_color_override("font_color",Color("#cdbb9b"))
	preview.add_child(preview_label)
	var info:=VBoxContainer.new()
	info.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation",4)
	row.add_child(info)
	var name_label:=make_label("Firemní zázemí – malý dřevosklad",18)
	name_label.add_theme_color_override("font_color",Color("#ffca42"))
	info.add_child(name_label)
	info.add_child(make_label("Oplocený provozní prostor s buňkou a místem pro zaměstnance, techniku a manipulaci se dřevem.",14))
	var price:=make_label("Pronájem: 2 000 Kč / 24 h",16)
	price.add_theme_color_override("font_color",Color("#ffca42"))
	info.add_child(price)
	info.add_child(make_label("Kauce: 10 000 Kč",15))
	info.add_child(make_label("Kapacita skladu po pronájmu: 40 m³",15))
	var rent:=Button.new()
	var rented: bool = bool(state.get("first_property_rented", false)) or str(state.get("company_location", "home")) == "first_property"
	rent.text="PRONAJATO" if rented else "PRONAJMOUT"
	rent.disabled=rented
	rent.custom_minimum_size=Vector2(150,40)
	rent.add_theme_font_size_override("font_size",14)
	rent.add_theme_stylebox_override("normal",panel_style("#315c1c","#5f9631",5,1))
	rent.add_theme_stylebox_override("hover",panel_style("#3d7124","#78b644",5,1))
	if not rented:
		rent.pressed.connect(_show_first_property_confirmation)
	row.add_child(rent)

func _show_first_property_confirmation() -> void:
	var total: float = FIRST_PROPERTY_DEPOSIT + FIRST_PROPERTY_DAILY_RENT
	var dialog:=ConfirmationDialog.new()
	dialog.title="Pronájem firemního zázemí"
	dialog.dialog_text="Pronajmout Firemní zázemí – malý dřevosklad?\n\nKauce: 10 000 Kč\nPrvních 24 h nájmu: 2 000 Kč\nCelkem nyní: 12 000 Kč\n\nPronájem zvýší kapacitu skladu na 40 m³. Dalších 2 000 Kč se strhne po každých 24 hodinách."
	dialog.ok_button_text="PRONAJMOUT ZA %.0f Kč" % total
	dialog.cancel_button_text="ZRUŠIT"
	dialog.min_size=Vector2i(520,280)
	add_child(dialog)
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(_confirm_first_property_rental.bind(dialog))
	dialog.popup_centered()

func _confirm_first_property_rental(dialog: ConfirmationDialog) -> void:
	var total: float = FIRST_PROPERTY_DEPOSIT + FIRST_PROPERTY_DAILY_RENT
	if float(state.get("money",0.0)) < total:
		dialog.dialog_text="Nemáš dost peněz. Potřebuješ 12 000 Kč na kauci a prvních 24 h nájmu."
		return
	state["money"] = float(state.get("money",0.0)) - total
	state["first_property_rented"] = true
	state["first_property_last_rent_time"] = Time.get_unix_time_from_system()
	if not state.has("company_location"):
		state["company_location"] = "home"
	save_game()
	update_hud()
	dialog.queue_free()
	show_tab("PODNIKATEL")

func _check_first_property_rent() -> void:
	var rented: bool = bool(state.get("first_property_rented", false)) or str(state.get("company_location", "home")) == "first_property"
	if not rented:
		return
	if not bool(state.get("first_property_rented", false)):
		state["first_property_rented"] = true
	var now: float = Time.get_unix_time_from_system()
	var last_paid: float = float(state.get("first_property_last_rent_time", 0.0))
	if last_paid <= 0.0 or last_paid > now:
		state["first_property_last_rent_time"] = now
		save_game()
		return
	var elapsed: float = now - last_paid
	var periods: int = int(floor(elapsed / FIRST_PROPERTY_RENT_INTERVAL))
	if periods <= 0:
		return
	state["money"] = float(state.get("money", 0.0)) - FIRST_PROPERTY_DAILY_RENT * float(periods)
	state["first_property_last_rent_time"] = last_paid + FIRST_PROPERTY_RENT_INTERVAL * float(periods)
	save_game()
	update_hud()
