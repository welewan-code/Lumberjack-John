extends Control

const SAVE_PATH: String = "user://drevo_tycoon_save.json"
const STORAGE_CAPACITY: float = 10.0
const AXE_IN: float = 0.010
const AXE_OUT: float = 0.015
const WOODEN_AXE_TIME: float = 1.8
const SHARPENED_AXE_TIME: float = 1.6
const FRAME_SAW_CYCLE: float = 20.0

var state: Dictionary = {
    "money": 0.0,
    "xp": 0,
    "level": 0,
    "logs_m3": 0.0,
    "roundwood_m3": 0.0,
    "split_m3": 0.0,
    "wooden_axe_qty": 0,
    "sharpened_axe_qty": 0,
    "frame_saw_qty": 0,
    "aku_saw_qty": 0,
    "wheelbarrow_qty": 0,
    "equipped_axe": "wooden",
    "splitter_tool": "",
    "sawyer_tool": "",
    "employed": true,
    "current_job": "helper",
    "work_clicks": 0,
    "home_clicks": 0,
    "overtime_clicks": 0
}

var current_tab: String = "FIRMA"
var page_host: MarginContainer
var hud_money: Label
var hud_storage: Label
var status_label: Label
var timer_label: Label
var action_progress: ProgressBar
var split_button: Button
var player_texture: TextureRect

var action_running: bool = false
var action_elapsed: float = 0.0
var action_duration: float = WOODEN_AXE_TIME
var save_elapsed: float = 0.0

func _ready() -> void:
    load_game()
    _build_shell()
    show_tab("FIRMA")
    update_hud()

func _build_shell() -> void:
    var background: ColorRect = ColorRect.new()
    background.color = Color("#1d1712")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)

    var root: VBoxContainer = VBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("separation", 0)
    add_child(root)

    var top_bar: PanelContainer = PanelContainer.new()
    top_bar.custom_minimum_size.y = 66
    root.add_child(top_bar)

    var top_margin: MarginContainer = MarginContainer.new()
    top_margin.add_theme_constant_override("margin_left", 22)
    top_margin.add_theme_constant_override("margin_right", 22)
    top_margin.add_theme_constant_override("margin_top", 10)
    top_margin.add_theme_constant_override("margin_bottom", 10)
    top_bar.add_child(top_margin)

    var top_row: HBoxContainer = HBoxContainer.new()
    top_row.add_theme_constant_override("separation", 28)
    top_margin.add_child(top_row)

    var title: Label = Label.new()
    title.text = "LUMBERJACK JOHN"
    title.add_theme_font_size_override("font_size", 24)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_row.add_child(title)

    hud_money = Label.new()
    hud_money.add_theme_font_size_override("font_size", 18)
    top_row.add_child(hud_money)

    hud_storage = Label.new()
    hud_storage.add_theme_font_size_override("font_size", 18)
    top_row.add_child(hud_storage)

    var body: HBoxContainer = HBoxContainer.new()
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 0)
    root.add_child(body)

    var menu_panel: PanelContainer = PanelContainer.new()
    menu_panel.custom_minimum_size.x = 210
    body.add_child(menu_panel)

    var menu_margin: MarginContainer = MarginContainer.new()
    menu_margin.add_theme_constant_override("margin_left", 14)
    menu_margin.add_theme_constant_override("margin_right", 14)
    menu_margin.add_theme_constant_override("margin_top", 18)
    menu_margin.add_theme_constant_override("margin_bottom", 18)
    menu_panel.add_child(menu_margin)

    var menu: VBoxContainer = VBoxContainer.new()
    menu.add_theme_constant_override("separation", 10)
    menu_margin.add_child(menu)

    _menu_button(menu, "FIRMA", "FIRMA")
    _menu_button(menu, "PRÁCE", "PRÁCE")
    _menu_button(menu, "OBCHOD", "OBCHOD")
    _menu_button(menu, "SKLAD", "SKLAD")

    var spacer: Control = Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    menu.add_child(spacer)

    var version_note: Label = Label.new()
    version_note.text = "základ rozhraní"
    version_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    version_note.modulate = Color(1, 1, 1, 0.55)
    menu.add_child(version_note)

    page_host = MarginContainer.new()
    page_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    page_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
    page_host.add_theme_constant_override("margin_left", 18)
    page_host.add_theme_constant_override("margin_right", 18)
    page_host.add_theme_constant_override("margin_top", 18)
    page_host.add_theme_constant_override("margin_bottom", 18)
    body.add_child(page_host)

    var bottom: PanelContainer = PanelContainer.new()
    bottom.custom_minimum_size.y = 42
    root.add_child(bottom)

    status_label = Label.new()
    status_label.text = "Připraveno."
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    bottom.add_child(status_label)

func _menu_button(parent: VBoxContainer, text: String, tab: String) -> void:
    var button: Button = Button.new()
    button.text = text
    button.custom_minimum_size = Vector2(180, 52)
    button.add_theme_font_size_override("font_size", 18)
    button.pressed.connect(show_tab.bind(tab))
    parent.add_child(button)

