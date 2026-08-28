extends Control

const SAVE_PATH: String = "user://drevo_tycoon_save.json"
const STORAGE_CAPACITY: float = 10.0
const LOGS_PRICE: float = 1100.0
const ROUNDWOOD_PRICE: float = 1200.0
const SPLIT_SALE_PRICE: float = 1100.0
const AXE_IN: float = 0.010
const AXE_OUT: float = 0.015
const SAW_IN: float = 0.025
const SAW_OUT: float = SAW_IN * 4.0 / 3.0
const SPLITTER_WAGE: float = 2.0
const SAWYER_WAGE: float = 3.0
const FRAME_SAW_CYCLE: float = 20.0
const AKU_SAW_CYCLE: float = 14.0

const LEVEL_XP: Array[int] = [0,100,250,450,700,1000,1400,1900,2500,3200,4000]
const JOBS: Dictionary = {
    "helper": {"name":"Pomocník ve dřevárně","pay":[1,3],"xp":[1,5]},
    "splitter": {"name":"Štípač dřeva","pay":[3,6],"xp":[2,6]},
    "warehouse": {"name":"Skladník dřeva","pay":[4,7],"xp":[3,7]},
    "sawmill": {"name":"Obsluha pily","pay":[6,9],"xp":[4,8]},
    "logger": {"name":"Dřevorubec","pay":[8,12],"xp":[5,9]},
    "driver": {"name":"Řidič","pay":[10,14],"xp":[6,10]}
}

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

var content: VBoxContainer
var hud_money: Label
var hud_wood: Label
var hud_level: Label
var message_label: Label
var current_tab: String = "FIRMA"
var manual_ready_at: int = 0
var splitter_accum: float = 0.0
var sawyer_accum: float = 0.0
var save_accum: float = 0.0
var picker_worker: String = ""
var picker_map: Dictionary = {}
var tool_picker: PopupMenu
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
    rng.randomize()
    load_game()
    build_ui()
    show_tab("FIRMA")
    update_hud()

func build_ui() -> void:
    var bg: ColorRect = ColorRect.new()
    bg.color = Color("2b241d")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    var root: VBoxContainer = VBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("separation", 8)
    add_child(root)

    var top: HBoxContainer = HBoxContainer.new()
    top.custom_minimum_size.y = 54
    top.add_theme_constant_override("separation", 20)
    root.add_child(top)

    var title: Label = Label.new()
    title.text = "  LUMBERJACK JOHN / DŘEVO TYCOON"
    title.add_theme_font_size_override("font_size", 22)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(title)

    hud_level = Label.new()
    top.add_child(hud_level)
    hud_money = Label.new()
    top.add_child(hud_money)
    hud_wood = Label.new()
    top.add_child(hud_wood)

    message_label = Label.new()
    message_label.text = "Godot verze je připravená."
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root.add_child(message_label)

    var panel: PanelContainer = PanelContainer.new()
    panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    root.add_child(panel)

    var margin: MarginContainer = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 18)
    margin.add_theme_constant_override("margin_right", 18)
    margin.add_theme_constant_override("margin_top", 12)
    margin.add_theme_constant_override("margin_bottom", 12)
    panel.add_child(margin)

    content = VBoxContainer.new()
    content.add_theme_constant_override("separation", 10)
    margin.add_child(content)

    var nav: HBoxContainer = HBoxContainer.new()
    nav.alignment = BoxContainer.ALIGNMENT_CENTER
    nav.custom_minimum_size.y = 64
    root.add_child(nav)
    for tab_value: String in ["FIRMA","PRÁCE","OBCHOD","SKLAD"]:
        var button: Button = Button.new()
        button.text = tab_value
        button.custom_minimum_size = Vector2(170,48)
        button.pressed.connect(show_tab.bind(tab_value))
        nav.add_child(button)

    tool_picker = PopupMenu.new()
    tool_picker.id_pressed.connect(on_tool_picked)
    add_child(tool_picker)

func clear_content() -> void:
    for child: Node in content.get_children():
        child.queue_free()

func show_tab(tab: String) -> void:
    current_tab = tab
    clear_content()
    match tab:
        "FIRMA": render_firma()
        "PRÁCE": render_prace()
        "OBCHOD": render_obchod()
        "SKLAD": render_sklad()
    update_hud()

func add_header(text: String) -> void:
    var label: Label = Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", 28)
    content.add_child(label)

func add_info(text: String, parent: Node = null) -> Label:
    var label: Label = Label.new()
    label.text = text
    if parent == null:
        content.add_child(label)
    else:
        parent.add_child(label)
    return label

