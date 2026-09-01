extends "res://main.gd"

var career_tab_button: Button
var entrepreneur_section: String = "OBJEDNÁVKY"
var achievements_section: String = "ÚSPĚCHY"
var stats_last_money: float = 0.0
var stats_last_roundwood: float = 0.0
var stats_last_split: float = 0.0

func _ready() -> void:
	if not state.has("stats_money_earned"):
		state["stats_money_earned"] = 0.0
	if not state.has("stats_roundwood_produced"):
		state["stats_roundwood_produced"] = 0.0
	if not state.has("stats_split_produced"):
		state["stats_split_produced"] = 0.0
	super._ready()
	if float(state.get("stats_money_earned", 0.0)) <= 0.0 and float(state.get("money", 0.0)) > 0.0:
		state["stats_money_earned"] = float(state.get("money", 0.0))
	if float(state.get("stats_roundwood_produced", 0.0)) <= 0.0 and float(state.get("roundwood_m3", 0.0)) > 0.0:
		state["stats_roundwood_produced"] = float(state.get("roundwood_m3", 0.0))
	if float(state.get("stats_split_produced", 0.0)) <= 0.0 and float(state.get("split_m3", 0.0)) > 0.0:
		state["stats_split_produced"] = float(state.get("split_m3", 0.0))
	stats_last_money = float(state.get("money", 0.0))
	stats_last_roundwood = float(state.get("roundwood_m3", 0.0))
	stats_last_split = float(state.get("split_m3", 0.0))
	save_game()

func _process(delta: float) -> void:
	super._process(delta)
	var money_now: float = float(state.get("money", 0.0))
	var roundwood_now: float = float(state.get("roundwood_m3", 0.0))
	var split_now: float = float(state.get("split_m3", 0.0))
	if money_now > stats_last_money + 0.0001:
		state["stats_money_earned"] = float(state.get("stats_money_earned", 0.0)) + (money_now - stats_last_money)
	if roundwood_now > stats_last_roundwood + 0.000001:
		state["stats_roundwood_produced"] = float(state.get("stats_roundwood_produced", 0.0)) + (roundwood_now - stats_last_roundwood)
	if split_now > stats_last_split + 0.000001:
		state["stats_split_produced"] = float(state.get("stats_split_produced", 0.0)) + (split_now - stats_last_split)
	stats_last_money = money_now
	stats_last_roundwood = roundwood_now
	stats_last_split = split_now

func build_bottom(parent: VBoxContainer) -> void:
	var bar:=HBoxContainer.new()
	bar.custom_minimum_size.y=58
	bar.add_theme_constant_override("separation",1)
	parent.add_child(bar)
	for tab_name:String in ["FIRMA","KARIÉRA","OBCHOD","SKLAD","STATISTIKY","ÚSPĚCHY","NASTAVENÍ"]:
		var b:=Button.new()
		var target_tab: String = tab_name
		if tab_name == "KARIÉRA":
			target_tab = "PRÁCE" if bool(state.get("employed", true)) else "PODNIKATEL"
			b.text = target_tab
			career_tab_button = b
		else:
			b.text=tab_name
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size",16)
		b.add_theme_stylebox_override("normal",panel_style("#211914","#4d3321",0,1))
		b.add_theme_stylebox_override("hover",panel_style("#5d3218","#8f5a2c",0,1))
		if tab_name == "KARIÉRA":
			b.pressed.connect(_open_career_tab)
		else:
			b.pressed.connect(show_tab.bind(target_tab))
		bar.add_child(b)

func _open_career_tab() -> void:
	show_tab("PRÁCE" if bool(state.get("employed", true)) else "PODNIKATEL")

func show_tab(tab:String) -> void:
	var requested: String = tab
	if requested == "PRÁCE" and not bool(state.get("employed", true)):
		requested = "PODNIKATEL"
	elif requested == "PODNIKATEL" and bool(state.get("employed", true)):
		requested = "PRÁCE"
	if requested == "PODNIKATEL":
		_clear_work_refs()
		current_tab = "PODNIKATEL"
		clear_content()
		if is_instance_valid(left_panel): left_panel.visible = false
		if is_instance_valid(right_panel): right_panel.visible = false
		render_entrepreneur()
		return
	if requested == "ÚSPĚCHY":
		_clear_work_refs()
		current_tab = "ÚSPĚCHY"
		clear_content()
		if is_instance_valid(left_panel): left_panel.visible = false
		if is_instance_valid(right_panel): right_panel.visible = false
		render_achievements_hub()
		return
	super.show_tab(requested)

