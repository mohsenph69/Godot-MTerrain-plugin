@tool
extends PanelContainer

var vbox:VBoxContainer
var items:Dictionary

#type is bitwise or between types of MAssetTable
func add_item(item_name:String,types:int,func_callback:Callable)->void:
	if items.has(item_name):
		printerr("Duplicate item name!")
		return
	items[item_name] = [types, func_callback]

func _ready() -> void:
	############ ADDING ITEMS ############
	var tmesh = MAssetTable.MESH
	var tpscene = MAssetTable.PACKEDSCENE
	var tdecal = MAssetTable.DECAL
	var thlod = MAssetTable.HLOD
	add_item("Rebake",thlod,AssetIOBaker.rebake_hlod_by_collection_id)
	add_item("Modify in blender",tmesh,AssetIO.modify_in_blender)
	add_item("Open Scene",tpscene,AssetIO.open_packed_scene)
	add_item("Open BakerScene",thlod,AssetIOBaker.open_hlod_baker)
	add_item("Show in FileSystem",tmesh|tpscene|tdecal|thlod,AssetIO.show_in_file_system)
	add_item("Show GLTF",tmesh,AssetIO.show_gltf)
	add_item("Tag",tmesh|tpscene|tdecal|thlod,AssetIO.show_tag)
	add_item("Remove only HLod",thlod, remove_only_hlod)
	add_item("Remove",tpscene|tdecal|thlod,AssetIO.remove_collection)
	########## END ADDING ITEMS ##########
	vbox = VBoxContainer.new()
	vbox.custom_minimum_size.x = 160
	add_child(vbox)
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color("1b1f27")
	set("theme_override_styles/panel",style_box)
	visible=false
	top_level = true

func clear():
	for b:Node in vbox.get_children():
		b.queue_free()

func add_buttons(collection_id:int):
	var at:=MAssetTable.get_singleton()
	if not at:
		print("AssetTable singelton is null")
		return
	var type = at.collection_get_type(collection_id)
	for item_name:String in items:
		if items[item_name][0]&type!=0:
			var btn = Button.new()
			btn.text = item_name
			btn.size_flags_horizontal=Control.SIZE_FILL
			btn.button_down.connect(set_visible.bind(false))
			var func_callback:Callable= items[item_name][1]
			func_callback = func_callback.bind(collection_id)
			btn.button_down.connect(func_callback)
			vbox.add_child(btn)

func item_clicked(collection_id: int, at_position: Vector2) -> void:	
	clear()
	var at:=MAssetTable.get_singleton()	
	visible = true
	var is_most_left:bool=get_parent().get_rect().size.x/1.3 < at_position.x
	var a_offset:Vector2
	a_offset.y = vbox.get_rect().size.y
	if is_most_left: a_offset.x = vbox.get_rect().size.x
	position = at_position - a_offset + get_parent().global_position
	add_buttons(collection_id)

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventMouseButton and event.pressed:
		var levent = make_input_local(event)		
		if not Rect2(Vector2(),get_rect().size).has_point(levent.position):
			visible = false

func remove_only_hlod(collection_id:int)->void:
	AssetIO.remove_collection(collection_id,true)
