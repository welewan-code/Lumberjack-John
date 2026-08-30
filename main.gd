extends Control

const SAVE_PATH: String = "user://drevo_tycoon_save.json"
const STORAGE_CAPACITY: float = 10.0
const AXE_IN: float = 0.010
const AXE_OUT: float = 0.015
const WOODEN_AXE_TIME: float = 1.8
const SHARPENED_AXE_TIME: float = 1.6
const CHECHT_AXE_TIME: float = 1.5

var state: Dictionary = {
	"money": 0.0,
	"xp": 0,
	"level": 0,
	"logs_m3": 0.0,
	"roundwood_m3": 0.0,
	"split_m3": 0.0,
	"wooden_axe_qty": 1,
	"sharpened_axe_qty": 0,
	"checht_axe_qty": 0,
	"equipped_axe": "wooden",
	"employed": true,
	"current_job": "helper",
	"work_clicks": 0,
	"chop_seeded": false,
	"sawyer_hired": false,
	"splitter_hired": false,
	"sawyer_active": true,
	"splitter_active": true,
	"sawyer_tool": "",
	"splitter_tool": "wooden"
}

var current_tab: String = "PRÁCE"
var content_host: MarginContainer
var left_panel: PanelContainer
var right_panel: PanelContainer
var money_label: Label
var logs_label: Label
var roundwood_label: Label
var split_label: Label
var role_label: Label
var xp_label: Label
var chop_button: Button
var timer_label: Label
var progress: ProgressBar
var action_running: bool = false
var action_elapsed: float = 0.0
var action_duration: float = WOODEN_AXE_TIME
var save_elapsed: float = 0.0

func _ready() -> void:
	load_game()
	build_ui()
	show_tab("PRÁCE")
	update_hud()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()

func panel_style(color_hex: String, border_hex: String = "#6b4628", radius: int = 6, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color_hex)
	style.border_color = Color(border_hex)
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style

func make_label(text_value: String, size: int = 16) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("#f2e9da"))
	return label

func build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#18120e")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	build_top(root)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 2)
	root.add_child(body)
	build_left(body)
	content_host = MarginContainer.new()
	content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_host.add_theme_constant_override("margin_left", 4)
	content_host.add_theme_constant_override("margin_right", 4)
	content_host.add_theme_constant_override("margin_top", 4)
	content_host.add_theme_constant_override("margin_bottom", 4)
	body.add_child(content_host)
	build_right(body)
	build_bottom(root)