func make_button(text: String, callback: Callable, parent: Node = null) -> Button:
    var button: Button = Button.new()
    button.text = text
    button.custom_minimum_size = Vector2(0,44)
    button.pressed.connect(callback)
    if parent == null:
        content.add_child(button)
    else:
        parent.add_child(button)
    return button

func render_firma() -> void:
    add_header("FIRMA — zahrada")
    add_info("Špalky: %.3f m³   |   Kulatina: %.3f m³   |   Naštípané: %.3f m³" % [float(state["logs_m3"]), float(state["roundwood_m3"]), float(state["split_m3"])])
    add_info("Sklad: %.3f / %.1f m³" % [total_stored(), STORAGE_CAPACITY])

    var yard: HBoxContainer = HBoxContainer.new()
    yard.size_flags_vertical = Control.SIZE_EXPAND_FILL
    yard.add_theme_constant_override("separation", 16)
    content.add_child(yard)

    var production: VBoxContainer = VBoxContainer.new()
    production.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    yard.add_child(production)
    add_info("VLASTNÍ PRÁCE", production).add_theme_font_size_override("font_size",20)
    make_button("🪓 ŠTÍPNOUT ŠPALEK", manual_split, production)
    make_button("PRODAT 0,1 m³ ŠTÍPANÉHO = 110 Kč", sell_split, production)
    add_info("Každý tvůj sek: -0,010 m³ špalků → +0,015 m³ štípaného.", production)

    var workers: VBoxContainer = VBoxContainer.new()
    workers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    yard.add_child(workers)
    add_info("VÝPOMOC OD KAMARÁDŮ", workers).add_theme_font_size_override("font_size",20)

    var saw_text: String = "+  PILAŘ — vyber pilu"
    if str(state["sawyer_tool"]) != "":
        saw_text = "👷🪚 PILAŘ — %s" % tool_name(str(state["sawyer_tool"]))
    make_button(saw_text, open_tool_picker.bind("sawyer"), workers)
    add_info("Rámovka: 20 s / cyklus. Aku pila z eshopu: 14 s / cyklus. Mzda pilaře 3 Kč / cyklus.", workers)

    var split_text: String = "+  ŠTÍPAČ — vyber sekeru"
    if str(state["splitter_tool"]) != "":
        split_text = "👷🪓 ŠTÍPAČ — %s" % tool_name(str(state["splitter_tool"]))
    make_button(split_text, open_tool_picker.bind("splitter"), workers)
    add_info("Štípač: -2 Kč za sek. Rychlost podle přidělené sekery.", workers)

func render_prace() -> void:
    add_header("PRÁCE")
    if not bool(state["employed"]):
        add_info("Momentálně jsi bez práce.")
        make_button("VRÁTIT SE JAKO POMOCNÍK", return_to_work)
        return
    var job: Dictionary = JOBS.get(str(state["current_job"]), JOBS["helper"])
    add_info("Pozice: %s" % str(job["name"]))
    add_info("Výdělek: %d–%d Kč / akce   |   XP: %d–%d" % [int(job["pay"][0]), int(job["pay"][1]), int(job["xp"][0]), int(job["xp"][1])])
    add_info("Směna: %d / 8   |   volné akce po směně: %d / 2" % [int(state["work_clicks"]), int(state["home_clicks"]) + int(state["overtime_clicks"])])
    make_button("PRACOVAT", work_action)
    if int(state["work_clicks"]) >= 8:
        make_button("PŘESČAS +20 %", overtime_action)
    make_button("ODEJÍT Z PRÁCE", quit_job)

func render_obchod() -> void:
    add_header("OBCHOD")
    add_info("VYBAVENÍ")
    make_button("Tupá dřevěná sekera — 100 Kč   (máš %d)" % int(state["wooden_axe_qty"]), buy_tool.bind("wooden"))
    make_button("Nabroušená sekera — 150 Kč   (máš %d)" % int(state["sharpened_axe_qty"]), buy_tool.bind("sharpened"))
    make_button("Rezavá rámovka — 80 Kč   (máš %d)" % int(state["frame_saw_qty"]), buy_tool.bind("frameSaw"))
    make_button("Aku pila z eshopu — 800 Kč   (máš %d)" % int(state["aku_saw_qty"]), buy_tool.bind("akuSaw"))
    make_button("Děravé kolečko — 120 Kč   (máš %d)" % int(state["wheelbarrow_qty"]), buy_tool.bind("wheelbarrow"))
    add_info("")
    add_info("DŘEVO")
    make_button("Koupit 1 m³ špalků — 1 100 Kč", buy_material.bind("logs"))
    make_button("Koupit 1 m³ měkké kulatiny — 1 200 Kč", buy_material.bind("roundwood"))

