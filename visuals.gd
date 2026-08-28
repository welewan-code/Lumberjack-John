extends Control

const TOOL_BASE := "res://assets/tools/"

var game: Node
var tool_strip: HBoxContainer

func _ready() -> void:
    game = get_parent()
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    z_index = 100
    _build_tool_strip()
    set_process(true)

func _build_tool_strip() -> void:
    tool_strip = HBoxContainer.new()
    tool_strip.position = Vector2(340, 92)
    tool_strip.add_theme_constant_override("separation", 14)
    tool_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(tool_strip)

    for item in [
        ["wooden_axe.png", "Tupá sekera"],
        ["sharpened_axe.png", "Nabroušená sekera"],
        ["frame_saw.png", "Rámovka"],
        ["aku_saw.png", "Aku pila"],
        ["wheelbarrow.png", "Kolečko"]
    ]:
        var box := VBoxContainer.new()
        box.custom_minimum_size = Vector2(92, 90)
        box.mouse_filter = Control.MOUSE_FILTER_IGNORE

        var tex := TextureRect.new()
        tex.custom_minimum_size = Vector2(72, 58)
        tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var path: String = TOOL_BASE + String(item[0])
        if ResourceLoader.exists(path):
            tex.texture = load(path)

        var label := Label.new()
        label.text = String(item[1])
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 11)
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE

        box.add_child(tex)
        box.add_child(label)
        tool_strip.add_child(box)

func _process(_delta: float) -> void:
    if game == null:
        visible = false
        return

    var tab := ""
    if "current_tab" in game:
        tab = str(game.current_tab)

    # FIRMA must stay completely clean: no character sprites, no animated workers,
    # no tool images from this overlay. Visual strip is only for OBCHOD/SKLAD.
    visible = tab == "OBCHOD" or tab == "SKLAD"
    if tool_strip != null and is_instance_valid(tool_strip):
        tool_strip.visible = visible