func build_top(parent: VBoxContainer) -> void:
	var top := HBoxContainer.new()
	top.custom_minimum_size.y = 84
	top.add_theme_constant_override("separation", 2)
	parent.add_child(top)
	var p1 := PanelContainer.new(); p1.custom_minimum_size.x = 360; p1.add_theme_stylebox_override("panel", panel_style("#1d1712")); top.add_child(p1)
	var m1 := MarginContainer.new(); m1.add_theme_constant_override("margin_left",14); m1.add_theme_constant_override("margin_top",8); m1.add_theme_constant_override("margin_right",14); m1.add_theme_constant_override("margin_bottom",8); p1.add_child(m1)
	var v1 := VBoxContainer.new(); m1.add_child(v1)
	role_label = make_label("Pomocník",15); v1.add_child(role_label)
	xp_label = make_label("0 XP",13); v1.add_child(xp_label)
	var xp_bar := ProgressBar.new(); xp_bar.max_value=100.0; xp_bar.value=0.0; xp_bar.show_percentage=false; xp_bar.custom_minimum_size.y=10; v1.add_child(xp_bar)
	var p2 := PanelContainer.new(); p2.size_flags_horizontal=Control.SIZE_EXPAND_FILL; p2.add_theme_stylebox_override("panel",panel_style("#1d1712")); top.add_child(p2)
	var m2 := MarginContainer.new(); m2.add_theme_constant_override("margin_left",18); m2.add_theme_constant_override("margin_top",14); p2.add_child(m2)
	money_label=make_label("0 Kč",27); money_label.add_theme_color_override("font_color",Color("#ffca42")); m2.add_child(money_label)
	var p3 := PanelContainer.new(); p3.size_flags_horizontal=Control.SIZE_EXPAND_FILL; p3.add_theme_stylebox_override("panel",panel_style("#1d1712")); top.add_child(p3)
	var m3 := MarginContainer.new(); m3.add_theme_constant_override("margin_left",14); m3.add_theme_constant_override("margin_top",14); p3.add_child(m3)
	logs_label=make_label("0.000 m³\nKulatina",17); m3.add_child(logs_label)
	var p4 := PanelContainer.new(); p4.size_flags_horizontal=Control.SIZE_EXPAND_FILL; p4.add_theme_stylebox_override("panel",panel_style("#1d1712")); top.add_child(p4)
	var m4 := MarginContainer.new(); m4.add_theme_constant_override("margin_left",14); m4.add_theme_constant_override("margin_top",14); p4.add_child(m4)
	roundwood_label=make_label("0.000 m³\nŠpalky",17); m4.add_child(roundwood_label)
	var p5 := PanelContainer.new(); p5.size_flags_horizontal=Control.SIZE_EXPAND_FILL; p5.add_theme_stylebox_override("panel",panel_style("#1d1712")); top.add_child(p5)
	var m5 := MarginContainer.new(); m5.add_theme_constant_override("margin_left",14); m5.add_theme_constant_override("margin_top",14); p5.add_child(m5)
	split_label=make_label("0.000 m³\nŠtípané dřevo",17); m5.add_child(split_label)

func build_left(parent: HBoxContainer) -> void:
	left_panel=PanelContainer.new(); left_panel.custom_minimum_size.x=274; left_panel.add_theme_stylebox_override("panel",panel_style("#1b1713")); parent.add_child(left_panel)
	var margin:=MarginContainer.new(); margin.add_theme_constant_override("margin_left",12); margin.add_theme_constant_override("margin_right",12); margin.add_theme_constant_override("margin_top",12); margin.add_theme_constant_override("margin_bottom",12); left_panel.add_child(margin)
	var box:=VBoxContainer.new(); box.add_theme_constant_override("separation",12); margin.add_child(box)
	var title:=make_label("PRÁCE",24); title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; box.add_child(title)
	var shift:=PanelContainer.new(); shift.add_theme_stylebox_override("panel",panel_style("#1a1714","#5f4027")); box.add_child(shift)
	var sm:=MarginContainer.new(); sm.add_theme_constant_override("margin_left",14); sm.add_theme_constant_override("margin_right",14); sm.add_theme_constant_override("margin_top",12); sm.add_theme_constant_override("margin_bottom",12); shift.add_child(sm)
	var sv:=VBoxContainer.new(); sm.add_child(sv); sv.add_child(make_label("Pracovní směna",16)); sv.add_child(make_label("Po 8 pracovních seknutích\nzískáš 2× volno. Když\npokračuješ, jede přesčas\n+20 % mzdy.",14))
	var own:=PanelContainer.new(); own.add_theme_stylebox_override("panel",panel_style("#1a1714","#5f4027")); box.add_child(own)
	var om:=MarginContainer.new(); om.add_theme_constant_override("margin_left",14); om.add_theme_constant_override("margin_right",14); om.add_theme_constant_override("margin_top",12); om.add_theme_constant_override("margin_bottom",12); own.add_child(om)
	var ov:=VBoxContainer.new(); om.add_child(ov); ov.add_child(make_label("Vlastní firma",16)); ov.add_child(make_label("Volný čas můžeš využít na\nvlastní zakázky v záložce\nFIRMA.",14))

