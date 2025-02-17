@tool
extends PanelContainer

var vbox:VBoxContainer

var item_list:ItemList
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
	add_item("Rebake",thlod,rebake_hlod)
	add_item("Open BakerScene",thlod,open_hlod_baker)
	add_item("Show in FileSystem",tmesh|tpscene|tdecal|thlod,show_in_file_system)
	add_item("Show GLTF",tmesh,show_gltf)
	add_item("Remove only HLod",thlod,remove_only_hlod)
	add_item("Remove",tpscene|tdecal|thlod,remove_collection)
	########## END ADDING ITEMS ##########
	vbox = VBoxContainer.new()
	vbox.custom_minimum_size.x = 160
	add_child(vbox)
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color("1b1f27")
	set("theme_override_styles/panel",style_box)
	visible=false

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

func item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index!=MOUSE_BUTTON_RIGHT: return
	clear()
	var at:=MAssetTable.get_singleton()
	var collection_id = item_list.get_item_metadata(index)
	visible = true
	var is_most_left:bool=get_parent().get_rect().size.x/1.3 < at_position.x
	var a_offset:Vector2
	a_offset.y = vbox.get_rect().size.y
	if is_most_left: a_offset.x = vbox.get_rect().size.x
	position = at_position - a_offset
	add_buttons(collection_id)

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventMouseButton and event.pressed:
		var levent = make_input_local(event)		
		if not Rect2(Vector2(),get_rect().size).has_point(levent.position):
			visible = false
			clear()

func show_in_file_system(collection_id:int)->void:
	var type = MAssetTable.get_singleton().collection_get_type(collection_id)
	var item_id:int= MAssetTable.get_singleton().collection_get_item_id(collection_id)
	var path:String
	match type:
		MAssetTable.MESH:
			item_id = MAssetTable.mesh_item_get_first_valid_id(item_id)
			if item_id==-1:
				MTool.print_edmsg("Not valid mesh in collection "+str(collection_id))
				return
			path = MHlod.get_mesh_path(item_id)
		MAssetTable.PACKEDSCENE: path = MHlod.get_packed_scene_path(item_id)
		MAssetTable.DECAL: path = MHlod.get_decal_path(item_id)
		MAssetTable.HLOD: path = MHlod.get_hlod_path(item_id)
	EditorInterface.get_file_system_dock().navigate_to_path(path)

func open_hlod_baker(collection_id:int):
	var type = MAssetTable.get_singleton().collection_get_type(collection_id)
	if type!=MAssetTable.ItemType.HLOD:
		printerr("Type MHlod is not valid")
		return
	var item_id:int= MAssetTable.get_singleton().collection_get_item_id(collection_id)
	var hlod:MHlod= load(MHlod.get_hlod_path(item_id))
	if not hlod:
		print("hlod resourse is not valid")
		return
	EditorInterface.call_deferred("open_scene_from_path",hlod.baker_path)

func show_gltf(collection_id:int):
	var at:=MAssetTable.get_singleton()
	var type = at.collection_get_type(collection_id)
	if type!=MAssetTable.ItemType.MESH:
		printerr("Type MESH is not valid")
		return
	var glb_id = at.collection_get_glb_id(collection_id)
	var import_info = at.import_info
	var gpath:String
	for path:String in import_info:
		if path.begins_with("__"): continue
		if import_info[path]["__id"] == glb_id:
			gpath = path
			break
	at.clear_import_info_cache()
	if not gpath.is_empty():
		EditorInterface.get_file_system_dock().navigate_to_path(gpath)
	
	
func remove_collection(collection_id:int,only_hlod=false)->void:
	var at:=MAssetTable.get_singleton()
	var type = at.collection_get_type(collection_id)
	var item_id:int= at.collection_get_item_id(collection_id)
	var cname = at.collection_get_name(collection_id)
	var removing_files:PackedStringArray
	match type:
		MAssetTable.MESH:
			removing_files.push_back(MHlod.get_mesh_path(item_id))
		MAssetTable.PACKEDSCENE:
			removing_files.push_back(MHlod.get_packed_scene_path(item_id))
		MAssetTable.DECAL:
			removing_files.push_back(MHlod.get_decal_path(item_id))
		MAssetTable.HLOD:
			removing_files.push_back(MHlod.get_hlod_path(item_id))
			if not only_hlod:
				var hlod:MHlod= load(MHlod.get_hlod_path(item_id))
				removing_files.push_back(hlod.baker_path)
	var confirm_box := ConfirmationDialog.new();
	confirm_box.canceled.connect(confirm_box.queue_free)
	confirm_box.initial_position=Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	confirm_box.dialog_text = "Removing collection \"%s\" These files will be removed:\n" % cname
	for f in removing_files:
		confirm_box.dialog_text += f +"\n"
	confirm_box.visible = true
	add_child(confirm_box)
	confirm_box.confirmed.connect(func():
		for f in removing_files:
			if FileAccess.file_exists(f):
				var res=load(f)
				if res:
					res.resource_path=""
					res.emit_changed()
				DirAccess.remove_absolute(f)
				var __f = FileAccess.open(f.get_basename() + ".stop",FileAccess.WRITE)
				__f.close()
		at.collection_remove(collection_id)
		MAssetTable.save()
		if AssetIO.asset_placer:
			AssetIO.asset_placer.regroup()
		EditorInterface.get_resource_filesystem().scan()
	)

func remove_only_hlod(collection_id:int)->void:
	remove_collection(collection_id,true)

func rebake_hlod(collection_id:int)->void:
	var at:=MAssetTable.get_singleton()
	var type = at.collection_get_type(collection_id)
	if type!=MAssetTable.ItemType.HLOD:
		printerr("Not valid HLOD type")
		return
	var item_id:int= at.collection_get_item_id(collection_id)
	var hpath = MHlod.get_hlod_path(item_id)
	var hres:MHlod=load(hpath)
	AssetIOBaker.rebake_hlod(hres)
