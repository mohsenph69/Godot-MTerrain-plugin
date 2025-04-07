@tool
extends Control

@onready var add_err := %add_static_body_error
@onready var materials_list: Tree = %materials_list
@onready var static_body_list: Tree = %static_body_list

var file_system_dock:FileSystemDock
var editor_file_system:EditorFileSystem
var empty_double_click_time = 0
func _ready() -> void:	
	file_system_dock = EditorInterface.get_file_system_dock()
	editor_file_system = EditorInterface.get_resource_filesystem()
	
	materials_list.set_column_expand(0,false)
	materials_list.set_column_expand(1,false)	
	materials_list.set_column_custom_minimum_width(0, 36)
	materials_list.set_column_custom_minimum_width(1, 36)		
	visibility_changed.connect(update_materials_list)
	update_materials_list()
	materials_list.item_selected.connect(show_material_in_file_system_dock)
	materials_list.item_activated.connect(func():
		var selected_item = materials_list.get_selected()
		materials_list.set_selected(selected_item, 2)
		if selected_item.get_text(2) == selected_item.get_tooltip_text(2):
			selected_item.set_text(2, "")
		materials_list.edit_selected(true)
	)
	materials_list.item_edited.connect(func():		
		var mat = load(materials_list.get_selected().get_tooltip_text(2))
		var selected_item = materials_list.get_selected()
		if mat.resource_name.is_empty() and selected_item.get_text(2).is_empty(): 
			selected_item.set_text(2, mat.resource_path)
			return
		mat.resource_name = selected_item.get_text(2)
		AssetIOMaterials.rename_material(int(selected_item.get_text(0)), mat.resource_name)
		mat.notify_property_list_changed()		
		if selected_item.get_text(2).is_empty():
			selected_item.set_text(2, mat.resource_path)
			
	)
	materials_list.button_clicked.connect(func(item: TreeItem, column, id, mouse_button_index):
		if id == 0:
			materials_list.set_selected(item, 0)
			show_replace_material_popup()
		elif id ==1:
			var material_table = AssetIOMaterials.get_material_table()
			var material_id = int(item.get_text(0))
			if not material_table.has(material_id):	
				push_error("MTerrain MaterialTable Error: Trying to delete material that does not exist")				
				return	
			var confirm := ConfirmationDialog.new()
			confirm.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
			confirm.confirmed.connect(func():
				AssetIOMaterials.remove_material(material_id)
				update_materials_list()
			)					
			confirm.dialog_text = "Are you sure you want to delete this material?"
			add_child(confirm)
			confirm.popup_centered()								
	)
	materials_list.empty_clicked.connect(empty_clicked)
	materials_list.material_table_changed.connect(update_materials_list)		
	%materials_search.text_changed.connect(update_materials_list)
	%add_material_button.pressed.connect(show_add_material_popup)
	
	update_static_body_list()
	static_body_list.item_selected.connect(show_static_body_in_file_system_dock)
	static_body_list.item_edited.connect(rename_static_body)
	%add_static_body_button.pressed.connect(add_static_body)
	%static_body_search.text_changed.connect(update_static_body_list)
	
func empty_clicked(_click_position,_mouse_button_index):
	if abs(empty_double_click_time - Time.get_ticks_msec()) < 320:
		show_add_material_popup()
	empty_double_click_time = Time.get_ticks_msec()
	
func add_materials_to_table(paths):	
	print(paths)
	for path in paths:
		if not path in AssetIOMaterials.get_material_table().values().map(func(a):return a.path):			
			AssetIOMaterials.update_material(-1, load(path))
	update_materials_list()
	
func show_add_material_popup():
	var popup = load("res://addons/m_terrain/asset_manager/ui/select_resources_by_type.tscn").instantiate()		
	popup.resources_selected.connect(add_materials_to_table)
	popup.select_multiple = true
	popup.types = ["StandardMaterial3D", "ShaderMaterial", "ORMMaterial3D"]
	popup.title = "Add Material(s)"
	add_child(popup)
	popup.popup()
	
func show_replace_material_popup():
	var popup:Window = preload("res://addons/m_terrain/asset_manager/ui/select_resources_by_type.tscn").instantiate()	
	popup.resources_selected.connect(replace_material)
	popup.types = ["StandardMaterial3D", "ShaderMaterial", "ORMMaterial3D"]		
	popup.title = "Replace Material: " + materials_list.get_selected().get_text(2)
	add_child(popup)
	popup.popup_centered()
	
func replace_material(new_path):
	var original_id = materials_list.get_selected().get_metadata(0)	
	AssetIOMaterials.update_material(original_id, load(new_path))		
	update_materials_list()
	
func update_materials_list(filter = null):	
	materials_list.clear()
	var root = materials_list.get_root()
	if not root:
		root = materials_list.create_item()		
	var material_table = AssetIOMaterials.get_material_table()	
	
	for i in material_table.keys():
		if filter and not filter in material_table[i].path: continue
		var item := root.create_child()
		item.set_text(0, str(i))
		item.set_metadata(0, i)		
		var mat = load(material_table[i].path) if FileAccess.file_exists(material_table[i].path) else null
		var is_mat_valid = mat!=null and mat is Material
		var mat_name = material_table[i].name
		if is_mat_valid:
			ThumbnailManager.thumbnail_queue.push_back({"resource":mat, "caller": item, "callback":update_material_icon })		
		else:
			mat_name += " [Invalid]"
			item.set_icon(1,load("res://addons/m_terrain/icons/no_images.png"))
		item.set_text(2, mat_name)		
		item.set_tooltip_text(2, material_table[i].path)		
		var img = Image.load_from_file(ProjectSettings.globalize_path("res://addons/m_terrain/icons/edit_icon.svg"))
		img.resize(24,24)
		var edit_button_texture = ImageTexture.create_from_image(img) 
		var remove_button_texture = preload("res://addons/m_terrain/icons/trash.svg")
		item.add_button(2, edit_button_texture)		
		item.add_button(2, remove_button_texture)	
		var glbs_using_material = AssetIOMaterials.get_glbs_using_material(i)
		if len(glbs_using_material) > 0:
			item.set_button_disabled(2, 1, true)
			item.set_button_tooltip_text(2,1,"Material still has meshes depending on it")						
			for glb_path in glbs_using_material:	
				var glb_item := item.create_child()
				glb_item.set_text(2, glb_path)
			item.collapsed = true

func update_material_icon(data):	
	data.caller.set_icon(1, data.texture)
	
func update_static_body_list(filter = null):
	var list = AssetIOMaterials.get_physics()
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
	
func show_material_in_file_system_dock() -> void:	
	var material_table = AssetIOMaterials.get_material_table()
	var sname = materials_list.get_selected().get_tooltip_text(2)
	if FileAccess.file_exists(sname):
		file_system_dock.navigate_to_path(sname)
		EditorInterface.edit_resource(load(sname))

func show_static_body_in_file_system_dock() -> void:	
	add_err.visible = false
	var list = AssetIOMaterials.get_physics()
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
	var list = AssetIOMaterials.get_physics()
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
	var list = AssetIOMaterials.get_physics()
	if list.has(sname):
		add_err.visible = true
		add_err.text = "Duplicate Setting Name"
		return false
	return true

func add_static_body() -> void:
	var list = AssetIOMaterials.get_physics()
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

static func get_physics_setting_id():
	pass
