extends Node

const SHOP_SAVE_PATH := "user://shop_inventory.json"
const CATEGORIES: Array[String] = ["SEKERY", "PILY", "DOPRAVNÍ PROSTŘEDKY", "NÁKUP DŘEVA"]
const LOG_PRICE_PER_M3: float = 1200.0
const BLOCK_PRICE_PER_M3: float = 1100.0
const STORAGE_CAPACITY: float = 10.0
const BUY_STEP_M3: float = 1.0

const ITEMS: Dictionary = {
	"wooden_axe": {"category":"SEKERY", "name":"Tupá sekera", "price":0, "asset":"res://assets/tools/wooden_axe.png", "desc":"Základní pracovní sekera."},
	"sharpened_axe": {"category":"SEKERY", "name":"Nabroušená sekera", "price":120, "asset":"res://assets/tools/sharpened_axe.png", "desc":"Rychlejší sekání než se základní sekerou."},
	"checht_axe": {"category":"SEKERY", "name":"Štípací sekera CHECHT", "price":590, "asset":"res://assets/Nástroje/štípací sekera checht.png", "desc":"Štípací rychlost 1,5 s / špalek."},
	"fickars_axe": {"category":"SEKERY", "name":"Štípací sekera Fickars", "price":1800, "asset":"res://assets/tools/fickars_axe.png", "desc":"1,3 s / špalek. 5 % šance: 0,020 m³ → 0,030 m³."},
	"frame_saw": {"category":"PILY", "name":"Rámová pila", "price":160, "asset":"res://assets/tools/frame_saw.png", "desc":"Ruční pila pro další pracovní činnosti."},
	"aku_saw": {"category":"PILY", "name":"Aku pila", "price":790, "asset":"res://assets/tools/aku_saw.png", "desc":"Rychlejší elektrická pila."},
	"wheelbarrow": {"category":"DOPRAVNÍ PROSTŘEDKY", "name":"Kolečko", "price":80, "asset":"res://assets/tools/wheelbarrow.png", "desc":"Základní přesun materiálu."},
	"handcart": {"category":"DOPRAVNÍ PROSTŘEDKY", "name":"Trakař", "price":220, "asset":"res://assets/tools/trakar.png", "desc":"Dřevěný trakař. Odveze 0,2 m³ na jednu otočku."},
	"small_trailer": {"category":"DOPRAVNÍ PROSTŘEDKY", "name":"Malý vozík za auto", "price":3500, "asset":"res://assets/tools/small_trailer.png", "desc":"Starý malý přívěsný vozík. Odveze 0,5 m³ na jednu otočku."}
}

var current_category: String = "SEKERY"
var category_refresh_id: int = 0
var inventory: Dictionary = {
	"sharpened_axe": 0,
	"checht_axe": 0,
	"fickars_axe": 0,
	"frame_saw": 0,
	"aku_saw": 0,
	"wheelbarrow": 0,
	"handcart": 0,
	"small_trailer": 0
}

func _ready() -> void:
	load_inventory()

func _render_shop() -> void:
	var main := get_tree().current_scene
	if main == null: return
	var host_value = main.get("content_host")
	if not (host_value is MarginContainer): return
	var host := host_value as MarginContainer
	for child in host.get_children(): child.queue_free()
	await get_tree().process_frame
	if not is_instance_valid(host): return
	var root := VBoxContainer.new(); root.size_flags_horizontal=Control.SIZE_EXPAND_FILL; root.size_flags_vertical=Control.SIZE_EXPAND_FILL; root.add_theme_constant_override("separation",12); host.add_child(root)
	var title := _make_label(main,"OBCHOD",28); title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; root.add_child(title)
	var tabs:=HBoxContainer.new(); tabs.add_theme_constant_override("separation",6); root.add_child(tabs)
	for category in CATEGORIES:
		var b:=Button.new(); b.text=category; b.size_flags_horizontal=Control.SIZE_EXPAND_FILL; b.custom_minimum_size.y=42; b.add_theme_font_size_override("font_size",15); b.pressed.connect(_switch_category.bind(category)); tabs.add_child(b)
	var category_host:=VBoxContainer.new(); category_host.name="ShopCategoryHost"; category_host.size_flags_vertical=Control.SIZE_EXPAND_FILL; category_host.add_theme_constant_override("separation",10); root.add_child(category_host); _render_category(main,category_host)