func build_right(parent: HBoxContainer) -> void:
	right_panel=PanelContainer.new(); right_panel.custom_minimum_size.x=300; right_panel.add_theme_stylebox_override("panel",panel_style("#1b1713")); parent.add_child(right_panel)
	var margin:=MarginContainer.new(); margin.add_theme_constant_override("margin_left",12); margin.add_theme_constant_override("margin_right",12); margin.add_theme_constant_override("margin_top",12); margin.add_theme_constant_override("margin_bottom",12); right_panel.add_child(margin)
	var box:=VBoxContainer.new(); box.add_theme_constant_override("separation",12); margin.add_child(box)
	var title:=make_label("PRÁCE",24); title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; box.add_child(title)
	var current:=PanelContainer.new(); current.add_theme_stylebox_override("panel",panel_style("#1a1714","#9a632c",7,2)); box.add_child(current)
	var cm:=MarginContainer.new(); cm.add_theme_constant_override("margin_left",12); cm.add_theme_constant_override("margin_right",12); cm.add_theme_constant_override("margin_top",12); cm.add_theme_constant_override("margin_bottom",12); current.add_child(cm)
	var cv:=VBoxContainer.new(); cm.add_child(cv); var h:=make_label("AKTUÁLNÍ PRÁCE",20); h.add_theme_color_override("font_color",Color("#ffca42")); cv.add_child(h); cv.add_child(make_label("Pomocník ve dřevárně",18)); cv.add_child(make_label("Pomocné práce se dřevem.",14)); cv.add_child(make_label("Mzda: 1–3 Kč / sek",14)); cv.add_child(make_label("XP: 1–5 XP / sek",14)); cv.add_child(make_label("Směna: 0/8",14))
	var quit:=Button.new(); quit.text="ODEJÍT Z PRÁCE"; quit.custom_minimum_size.y=34; quit.add_theme_stylebox_override("normal",panel_style("#597f0d","#7ca620",4,1)); box.add_child(quit)
	var offer:=PanelContainer.new(); offer.add_theme_stylebox_override("panel",panel_style("#1a1714","#9a632c",7,2)); box.add_child(offer)
	var ofm:=MarginContainer.new(); ofm.add_theme_constant_override("margin_left",12); ofm.add_theme_constant_override("margin_right",12); ofm.add_theme_constant_override("margin_top",12); ofm.add_theme_constant_override("margin_bottom",12); offer.add_child(ofm)
	var ofv:=VBoxContainer.new(); ofm.add_child(ofv); var oh:=make_label("NABÍDKA PRÁCE",20); oh.add_theme_color_override("font_color",Color("#ffca42")); ofv.add_child(oh); ofv.add_child(make_label("Skladník dřeva",18)); ofv.add_child(make_label("Práce ve skladu a manipulace\nse dřevem.",14)); ofv.add_child(make_label("Požadovaný level: 1",14)); ofv.add_child(make_label("Mzda: 4–7 Kč",14)); ofv.add_child(make_label("XP: 3–7 XP",14))
	var accept:=Button.new(); accept.text="PŘIJMOUT PRÁCI"; accept.custom_minimum_size.y=34; accept.add_theme_stylebox_override("normal",panel_style("#597f0d","#7ca620",4,1)); ofv.add_child(accept)

func build_bottom(parent: VBoxContainer) -> void:
	var bar:=HBoxContainer.new(); bar.custom_minimum_size.y=58; bar.add_theme_constant_override("separation",1); parent.add_child(bar)
	for tab_name:String in ["FIRMA","PRÁCE","OBCHOD","SKLAD","STATISTIKY","ÚSPĚCHY","NASTAVENÍ"]:
		var b:=Button.new(); b.text=tab_name; b.size_flags_horizontal=Control.SIZE_EXPAND_FILL; b.add_theme_font_size_override("font_size",16); b.add_theme_stylebox_override("normal",panel_style("#211914","#4d3321",0,1)); b.add_theme_stylebox_override("hover",panel_style("#5d3218","#8f5a2c",0,1)); b.pressed.connect(show_tab.bind(tab_name)); bar.add_child(b)

func clear_content() -> void:
	for child:Node in content_host.get_children(): child.queue_free()

func _clear_work_refs() -> void:
	action_running = false
	chop_button = null
	timer_label = null
	progress = null