func render_achievements_hub() -> void:
	var panel:=PanelContainer.new()
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",panel_style("#1b1713","#6b4628",7,1))
	content_host.add_child(panel)
	var margin:=MarginContainer.new()
	margin.add_theme_constant_override("margin_left",16)
	margin.add_theme_constant_override("margin_right",16)
	margin.add_theme_constant_override("margin_top",14)
	margin.add_theme_constant_override("margin_bottom",14)
	panel.add_child(margin)
	var root:=VBoxContainer.new()
	root.add_theme_constant_override("separation",12)
	margin.add_child(root)
	var title:=make_label("ÚSPĚCHY",28)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color",Color("#ffca42"))
	root.add_child(title)
	var tabs:=HBoxContainer.new()
	tabs.add_theme_constant_override("separation",2)
	root.add_child(tabs)
	for section:String in ["ÚSPĚCHY","STATISTIKY"]:
		var b:=Button.new()
		b.text=section
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y=42
		b.add_theme_font_size_override("font_size",15)
		if section == achievements_section:
			b.add_theme_stylebox_override("normal",panel_style("#6b3d1d","#b87935",4,2))
		else:
			b.add_theme_stylebox_override("normal",panel_style("#211914","#5f4027",4,1))
		b.add_theme_stylebox_override("hover",panel_style("#5d3218","#9a632c",4,1))
		b.pressed.connect(_set_achievements_section.bind(section))
		tabs.add_child(b)
	var section_host:=PanelContainer.new()
	section_host.size_flags_vertical=Control.SIZE_EXPAND_FILL
	section_host.add_theme_stylebox_override("panel",panel_style("#211914","#5f4027",6,1))
	root.add_child(section_host)
	var section_margin:=MarginContainer.new()
	section_margin.add_theme_constant_override("margin_left",18)
	section_margin.add_theme_constant_override("margin_right",18)
	section_margin.add_theme_constant_override("margin_top",18)
	section_margin.add_theme_constant_override("margin_bottom",18)
	section_host.add_child(section_margin)
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	section_margin.add_child(box)
	var heading:=make_label(achievements_section,24)
	heading.add_theme_color_override("font_color",Color("#ffca42"))
	box.add_child(heading)
	if achievements_section == "ÚSPĚCHY":
		box.add_child(make_label("Tady budou herní úspěchy.",16))
	else:
		_render_statistics(box)

func _render_statistics(box: VBoxContainer) -> void:
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	box.add_child(row)
	_add_stat_card(row, "VYDĚLÁNO PENĚZ", "%.0f Kč" % float(state.get("stats_money_earned", 0.0)))
	_add_stat_card(row, "VYROBENO ŠTÍPANÉHO DŘEVA", "%.3f m³" % float(state.get("stats_split_produced", 0.0)))
	_add_stat_card(row, "VYROBENO ŠPALKŮ", "%.3f m³" % float(state.get("stats_roundwood_produced", 0.0)))

func _add_stat_card(parent: HBoxContainer, label_text: String, value_text: String) -> void:
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
	var value:=make_label(value_text,25)
	value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_color_override("font_color",Color("#ffca42"))
	content.add_child(value)

func _set_achievements_section(section: String) -> void:
	achievements_section = section
	show_tab("ÚSPĚCHY")

func _show_quit_job_confirmation() -> void:
	var dialog:=ConfirmationDialog.new()
	dialog.title="Životní změna"
	dialog.dialog_text="Opravdu chcete odejít z práce a začít podnikat?\n\nPřijdete o pravidelnou mzdu a stanete se podnikatelem. Příjem bude záviset pouze na vašem podnikání."
	dialog.ok_button_text="ZAČÍT PODNIKAT"
	dialog.cancel_button_text="ZRUŠIT"
	dialog.min_size=Vector2i(520,220)
	add_child(dialog)
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(_confirm_start_business.bind(dialog))
	dialog.popup_centered()

func _confirm_start_business(dialog: ConfirmationDialog) -> void:
	state["employed"] = false
	state["current_job"] = "entrepreneur"
	save_game()
	update_hud()
	_update_career_button()
	dialog.queue_free()
	show_tab("PODNIKATEL")

func _show_find_job_confirmation() -> void:
	var dialog:=ConfirmationDialog.new()
	dialog.title="Životní změna"
	dialog.dialog_text="Chcete ukončit podnikání a znovu si najít práci?\n\nVrátíte se do zaměstnání s pravidelnou mzdou. Podnikatelský režim se tím ukončí."
	dialog.ok_button_text="NAJÍT SI PRÁCI"
	dialog.cancel_button_text="ZRUŠIT"
	dialog.min_size=Vector2i(520,220)
	add_child(dialog)
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(_confirm_find_job.bind(dialog))
	dialog.popup_centered()

func _confirm_find_job(dialog: ConfirmationDialog) -> void:
	state["employed"] = true
	state["current_job"] = "helper"
	save_game()
	update_hud()
	_update_career_button()
	dialog.queue_free()
	show_tab("PRÁCE")

func _update_career_button() -> void:
	if is_instance_valid(career_tab_button):
		career_tab_button.text = "PRÁCE" if bool(state.get("employed", true)) else "PODNIKATEL"