func _switch_category(category:String)->void:
	current_category=category; _refresh_category()

func _render_category(main:Node,host:VBoxContainer)->void:
	if current_category=="NÁKUP DŘEVA": _render_wood_buy(main,host); return
	var grid:=GridContainer.new(); grid.columns=2; grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL; grid.add_theme_constant_override("h_separation",12); grid.add_theme_constant_override("v_separation",12); host.add_child(grid)
	for item_id in ITEMS.keys():
		var item:Dictionary=ITEMS[item_id]
		if str(item["category"])==current_category: _add_item_card(main,grid,str(item_id),item)

func _render_wood_buy(main:Node,host:VBoxContainer)->void:
	var state:=_main_state(main); var used:=_storage_used(state); var free:=maxf(0.0,STORAGE_CAPACITY-used)
	var storage:=_make_label(main,"Sklad: %.2f / 10.00 m³  •  Volno: %.2f m³" % [used,free],16); storage.add_theme_color_override("font_color",Color("#ffca42")); host.add_child(storage)
	host.add_child(_make_label(main,"Materiál se nakupuje pouze po celých metrech.",14))
	var grid:=GridContainer.new(); grid.columns=2; grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL; grid.add_theme_constant_override("h_separation",12); host.add_child(grid)
	_add_wood_buy_card(main,grid,"roundwood_m3","ŠPALKY",BLOCK_PRICE_PER_M3); _add_wood_buy_card(main,grid,"logs_m3","KLÁDY",LOG_PRICE_PER_M3)

func _add_wood_buy_card(main:Node,grid:GridContainer,key:String,title_text:String,price:float)->void:
	var state:=_main_state(main); var owned:=float(state.get(key,0.0)); var used:=_storage_used(state); var can_fit:=used+BUY_STEP_M3<=STORAGE_CAPACITY+0.0001; var can_afford:=float(state.get("money",0.0))>=price
	var panel:=PanelContainer.new(); panel.custom_minimum_size=Vector2(360,220); panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL; panel.add_theme_stylebox_override("panel",_panel_style(main,"#1b1713","#6b4628",7,1)); grid.add_child(panel)
	var margin:=MarginContainer.new(); margin.add_theme_constant_override("margin_left",14); margin.add_theme_constant_override("margin_right",14); margin.add_theme_constant_override("margin_top",14); margin.add_theme_constant_override("margin_bottom",14); panel.add_child(margin)
	var box:=VBoxContainer.new(); box.add_theme_constant_override("separation",8); margin.add_child(box); var title:=_make_label(main,title_text,21); title.add_theme_color_override("font_color",Color("#ffca42")); box.add_child(title); box.add_child(_make_label(main,"Ve skladu: %.2f m³"%owned,15)); box.add_child(_make_label(main,"Cena: %.0f Kč / m³"%price,15)); box.add_child(_make_label(main,"Balení: 1 m³",14))
	var buy:=Button.new(); buy.text="KOUPIT 1 m³ ZA %.0f Kč"%price; buy.custom_minimum_size.y=42; buy.disabled=not can_fit or not can_afford; buy.pressed.connect(_buy_wood.bind(key,price)); box.add_child(buy)
	if not can_fit: box.add_child(_make_label(main,"Ve skladu není místo na další 1 m³.",13))

func _buy_wood(key:String,price:float)->void:
	var main:=get_tree().current_scene
	if main==null:return
	var state:=_main_state(main)
	if float(state.get("money",0.0))<price or _storage_used(state)+BUY_STEP_M3>STORAGE_CAPACITY+0.0001:return
	state["money"]=float(state.get("money",0.0))-price; state[key]=float(state.get(key,0.0))+BUY_STEP_M3; main.set("state",state); main.call("update_hud"); main.call("save_game"); _refresh_category()