func render_sklad() -> void:
    add_header("SKLAD")
    add_info("Kapacita: %.3f / %.1f m³" % [total_stored(), STORAGE_CAPACITY])
    add_info("Špalky: %.3f m³" % float(state["logs_m3"]))
    add_info("Kulatina: %.3f m³" % float(state["roundwood_m3"]))
    add_info("Naštípané dřevo: %.3f m³" % float(state["split_m3"]))
    add_info("")
    add_info("NÁŘADÍ")
    add_info("Tupá sekera: %d   |   Nabroušená: %d   |   Rámovka: %d   |   Aku pila: %d   |   Kolečko: %d" % [int(state["wooden_axe_qty"]), int(state["sharpened_axe_qty"]), int(state["frame_saw_qty"]), int(state["aku_saw_qty"]), int(state["wheelbarrow_qty"])])
    add_info("Štípač má: %s" % (tool_name(str(state["splitter_tool"])) if str(state["splitter_tool"]) != "" else "nic"))
    add_info("Pilař má: %s" % (tool_name(str(state["sawyer_tool"])) if str(state["sawyer_tool"]) != "" else "nic"))

func total_stored() -> float:
    return float(state["logs_m3"]) + float(state["roundwood_m3"]) + float(state["split_m3"])

func free_storage() -> float:
    return STORAGE_CAPACITY - total_stored()

func tool_name(tool: String) -> String:
    match tool:
        "wooden": return "Tupá dřevěná sekera"
        "sharpened": return "Nabroušená sekera"
        "frameSaw": return "Rezavá rámovka"
        "akuSaw": return "Aku pila z eshopu"
    return ""

func tool_qty(tool: String) -> int:
    match tool:
        "wooden": return int(state["wooden_axe_qty"])
        "sharpened": return int(state["sharpened_axe_qty"])
        "frameSaw": return int(state["frame_saw_qty"])
        "akuSaw": return int(state["aku_saw_qty"])
    return 0

func assigned_count(tool: String) -> int:
    var count: int = 0
    if str(state["splitter_tool"]) == tool:
        count += 1
    if str(state["sawyer_tool"]) == tool:
        count += 1
    return count

func free_tool_count(tool: String) -> int:
    return maxi(0, tool_qty(tool) - assigned_count(tool))

func open_tool_picker(worker: String) -> void:
    picker_worker = worker
    picker_map.clear()
    tool_picker.clear()
    var item_id: int = 1
    if worker == "splitter":
        for tool: String in ["wooden","sharpened"]:
            if free_tool_count(tool) > 0:
                tool_picker.add_item(tool_name(tool), item_id)
                picker_map[item_id] = tool
                item_id += 1
    else:
        for tool: String in ["frameSaw", "akuSaw"]:
            if free_tool_count(tool) > 0:
                tool_picker.add_item(tool_name(tool), item_id)
                picker_map[item_id] = tool
                item_id += 1

    var current: String = str(state["splitter_tool"]) if worker == "splitter" else str(state["sawyer_tool"])
    if current != "":
        tool_picker.add_separator()
        tool_picker.add_item("ODEBRAT NÁSTROJ", 99)
        picker_map[99] = "REMOVE"
    if picker_map.is_empty():
        tool_picker.add_item("Žádný volný vhodný nástroj", 50)
        var disabled_index: int = tool_picker.get_item_index(50)
        if disabled_index >= 0:
            tool_picker.set_item_disabled(disabled_index, true)
    tool_picker.popup_centered(Vector2i(430,0))

func on_tool_picked(id: int) -> void:
    if not picker_map.has(id):
        return
    var tool: String = str(picker_map[id])
    if tool == "REMOVE":
        if picker_worker == "splitter":
            state["splitter_tool"] = ""
        else:
            state["sawyer_tool"] = ""
        say("Nástroj vrácen do skladu.")
    else:
        if picker_worker == "splitter":
            state["splitter_tool"] = tool
        else:
            state["sawyer_tool"] = tool
        var worker_name: String = "Štípač" if picker_worker == "splitter" else "Pilař"
        say("%s dostal %s." % [worker_name, tool_name(tool)])
    save_game()
    show_tab("FIRMA")

func player_axe() -> String:
    var preferred: String = str(state["equipped_axe"])
    if preferred in ["wooden","sharpened"] and free_tool_count(preferred) > 0:
        return preferred
    if free_tool_count("sharpened") > 0:
        return "sharpened"
    if free_tool_count("wooden") > 0:
        return "wooden"
    return ""