func _clear_page() -> void:
    for child: Node in page_host.get_children():
        child.queue_free()

func show_tab(tab: String) -> void:
    current_tab = tab
    _clear_page()
    match tab:
        "FIRMA": _render_firma()
        "PRÁCE": _render_placeholder("PRÁCE", "Tady později přesuneme pracovní směny a zaměstnání.")
        "OBCHOD": _render_placeholder("OBCHOD", "Tady později přesuneme nákup nářadí a materiálu.")
        "SKLAD": _render_placeholder("SKLAD", "Tady později přesuneme sklad a přehled vybavení.")
    update_hud()

func _render_firma() -> void:
    var page: VBoxContainer = VBoxContainer.new()
    page.add_theme_constant_override("separation", 12)
    page_host.add_child(page)

    var heading: Label = Label.new()
    heading.text = "FIRMA — DOMÁCÍ ZAHRADA"
    heading.add_theme_font_size_override("font_size", 27)
    page.add_child(heading)

    var sub: Label = Label.new()
    sub.text = "Špalky %.3f m³   •   Naštípané %.3f m³" % [float(state["logs_m3"]), float(state["split_m3"])]
    sub.modulate = Color(1, 1, 1, 0.72)
    page.add_child(sub)

    var yard_panel: PanelContainer = PanelContainer.new()
    yard_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    page.add_child(yard_panel)

    var yard: Control = Control.new()
    yard.custom_minimum_size = Vector2(0, 430)
    yard_panel.add_child(yard)

    var yard_bg: ColorRect = ColorRect.new()
    yard_bg.color = Color("#5b7140")
    yard_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    yard.add_child(yard_bg)

    var ground: ColorRect = ColorRect.new()
    ground.color = Color("#796346")
    ground.anchor_left = 0.0
    ground.anchor_top = 0.68
    ground.anchor_right = 1.0
    ground.anchor_bottom = 1.0
    yard.add_child(ground)

    var shed: PanelContainer = PanelContainer.new()
    shed.position = Vector2(38, 34)
    shed.size = Vector2(210, 120)
    yard.add_child(shed)
    var shed_label: Label = Label.new()
    shed_label.text = "DOMÁCÍ DŘEVÁRNA\n\npozději sem dáme\nbaráček / přístřešek"
    shed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    shed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    shed.add_child(shed_label)

    var stack_label: Label = Label.new()
    stack_label.text = "🪵  🪵  🪵\nzásoba špalků"
    stack_label.position = Vector2(52, 295)
    stack_label.add_theme_font_size_override("font_size", 22)
    yard.add_child(stack_label)

    var work_zone: VBoxContainer = VBoxContainer.new()
    work_zone.position = Vector2(470, 60)
    work_zone.size = Vector2(350, 330)
    work_zone.alignment = BoxContainer.ALIGNMENT_CENTER
    yard.add_child(work_zone)

    var role: Label = Label.new()
    role.text = "TY — RUČNÍ ŠTÍPÁNÍ"
    role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    role.add_theme_font_size_override("font_size", 19)
    work_zone.add_child(role)

    player_texture = TextureRect.new()
    player_texture.custom_minimum_size = Vector2(230, 210)
    player_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    player_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    player_texture.texture = _load_texture_for_axe()
    work_zone.add_child(player_texture)

    if player_texture.texture == null:
        var fallback: Label = Label.new()
        fallback.text = "🧔\n🪓   🪵"
        fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        fallback.add_theme_font_size_override("font_size", 42)
        work_zone.add_child(fallback)

    var stump: Label = Label.new()
    stump.text = "🪵  špalek"
    stump.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stump.add_theme_font_size_override("font_size", 24)
    work_zone.add_child(stump)

    var action_panel: PanelContainer = PanelContainer.new()
    page.add_child(action_panel)

    var action_margin: MarginContainer = MarginContainer.new()
    action_margin.add_theme_constant_override("margin_left", 14)
    action_margin.add_theme_constant_override("margin_right", 14)
    action_margin.add_theme_constant_override("margin_top", 12)
    action_margin.add_theme_constant_override("margin_bottom", 12)
    action_panel.add_child(action_margin)

    var action_row: HBoxContainer = HBoxContainer.new()
    action_row.add_theme_constant_override("separation", 14)
    action_margin.add_child(action_row)

    split_button = Button.new()
    split_button.text = "ŠTÍPAT"
    split_button.custom_minimum_size = Vector2(220, 58)
    split_button.add_theme_font_size_override("font_size", 22)
    split_button.pressed.connect(_start_manual_split)
    action_row.add_child(split_button)

    var timing: VBoxContainer = VBoxContainer.new()
    timing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    action_row.add_child(timing)

    timer_label = Label.new()
    timer_label.text = _timer_text()
    timer_label.add_theme_font_size_override("font_size", 17)
    timing.add_child(timer_label)

    action_progress = ProgressBar.new()
    action_progress.min_value = 0.0
    action_progress.max_value = _axe_time()
    action_progress.value = 0.0
    action_progress.show_percentage = false
    action_progress.custom_minimum_size.y = 20
    timing.add_child(action_progress)

    var hint: Label = Label.new()
    hint.text = "Klik → čas podle sekery → hotový sek. Později sem jen přesuneme další ovládací prvky."
    hint.modulate = Color(1, 1, 1, 0.62)
    timing.add_child(hint)