func _storage_used(state:Dictionary)->float:
	return float(state.get("logs_m3",0.0))+float(state.get("roundwood_m3",0.0))+float(state.get("split_m3",0.0))

func _add_item_card(main:Node,grid:GridContainer,item_id:String,item:Dictionary)->void:
	var panel:=PanelContainer.new(); panel.custom_minimum_size=Vector2(360,190); panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL; panel.add_theme_stylebox_override("panel",_panel_style(main,"#1b1713","#6b4628",7,1)); grid.add_child(panel)
	var margin:=MarginContainer.new(); margin.add_theme_constant_override("margin_left",14); margin.add_theme_constant_override("margin_right",14); margin.add_theme_constant_override("margin_top",12); margin.add_theme_constant_override("margin_bottom",12); panel.add_child(margin)
	var row:=HBoxContainer.new(); row.add_theme_constant_override("separation",12); margin.add_child(row)
	var asset_path:String=str(item.get("asset",""))
	if asset_path!="" and ResourceLoader.exists(asset_path):
		if item_id=="checht_axe":
			_add_checht_preview(row,asset_path)
		else:
			var tex:=TextureRect.new(); tex.custom_minimum_size=Vector2(120,120); tex.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; tex.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; var res:=ResourceLoader.load(asset_path)
			if res is Texture2D: tex.texture=res as Texture2D
			row.add_child(tex)
	var info:=VBoxContainer.new(); info.size_flags_horizontal=Control.SIZE_EXPAND_FILL; info.add_theme_constant_override("separation",5); row.add_child(info)
	var name_label:=_make_label(main,str(item["name"]),20); name_label.add_theme_color_override("font_color",Color("#ffca42")); info.add_child(name_label); info.add_child(_make_label(main,str(item["desc"]),14))
	var price:int=int(item["price"]); var owned:int=get_owned_item_count(item_id); var price_text:="Startovní výbava" if price<=0 else "%d Kč"%price; info.add_child(_make_label(main,"Cena: %s  •  Vlastníš: %d"%[price_text,owned],14))
	var actions:=HBoxContainer.new(); actions.add_theme_constant_override("separation",6); info.add_child(actions)
	if item_id=="wooden_axe":
		var equip_start:=Button.new(); equip_start.text="VYBAVIT"; equip_start.size_flags_horizontal=Control.SIZE_EXPAND_FILL; equip_start.custom_minimum_size.y=36; equip_start.pressed.connect(_equip_axe.bind("wooden")); actions.add_child(equip_start)
	elif item_id=="sharpened_axe" or item_id=="checht_axe" or item_id=="fickars_axe":
		if owned>0:
			var equip_id:String="sharpened"
			if item_id=="checht_axe": equip_id="checht"
			elif item_id=="fickars_axe": equip_id="fickars"
			var equip:=Button.new(); equip.text="VYBAVIT"; equip.size_flags_horizontal=Control.SIZE_EXPAND_FILL; equip.custom_minimum_size.y=36; equip.pressed.connect(_equip_axe.bind(equip_id)); actions.add_child(equip)
		_add_buy_button(main,actions,item_id,price,owned)
	else:
		_add_buy_button(main,actions,item_id,price,owned)

func _add_buy_button(main:Node,actions:HBoxContainer,item_id:String,price:int,owned:int)->void:
	var buy:=Button.new(); buy.size_flags_horizontal=Control.SIZE_EXPAND_FILL; buy.custom_minimum_size.y=36
	buy.text=("KOUPIT DALŠÍ ZA %d Kč" if owned>0 else "KOUPIT ZA %d Kč") % price
	buy.disabled=float(_main_state(main).get("money",0.0))<float(price)
	buy.pressed.connect(_buy_item.bind(item_id)); actions.add_child(buy)