func show_tab(tab:String) -> void:
	if tab != "PRÁCE":
		_clear_work_refs()
	current_tab=tab
	clear_content()
	var is_work: bool = tab == "PRÁCE"
	if is_instance_valid(left_panel): left_panel.visible = is_work
	if is_instance_valid(right_panel): right_panel.visible = is_work
	if tab=="PRÁCE":
		render_work()
	elif tab=="OBCHOD":
		call_deferred("_open_shop")
	elif tab=="FIRMA":
		render_company()
	else:
		render_placeholder(tab)

func _open_shop() -> void:
	var shop := get_node_or_null("/root/ShopUI")
	if shop != null and shop.has_method("_render_shop"):
		shop.call("_render_shop")
	else:
		render_placeholder("OBCHOD")

func render_company() -> void:
	var panel:=PanelContainer.new()
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",panel_style("#211914","#6b4628",7,1))
	content_host.add_child(panel)
	var box:=VBoxContainer.new()
	box.alignment=BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation",10)
	panel.add_child(box)
	var title:=make_label("FIRMA",32)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color",Color("#ffca42"))
	box.add_child(title)
	var info:=make_label("Firemní záložka je připravená jako samostatná obrazovka.\nObsah firmy doplníme zvlášť, práce už se sem nepřekresluje.",17)
	info.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info)

func render_work() -> void:
	var center:=PanelContainer.new(); center.size_flags_horizontal=Control.SIZE_EXPAND_FILL; center.size_flags_vertical=Control.SIZE_EXPAND_FILL; center.add_theme_stylebox_override("panel",panel_style("#6f5a3f","#8b5d32",0,1)); content_host.add_child(center)
	var scene:=Control.new(); scene.custom_minimum_size=Vector2(760,560); center.add_child(scene)
	var sky:=ColorRect.new(); sky.color=Color("#a8c2cb"); sky.anchor_right=1.0; sky.anchor_bottom=0.34; scene.add_child(sky)
	var grass:=ColorRect.new(); grass.color=Color("#95a184"); grass.anchor_top=0.34; grass.anchor_right=1.0; grass.anchor_bottom=0.54; scene.add_child(grass)
	var dirt:=ColorRect.new(); dirt.color=Color("#735f44"); dirt.anchor_top=0.54; dirt.anchor_right=1.0; dirt.anchor_bottom=1.0; scene.add_child(dirt)
	var frame:=ColorRect.new(); frame.color=Color("#5b5047"); frame.position=Vector2(690,100); frame.size=Vector2(180,145); scene.add_child(frame)
	var door:=ColorRect.new(); door.color=Color("#292522"); door.position=Vector2(713,129); door.size=Vector2(132,92); scene.add_child(door)
	for i in range(4):
		var log:=ColorRect.new(); log.color=Color("#8a5528"); log.position=Vector2(80+i*32,390-(i%2)*24); log.size=Vector2(74,22); scene.add_child(log)
	var player:=TextureRect.new(); player.position=Vector2(335,205); player.size=Vector2(220,250); player.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; player.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; player.texture=load_player_texture(); scene.add_child(player)
	var stump:=ColorRect.new(); stump.color=Color("#75451f"); stump.position=Vector2(405,430); stump.size=Vector2(120,52); scene.add_child(stump)
	var actions:=VBoxContainer.new(); actions.position=Vector2(205,455); actions.size=Vector2(500,110); actions.add_theme_constant_override("separation",8); scene.add_child(actions)
	chop_button=Button.new(); chop_button.text="SEKNOUT"; chop_button.custom_minimum_size.y=66; chop_button.add_theme_font_size_override("font_size",26); chop_button.add_theme_stylebox_override("normal",panel_style("#5d8615","#8eb33c",7,2)); chop_button.add_theme_stylebox_override("hover",panel_style("#6f991d","#a8cc55",7,2)); chop_button.pressed.connect(start_chop); actions.add_child(chop_button)
	var timer_panel:=PanelContainer.new(); timer_panel.add_theme_stylebox_override("panel",panel_style("#171411","#5b422c",5,1)); actions.add_child(timer_panel)
	var tm:=MarginContainer.new(); tm.add_theme_constant_override("margin_left",12); tm.add_theme_constant_override("margin_right",12); tm.add_theme_constant_override("margin_top",8); tm.add_theme_constant_override("margin_bottom",8); timer_panel.add_child(tm)
	var tv:=VBoxContainer.new(); tm.add_child(tv); timer_label=make_label(timer_text(),15); timer_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; tv.add_child(timer_label)
	progress=ProgressBar.new(); progress.max_value=axe_time(); progress.value=0.0; progress.show_percentage=false; progress.custom_minimum_size.y=13; tv.add_child(progress)

