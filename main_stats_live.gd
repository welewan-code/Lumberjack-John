extends "res://main_career.gd"

var stats_money_value_label: Label = null
var stats_split_value_label: Label = null
var stats_roundwood_value_label: Label = null

func show_tab(tab: String) -> void:
	if tab == "STATISTIKY":
		achievements_section = "STATISTIKY"
		super.show_tab("ÚSPĚCHY")
		return
	super.show_tab(tab)

func _process(delta: float) -> void:
	super._process(delta)
	_refresh_statistics_values()

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