func _add_checht_preview(row: HBoxContainer, asset_path: String) -> void:
	var holder:=Control.new(); holder.custom_minimum_size=Vector2(120,120); row.add_child(holder)
	var source:=ResourceLoader.load(asset_path)
	if not (source is Texture2D): return
	var source_tex:=source as Texture2D
	var atlas:=AtlasTexture.new(); atlas.atlas=source_tex
	var w:float=float(source_tex.get_width()); var h:float=float(source_tex.get_height())
	atlas.region=Rect2(0.0,h*0.25,w,h*0.25)
	var tex:=TextureRect.new(); tex.texture=atlas; tex.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; tex.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.position=Vector2(15,15); tex.size=Vector2(90,90); tex.pivot_offset=Vector2(45,45); tex.rotation_degrees=-42.0
	holder.add_child(tex)

func _buy_item(item_id:String)->void:
	if not ITEMS.has(item_id):return
	var main:=get_tree().current_scene
	if main==null:return
	var item:Dictionary=ITEMS[item_id]; var price:int=int(item["price"]); var state:=_main_state(main)
	if float(state.get("money",0.0))<float(price):return
	state["money"]=float(state.get("money",0.0))-float(price)
	inventory[item_id]=int(inventory.get(item_id,0))+1
	main.set("state",state); main.call("update_hud"); main.call("save_game"); save_inventory(); _refresh_category()

func _equip_axe(axe_id:String)->void:
	var main:=get_tree().current_scene
	if main==null:return
	var required_item:String="wooden_axe"
	if axe_id=="sharpened":required_item="sharpened_axe"
	elif axe_id=="checht":required_item="checht_axe"
	elif axe_id=="fickars":required_item="fickars_axe"
	if get_owned_item_count(required_item)<=0:return
	var state:=_main_state(main); state["equipped_axe"]=axe_id; main.set("state",state); main.call("save_game"); _refresh_category()

func get_owned_item_count(item_id:String)->int:
	if item_id=="wooden_axe":return 1
	return maxi(0,int(inventory.get(item_id,0)))

func _refresh_category()->void:
	category_refresh_id+=1; var request_id:int=category_refresh_id; var main:=get_tree().current_scene
	if main==null:return
	var host:=_find_named_node(main,"ShopCategoryHost")
	if host is VBoxContainer:
		for child in host.get_children():child.queue_free()
		await get_tree().process_frame
		if request_id!=category_refresh_id:return
		if is_instance_valid(host):_render_category(main,host as VBoxContainer)

func _owned_count(_main:Node,item_id:String)->int:
	return get_owned_item_count(item_id)

func _main_state(main:Node)->Dictionary:
	var value=main.get("state"); return value as Dictionary if value is Dictionary else {}
func _make_label(main:Node,text_value:String,size:int)->Label:
	var value=main.call("make_label",text_value,size)
	if value is Label:return value as Label
	var label:=Label.new(); label.text=text_value; return label
func _panel_style(main:Node,bg:String,border:String,radius:int,width:int)->StyleBoxFlat:
	var value=main.call("panel_style",bg,border,radius,width); return value as StyleBoxFlat if value is StyleBoxFlat else StyleBoxFlat.new()
func _find_named_node(root:Node,node_name:String)->Node:
	for node in _all_nodes(root):
		if node.name==node_name:return node
	return null
func _all_nodes(root:Node)->Array[Node]:
	var result:Array[Node]=[]; var stack:Array[Node]=[root]
	while not stack.is_empty():
		var current:Node=stack.pop_back(); result.append(current)
		for child in current.get_children():stack.append(child)
	return result
func save_inventory()->void:
	var f:=FileAccess.open(SHOP_SAVE_PATH,FileAccess.WRITE)
	if f!=null:f.store_string(JSON.stringify(inventory))
func load_inventory()->void:
	if not FileAccess.file_exists(SHOP_SAVE_PATH):return
	var f:=FileAccess.open(SHOP_SAVE_PATH,FileAccess.READ)
	if f==null:return
	var parsed=JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		for key in inventory.keys():
			if parsed.has(key):inventory[key]=maxi(0,int(parsed[key]))