func _render_placeholder(title_text: String, body_text: String) -> void:
    var panel: PanelContainer = PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    page_host.add_child(panel)

    var box: VBoxContainer = VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    panel.add_child(box)

    var title: Label = Label.new()
    title.text = title_text
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 30)
    box.add_child(title)

    var body: Label = Label.new()
    body.text = body_text
    body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    body.add_theme_font_size_override("font_size", 18)
    box.add_child(body)

func _load_texture_for_axe() -> Texture2D:
    var path: String = "res://assets/characters/player_wood_1.png"
    if str(state["equipped_axe"]) == "sharpened":
        path = "res://assets/characters/player_sharp_1.png"
    if ResourceLoader.exists(path):
        var resource: Resource = ResourceLoader.load(path)
        if resource is Texture2D:
            return resource as Texture2D
    return null

func _axe_time() -> float:
    if str(state["equipped_axe"]) == "sharpened":
        return SHARPENED_AXE_TIME
    return WOODEN_AXE_TIME

func _timer_text() -> String:
    var axe_name: String = "Tupá sekera"
    if str(state["equipped_axe"]) == "sharpened":
        axe_name = "Nabroušená sekera"
    return "%s  •  %.1f s / sek" % [axe_name, _axe_time()]

func _start_manual_split() -> void:
    if action_running:
        return
    if float(state["logs_m3"]) + 0.000001 < AXE_IN:
        _say("Nemáš dost špalků. Pro rychlý test spusť TESTOVAT.bat.")
        return
    if _free_storage() + AXE_IN + 0.000001 < AXE_OUT:
        _say("Sklad je plný.")
        return
    if _available_player_axe() == "":
        _say("Nemáš volnou sekeru.")
        return

    action_running = true
    action_elapsed = 0.0
    action_duration = _axe_time()
    if action_progress != null:
        action_progress.max_value = action_duration
        action_progress.value = 0.0
    if split_button != null:
        split_button.disabled = true
        split_button.text = "ŠTÍPÁM…"
    _say("Štípání začalo.")

func _finish_manual_split() -> void:
    action_running = false
    state["logs_m3"] = float(state["logs_m3"]) - AXE_IN
    state["split_m3"] = float(state["split_m3"]) + AXE_OUT
    save_game()
    _say("Hotovo: +0,015 m³ štípaného.")
    show_tab("FIRMA")

func _available_player_axe() -> String:
    if str(state["equipped_axe"]) == "sharpened" and int(state["sharpened_axe_qty"]) > 0:
        return "sharpened"
    if int(state["wooden_axe_qty"]) > 0:
        state["equipped_axe"] = "wooden"
        return "wooden"
    if int(state["sharpened_axe_qty"]) > 0:
        state["equipped_axe"] = "sharpened"
        return "sharpened"
    return ""

func _process(delta: float) -> void:
    if action_running:
        action_elapsed += delta
        if action_progress != null:
            action_progress.value = minf(action_elapsed, action_duration)
        if timer_label != null:
            var left: float = maxf(0.0, action_duration - action_elapsed)
            timer_label.text = "Sekera pracuje… %.1f s" % left
        if action_elapsed >= action_duration:
            _finish_manual_split()

    save_elapsed += delta
    if save_elapsed >= 5.0:
        save_elapsed = 0.0
        save_game()
    update_hud()

func update_hud() -> void:
    if hud_money != null:
        hud_money.text = "PENÍZE  %.0f Kč" % float(state["money"])
    if hud_storage != null:
        hud_storage.text = "SKLAD  %.3f / %.1f m³" % [_total_stored(), STORAGE_CAPACITY]

func _say(text: String) -> void:
    if status_label != null:
        status_label.text = text

func _total_stored() -> float:
    return float(state["logs_m3"]) + float(state["roundwood_m3"]) + float(state["split_m3"])

func _free_storage() -> float:
    return STORAGE_CAPACITY - _total_stored()

# Tyhle dvě funkce necháváme kvůli offline_manager.gd, aby projekt zůstal kompatibilní.
func do_splitter_cycle() -> bool:
    if float(state["logs_m3"]) + 0.000001 < AXE_IN:
        return false
    if _free_storage() + AXE_IN + 0.000001 < AXE_OUT:
        return false
    state["logs_m3"] = float(state["logs_m3"]) - AXE_IN
    state["split_m3"] = float(state["split_m3"]) + AXE_OUT
    return true

func do_sawyer_cycle() -> bool:
    return false

func save_game() -> void:
    var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(state))

func load_game() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        var loaded: Dictionary = parsed as Dictionary
        for key: Variant in loaded.keys():
            state[key] = loaded[key]