func manual_split() -> void:
    if bool(state["employed"]) and int(state["work_clicks"]) < 8:
        say("Nejdřív dokonči 8 pracovních akcí. Pak máš 2 volné akce doma nebo přesčas.")
        return
    if bool(state["employed"]) and int(state["home_clicks"]) + int(state["overtime_clicks"]) >= 2:
        reset_shift()
        say("Volno skončilo. Zase musíš do práce.")
        show_tab("FIRMA")
        return
    var axe: String = player_axe()
    if axe == "":
        say("Nemáš volnou sekeru. Pokud ji má brigádník, potřebuješ druhou.")
        return
    var now: int = Time.get_ticks_msec()
    if now < manual_ready_at:
        say("Sekera ještě není připravená.")
        return
    if float(state["logs_m3"]) + 0.000001 < AXE_IN:
        say("Nemáš dost špalků.")
        return
    if free_storage() + AXE_IN + 0.000001 < AXE_OUT:
        say("Sklad je plný.")
        return
    state["logs_m3"] = float(state["logs_m3"]) - AXE_IN
    state["split_m3"] = float(state["split_m3"]) + AXE_OUT
    manual_ready_at = now + (1600 if axe == "sharpened" else 1800)
    if bool(state["employed"]):
        state["home_clicks"] = int(state["home_clicks"]) + 1
        finish_bonus_if_needed()
    say("Štípnuto: +0,015 m³.")
    save_game()
    show_tab("FIRMA")

func sell_split() -> void:
    if float(state["split_m3"]) + 0.000001 < 0.1:
        say("Nemáš 0,1 m³ štípaného dřeva.")
        return
    state["split_m3"] = float(state["split_m3"]) - 0.1
    state["money"] = float(state["money"]) + 110.0
    say("Prodáno 0,1 m³ za 110 Kč.")
    save_game()
    show_tab("FIRMA")

func buy_tool(tool: String) -> void:
    var price: float = 0.0
    match tool:
        "wooden": price = 100.0
        "sharpened": price = 150.0
        "frameSaw": price = 80.0
        "akuSaw": price = 800.0
        "wheelbarrow": price = 120.0
    if float(state["money"]) < price:
        say("Nemáš dost peněz.")
        return
    if tool == "sharpened" and int(state["wooden_axe_qty"]) < 1:
        say("Nejdřív kup tupou dřevěnou sekeru.")
        return
    state["money"] = float(state["money"]) - price
    match tool:
        "wooden": state["wooden_axe_qty"] = int(state["wooden_axe_qty"]) + 1
        "sharpened": state["sharpened_axe_qty"] = int(state["sharpened_axe_qty"]) + 1
        "frameSaw": state["frame_saw_qty"] = int(state["frame_saw_qty"]) + 1
        "akuSaw": state["aku_saw_qty"] = int(state["aku_saw_qty"]) + 1
        "wheelbarrow": state["wheelbarrow_qty"] = int(state["wheelbarrow_qty"]) + 1
    say("Nářadí koupeno.")
    save_game()
    show_tab("OBCHOD")

func buy_material(kind: String) -> void:
    if free_storage() < 0.999999:
        say("Ve skladu není místo na 1 m³.")
        return
    var price: float = LOGS_PRICE if kind == "logs" else ROUNDWOOD_PRICE
    if float(state["money"]) < price:
        say("Nemáš dost peněz.")
        return
    state["money"] = float(state["money"]) - price
    if kind == "logs":
        state["logs_m3"] = float(state["logs_m3"]) + 1.0
    else:
        state["roundwood_m3"] = float(state["roundwood_m3"]) + 1.0
    say("Materiál koupen.")
    save_game()
    show_tab("OBCHOD")

func work_action() -> void:
    if not bool(state["employed"]):
        return
    if int(state["work_clicks"]) >= 8:
        say("Směna hotová. Máš 2 volné akce: doma nebo přesčas.")
        return
    var job: Dictionary = JOBS.get(str(state["current_job"]), JOBS["helper"])
    var pay: int = rng.randi_range(int(job["pay"][0]), int(job["pay"][1]))
    var xp_gain: int = rng.randi_range(int(job["xp"][0]), int(job["xp"][1]))
    state["money"] = float(state["money"]) + pay
    state["xp"] = int(state["xp"]) + xp_gain
    state["work_clicks"] = int(state["work_clicks"]) + 1
    sync_level()
    say("Práce: +%d Kč, +%d XP." % [pay,xp_gain])
    save_game()
    show_tab("PRÁCE")

