@tool
extends Control

@onready var add_err := %add_static_body_error
@onready var materials_list: Tree = %materials_list
@onready var static_body_list: Tree = %static_body_list
@onready var material_table = AssetIO.get_material_table()
var file_system_dock:FileSystemDock
var editor_file_system:EditorFileSystem

func _ready() -> void:	
	file_system_dock = EditorInterface.get_file_system_dock()
	editor_file_system = EditorInterface.get_resource_filesystem()
	
	materials_list.set_column_expand(0,false)
	materials_list.set_column_expand(1,false)	
	materials_list.set_column_custom_minimum_width(0, 36)
	materials_list.set_column_custom_minimum_width(1, 36)	
	update_materials_list()	
	materials_list.item_selected.connect(show_material_in_file_system_dock)
	materials_list.item_activated.connect(show_replace_material_popup)
	materials_list.material_table_changed.connect(update_materials_list)		
	%materials_search.text_changed.connect(update_materials_list)
	%add_material_button.pressed.connect(show_add_material_popup)
	
	update_static_body_list()
	static_body_list.item_selected.connect(show_static_body_in_file_system_dock)
	static_body_list.item_edited.connect(rename_static_body)
	%add_static_body_button.pressed.connect(add_static_body)
	%static_body_search.text_changed.connect(update_static_body_list)
	
	
func add_materials_to_table(paths):
	for path in paths:
		AssetIO.update_material(-1, path)
	
func show_add_material_popup():
	var popup = load("res://addons/m_terrain/asset_manager/ui/select_resources_by_type.tscn").instantiate()		
	popup.resources_selected.connect(add_materials_to_table)
	popup.types = ["StandardMaterial3D", "ShaderMaterial", "ORMMaterial3D"]
	popup.title = "Add Material(s)"
	add_child(popup)
	popup.popup()
		
func show_replace_material_popup():
	var popup:Popup = preload("res://addons/m_terrain/asset_manager/ui/select_resources_by_type.tscn").instantiate()	
	popup.resource_selected.connect(replace_material)
	popup.types = ["StandardMaterial3D", "ShaderMaterial", "ORMMaterial3D"]	
	popup.title = material_table[materials_list.get_selected().get_metadata(0)]
	add_child(popup)
	popup.popup_centered()
	
func replace_material(new_path):
	var original_id = materials_list.get_selected().get_metadata(0)
	print("replacing ",original_id, " with ", new_path)
	AssetIO.update_material(original_id,new_path)		
	update_materials_list()
	
func update_materials_list(filter = null):	
	materials_list.clear()
	var root = materials_list.get_root()
	if not root:
		root = materials_list.create_item()		
	for i in material_table.keys():
		if filter and not filter in material_table[i]: continue
		var item := root.create_child()
		item.set_text(0, str(i))
		item.set_metadata(0, i)
		item.set_icon(1, AssetIO.get_thumbnail(AssetIO.get_thumbnail_path(i, false)))
		item.set_text(2, material_table[i])		
		for file in DirAccess.get_files_at("res://massets/meshes/"):
			for dependency in ResourceLoader.get_dependencies("res://massets/meshes/" + file):
				if material_table[i] in dependency: 				
					var mesh_item := item.create_child()
					mesh_item.set_text(2, file)
					break
					#AssetIO.get_thumbnail(AssetIO.get_thumbnail_path())
		item.collapsed = true
			
func update_static_body_list(filter = null):
	var list = get_setting_list()
	static_body_list.clear()
	var root = static_body_list.get_root()
	if not root:
		root = static_body_list.create_item()
	for sname in list:
		if filter and not filter in sname: continue
		#print("adding ", sname)
		var item := root.create_child()
		item.set_editable(0, true)		
		item.set_text(0, sname)
		item.set_metadata(0, sname)

func get_setting_list()->Dictionary: #key -> asset_name, value asset
	var dir_path = MHlod.get_physics_settings_dir()
	var dir = DirAccess.open(dir_path)
	var out:Dictionary
	if not dir:
		return out
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		var fpath = dir_path.path_join(fname)
		fname = dir.get_next()
		var s:MHlodCollisionSetting = load(fpath)
		if out.has(s.name):
			printerr("Duplicate Physcis Setting name Please change the name mannually and restart Godot"+fpath)
			continue
		if s:
			out[s.name] = s
	return out
	
func show_material_in_file_system_dock() -> void:	
	var list = material_table.values()
	var sname = materials_list.get_selected().get_text(2)
	if not sname in list:
		printerr("Can not find Item ",sname)
		return
	var s:Material = load(sname)
	if not s:
		printerr("Material is not valid ",sname)
		return
	if s.resource_path == "":
		printerr("Material has invalid path ",sname)
		return
	file_system_dock.navigate_to_path(s.resource_path)
	EditorInterface.edit_resource(s)

func show_static_body_in_file_system_dock() -> void:	
	add_err.visible = false
	var list = get_setting_list()	
	var sname = static_body_list.get_selected().get_text(0)
	if not list.has(sname):
		printerr("Can not find Item ",sname)
		return
	var s:MHlodCollisionSetting = list[sname]
	if not s:
		printerr("Asset is not valid ",sname)
		return
	if s.resource_path == "":
		printerr("Asset has invalid path ",sname)
		return
	file_system_dock.navigate_to_path(s.resource_path)
	EditorInterface.edit_resource(s)

func rename_static_body():
	var item := static_body_list.get_edited()
	var original_name = item.get_metadata(0)
	var list = get_setting_list()
	if not original_name in list: 
		print("static body with original name ", original_name,  " does not exist")
		return
	if validate_static_body_name(item.get_text(0)):
		print("renamed ", original_name, " to ", item.get_text(0))
		list[original_name].name = item.get_text(0)
		item.set_metadata(0, list[original_name].name)
	else:
		print("cannot rename ", original_name, " to ", item.get_text(0))
		item.set_text(0, original_name)

func validate_static_body_name(sname)->bool:
	add_err.visible = false
	if sname == "":
		add_err.visible = true
		add_err.text = "Empty Setting Name"
		return false
	var list = get_setting_list()
	if list.has(sname):
		add_err.visible = true
		add_err.text = "Duplicate Setting Name"
		return false
	return true

func add_static_body() -> void:
	var list = get_setting_list()
	var i = 0	
	var sname = "new_static_body"
	while list.has(sname):
		i+= 1	
		sname = str("new_static_body_", i) 	
	### Finding an empty ID
	var exist_ids:PackedInt32Array
	for k in list:
		var s:MHlodCollisionSetting = list[k]
		if not s:
			continue
		var ii:int = s.resource_path.get_file().get_basename().to_int()
		if ii == 0:
			printerr("invalide Setting path: ",s.resource_path)
			continue
		exist_ids.push_back(ii)
	exist_ids.sort()
	var biggest_id :int= 0
	if exist_ids.size() != 0:
		biggest_id = exist_ids[exist_ids.size() - 1]
	var new_id = biggest_id + 1
	var ns := MHlodCollisionSetting.new();
	ns.name = sname
	var npath = MHlod.get_physics_settings_dir().path_join(str(new_id)+".res")
	if not DirAccess.dir_exists_absolute(MHlod.get_physics_settings_dir()):
		DirAccess.make_dir_recursive_absolute(MHlod.get_physics_settings_dir())
	ResourceSaver.save(ns,npath)
	update_static_body_list()
	editor_file_system.scan()