func update_hud() -> void:
	super.update_hud()
	if not bool(state.get("employed", true)) and is_instance_valid(role_label):
		role_label.text="Podnikatel"

func render_entrepreneur() -> void:
	var panel:=PanelContainer.new()
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",panel_style("#1b1713","#6b4628",7,1))
	content_host.add_child(panel)
	var margin:=MarginContainer.new()
	margin.add_theme_constant_override("margin_left",16)
	margin.add_theme_constant_override("margin_right",16)
	margin.add_theme_constant_override("margin_top",14)
	margin.add_theme_constant_override("margin_bottom",10)
	panel.add_child(margin)
	var root:=VBoxContainer.new()
	root.add_theme_constant_override("separation",12)
	margin.add_child(root)
	var title:=make_label("PODNIKATEL",28)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color",Color("#ffca42"))
	root.add_child(title)
	var tabs:=HBoxContainer.new()
	tabs.add_theme_constant_override("separation",2)
	root.add_child(tabs)
	for section:String in ["OBJEDNÁVKY","MARKETING","NEMOVITOSTI","FINANCE"]:
		var b:=Button.new()
		b.text=section
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y=42
		b.add_theme_font_size_override("font_size",15)
		if section == entrepreneur_section:
			b.add_theme_stylebox_override("normal",panel_style("#6b3d1d","#b87935",4,2))
		else:
			b.add_theme_stylebox_override("normal",panel_style("#211914","#5f4027",4,1))
		b.add_theme_stylebox_override("hover",panel_style("#5d3218","#9a632c",4,1))
		b.pressed.connect(_set_entrepreneur_section.bind(section))
		tabs.add_child(b)
	var section_host:=PanelContainer.new()
	section_host.size_flags_vertical=Control.SIZE_EXPAND_FILL
	section_host.add_theme_stylebox_override("panel",panel_style("#211914","#5f4027",6,1))
	root.add_child(section_host)
	var section_margin:=MarginContainer.new()
	section_margin.add_theme_constant_override("margin_left",18)
	section_margin.add_theme_constant_override("margin_right",18)
	section_margin.add_theme_constant_override("margin_top",18)
	section_margin.add_theme_constant_override("margin_bottom",18)
	section_host.add_child(section_margin)
	_render_entrepreneur_section(section_margin)
	var bottom:=HBoxContainer.new()
	root.add_child(bottom)
	var spacer:=Control.new()
	spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	var find_job:=Button.new()
	find_job.text="NAJÍT SI PRÁCI"
	find_job.custom_minimum_size=Vector2(180,34)
	find_job.add_theme_font_size_override("font_size",13)
	find_job.add_theme_stylebox_override("normal",panel_style("#8f2525","#c94a4a",5,1))
	find_job.add_theme_stylebox_override("hover",panel_style("#a92e2e","#e35b5b",5,1))
	find_job.pressed.connect(_show_find_job_confirmation)
	bottom.add_child(find_job)

func _set_entrepreneur_section(section: String) -> void:
	entrepreneur_section = section
	show_tab("PODNIKATEL")

func _render_entrepreneur_section(host: MarginContainer) -> void:
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	host.add_child(box)
	if entrepreneur_section == "OBJEDNÁVKY":
		_render_orders_draft(box)
	elif entrepreneur_section == "MARKETING":
		_render_business_placeholder(box,"MARKETING","Tady budou reklamní kampaně a rozpočet na propagaci.\nInvestice do reklamy bude zvyšovat počet příchozích objednávek.")
	elif entrepreneur_section == "NEMOVITOSTI":
		_render_properties(box)
	else:
		_render_business_placeholder(box,"FINANCE","Přehled příjmů a nákladů firmy.\nPozději zde budou také půjčky a jejich splátky.")

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
	var price:=make_label("Pronájem: 2 000 Kč / den",16)
	price.add_theme_color_override("font_color",Color("#ffca42"))
	info.add_child(price)
	info.add_child(make_label("Kauce: 10 000 Kč",15))
	var rent:=Button.new()
	rent.text="PRONAJMOUT"
	rent.custom_minimum_size=Vector2(150,40)
	rent.add_theme_font_size_override("font_size",14)
	rent.add_theme_stylebox_override("normal",panel_style("#315c1c","#5f9631",5,1))
	rent.add_theme_stylebox_override("hover",panel_style("#3d7124","#78b644",5,1))
	row.add_child(rent)

func _render_business_placeholder(box: VBoxContainer, heading: String, text: String) -> void:
	var h:=make_label(heading,24)
	h.add_theme_color_override("font_color",Color("#ffca42"))
	box.add_child(h)
	box.add_child(make_label(text,16))

func _render_orders_draft(box: VBoxContainer) -> void:
	var h:=make_label("OBJEDNÁVKY",24)
	h.add_theme_color_override("font_color",Color("#ffca42"))
	box.add_child(h)
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