func overtime_action() -> void:
    if not bool(state["employed"]) or int(state["work_clicks"]) < 8:
        return
    if int(state["home_clicks"]) + int(state["overtime_clicks"]) >= 2:
        reset_shift()
        show_tab("PRÁCE")
        return
    var job: Dictionary = JOBS.get(str(state["current_job"]), JOBS["helper"])
    var base_pay: int = rng.randi_range(int(job["pay"][0]), int(job["pay"][1]))
    var pay: int = int(round(base_pay * 1.2))
    state["money"] = float(state["money"]) + pay
    state["overtime_clicks"] = int(state["overtime_clicks"]) + 1
    say("Přesčas: +%d Kč." % pay)
    finish_bonus_if_needed()
    save_game()
    show_tab("PRÁCE")

func finish_bonus_if_needed() -> void:
    if int(state["home_clicks"]) + int(state["overtime_clicks"]) >= 2:
        reset_shift()

func reset_shift() -> void:
    state["work_clicks"] = 0
    state["home_clicks"] = 0
    state["overtime_clicks"] = 0

func quit_job() -> void:
    state["employed"] = false
    reset_shift()
    say("Odešel jsi z práce.")
    save_game()
    show_tab("PRÁCE")

func return_to_work() -> void:
    state["employed"] = true
    state["current_job"] = "helper"
    say("Vrátil ses jako pomocník.")
    save_game()
    show_tab("PRÁCE")

func sync_level() -> void:
    var level_value: int = 0
    for i: int in range(1, LEVEL_XP.size()):
        if int(state["xp"]) >= LEVEL_XP[i]:
            level_value = i
    state["level"] = mini(10, level_value)

func do_splitter_cycle() -> bool:
    if float(state["money"]) < SPLITTER_WAGE:
        return false
    if float(state["logs_m3"]) + 0.000001 < AXE_IN:
        return false
    if free_storage() + AXE_IN + 0.000001 < AXE_OUT:
        return false
    state["money"] = float(state["money"]) - SPLITTER_WAGE
    state["logs_m3"] = float(state["logs_m3"]) - AXE_IN
    state["split_m3"] = float(state["split_m3"]) + AXE_OUT
    return true

func do_sawyer_cycle() -> bool:
    if float(state["money"]) < SAWYER_WAGE:
        return false
    if float(state["roundwood_m3"]) + 0.000001 < SAW_IN:
        return false
    if free_storage() + SAW_IN + 0.000001 < SAW_OUT:
        return false
    state["money"] = float(state["money"]) - SAWYER_WAGE
    state["roundwood_m3"] = float(state["roundwood_m3"]) - SAW_IN
    state["logs_m3"] = float(state["logs_m3"]) + SAW_OUT
    return true

func _process(delta: float) -> void:
    var splitter_tool: String = str(state["splitter_tool"])
    if splitter_tool != "":
        splitter_accum += delta
        var splitter_cycle: float = 1.6 if splitter_tool == "sharpened" else 1.8
        while splitter_accum >= splitter_cycle:
            splitter_accum -= splitter_cycle
            if not do_splitter_cycle():
                splitter_accum = 0.0
                break
    else:
        splitter_accum = 0.0

    var sawyer_tool: String = str(state["sawyer_tool"])
    var sawyer_cycle: float = 0.0
    if sawyer_tool == "frameSaw":
        sawyer_cycle = FRAME_SAW_CYCLE
    elif sawyer_tool == "akuSaw":
        sawyer_cycle = AKU_SAW_CYCLE

    if sawyer_cycle > 0.0:
        sawyer_accum += delta
        while sawyer_accum >= sawyer_cycle:
            sawyer_accum -= sawyer_cycle
            if not do_sawyer_cycle():
                sawyer_accum = 0.0
                break
    else:
        sawyer_accum = 0.0

    save_accum += delta
    if save_accum >= 5.0:
        save_accum = 0.0
        save_game()
    update_hud()

func update_hud() -> void:
    if hud_money == null:
        return
    hud_money.text = "PENÍZE: %.0f Kč" % float(state["money"])
    hud_wood.text = "DŘEVO: %.3f m³" % float(state["split_m3"])
    hud_level.text = "LVL %d  |  XP %d" % [int(state["level"]), int(state["xp"])]

func say(text: String) -> void:
    if message_label != null:
        message_label.text = text

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
        var parsed_dict: Dictionary = parsed
        for key: Variant in parsed_dict.keys():
            state[key] = parsed_dict[key]
    if not state.has("aku_saw_qty"):
        state["aku_saw_qty"] = 0
    sync_level()