func render_placeholder(tab:String) -> void:
	var panel:=PanelContainer.new(); panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL; panel.size_flags_vertical=Control.SIZE_EXPAND_FILL; panel.add_theme_stylebox_override("panel",panel_style("#211914")); content_host.add_child(panel)
	var label:=make_label(tab,30); label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; panel.add_child(label)

func load_player_texture() -> Texture2D:
	var path:="res://assets/characters/player_wood_1.png"
	if str(state["equipped_axe"])=="sharpened": path="res://assets/characters/player_sharp_1.png"
	if ResourceLoader.exists(path):
		var r:=ResourceLoader.load(path)
		if r is Texture2D: return r as Texture2D
	return null

func axe_time() -> float:
	match str(state.get("equipped_axe", "wooden")):
		"checht": return CHECHT_AXE_TIME
		"sharpened": return SHARPENED_AXE_TIME
		_: return WOODEN_AXE_TIME

func timer_text() -> String:
	var name:="Tupá sekera"
	if str(state.get("equipped_axe", "wooden"))=="sharpened": name="Nabroušená sekera"
	elif str(state.get("equipped_axe", "wooden"))=="checht": name="Štípací sekera CHECHT"
	return "%s  –  %.1f s / sek" % [name,axe_time()]

func start_chop() -> void:
	if action_running:
		return
	action_running=true
	action_elapsed=0.0
	action_duration=axe_time()
	progress.max_value=action_duration
	progress.value=0.0
	chop_button.disabled=true
	chop_button.text="SEKÁM..."

func finish_chop() -> void:
	action_running=false
	if is_instance_valid(chop_button):
		chop_button.disabled=false
		chop_button.text="SEKNOUT"
	if is_instance_valid(progress): progress.value=0.0
	if is_instance_valid(timer_label): timer_label.text=timer_text()
	save_game()
	update_hud()

func _process(delta:float) -> void:
	if action_running:
		action_elapsed+=delta
		if is_instance_valid(progress): progress.value=action_elapsed
		if is_instance_valid(timer_label): timer_label.text="%.1f s" % maxf(0.0,action_duration-action_elapsed)
		if action_elapsed>=action_duration: finish_chop()
	save_elapsed+=delta
	if save_elapsed>=5.0: save_elapsed=0.0; save_game()

func update_hud() -> void:
	if is_instance_valid(money_label): money_label.text="%.0f Kč\nPeníze" % float(state["money"])
	if is_instance_valid(logs_label): logs_label.text="%.3f m³\nKulatina" % float(state["logs_m3"])
	if is_instance_valid(roundwood_label): roundwood_label.text="%.3f m³\nŠpalky" % float(state["roundwood_m3"])
	if is_instance_valid(split_label): split_label.text="%.3f m³\nŠtípané dřevo" % float(state["split_m3"])
	if is_instance_valid(role_label): role_label.text="Pomocník ve dřevárně"
	if is_instance_valid(xp_label): xp_label.text="%d XP" % int(state["xp"])

func save_game() -> void:
	var f:=FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	if f!=null: f.store_string(JSON.stringify(state))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var f:=FileAccess.open(SAVE_PATH,FileAccess.READ)
	if f==null: return
	var parsed=JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		for key in state.keys():
			if parsed.has(key): state[key]=parsed[key]
