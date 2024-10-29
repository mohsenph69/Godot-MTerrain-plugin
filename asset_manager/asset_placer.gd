#class_name Asset_Placer
@tool
extends PanelContainer

signal selection_changed

@onready var groups = find_child("groups")
@onready var ungrouped = find_child("other")
@onready var grouping_popup_menu:PopupMenu = find_child("grouping_popup_menu")
@onready var search_collections:LineEdit = find_child("search_collections")
@onready var group_by_button = find_child("group_by_button")
	
var asset_library: MAssetTable = MAssetTable.get_singleton()
var current_selection = [] #array of collection id
var current_group = "None" #group name
func _ready():		
	asset_library.tag_set_name(1, "hidden")
	asset_library.finish_import.connect(func(_arg): 
		regroup())	
	init_debug_buttons()
	
	ungrouped.set_group("other")	
	regroup()	
	
	#Connect signals for buttons	
	search_collections.text_changed.connect(search_items)	
	ungrouped.group_list.multi_selected.connect(func(id, selected):
		process_selection(ungrouped.group_list, id, selected)
	)
	ungrouped.group_list.item_activated.connect(collection_item_activated.bind(ungrouped.group_list))
	grouping_popup_menu.index_pressed.connect(func(i):
		regroup(grouping_popup_menu.get_item_text(i))
	)	
	find_child("edit_button").pressed.connect(edit_pressed)
	group_by_button.pressed.connect(group_by_pressed)
	
	#Filters tags control
	var tags_control = find_child("Tags")	
	tags_control.set_options(asset_library.tag_get_names())
	tags_control.set_tags_from_data([])
	for child in tags_control.tag_list.get_children():
		child.set_editable(false)

	

func search_items(text):				
	var filtered_collections = asset_library.collection_names_begin_with(text) if text != "" else asset_library.collection_get_list()			
	regroup(current_group, filtered_collections)							

func group_by_pressed():	
	update_grouping_options()		
	grouping_popup_menu.visible = true
	grouping_popup_menu.position.x = group_by_button.global_position.x
	grouping_popup_menu.position.y = group_by_button.size.y + global_position.y
	
func edit_pressed():
	var popup = Window.new()
	popup.wrap_controls = true
	popup.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	popup.close_requested.connect(popup.queue_free)
	var settings_control = preload("res://addons/m_terrain/asset_manager/ui/asset_manager_settings.tscn").instantiate()		
	popup.add_child(settings_control)
	add_child(popup)		
	popup.popup_centered(Vector2i(0,0))
	popup.window_input.connect(func(e): if e is InputEventKey and e.keycode == KEY_ESCAPE: popup.queue_free())

func update_grouping_options():
	grouping_popup_menu.clear()
	grouping_popup_menu.add_item("None")	
	#for category in categories:		
	for category in asset_library.group_get_list():
		grouping_popup_menu.add_item(category)
		
func _can_drop_data(at_position: Vector2, data: Variant):		
	if "files" in data and ".glb" in data.files[0]:
		return true

func _drop_data(at_position, data):		
	for file in data.files:
		AssetIO.glb_load(file)
		
####################
# GROUPS AND ITEMS #
####################
func regroup(group = "None", filtered_collections = asset_library.collection_get_list()):			
	filtered_collections = Array(filtered_collections).filter(func(a): return not a in asset_library.tag_get_collections(1))
	if current_group != group:		
		for child in groups.get_children():
			groups.remove_child(child)
			child.queue_free()
	if group == "None":		
		ungrouped.group_list.clear()						
		for collection_id in filtered_collections:
			var collection_name = asset_library.collection_get_name(collection_id)
			var thumbnail = null
			var thumbnail_path = str("res://massets/thumbnails/", collection_id, ".png")
			if FileAccess.file_exists(thumbnail_path):
				thumbnail = load(thumbnail_path)
			ungrouped.add_item(collection_name, thumbnail, collection_id)	
			collection_id += 1
		#for collection in asset_library.data.collections:							
		ungrouped.group_button.visible = false	
	elif group in asset_library.group_get_list():
		ungrouped.group_button.visible = true
		var group_control_scene = preload("res://addons/m_terrain/asset_manager/ui/group_control.tscn")		
		for tag_id in asset_library.group_get_tags(group):
			var tag_name = asset_library.tag_get_name(tag_id)
			if tag_name == "": continue
			var group_control
			if not groups.has_node(tag_name):						
				group_control = group_control_scene.instantiate()								
				groups.add_child(group_control)			
				group_control.group_list.multi_selected.connect(func(id, selected):
					process_selection(group_control.group_list, id, selected)
				)
				group_control.set_group(asset_library.tag_get_name(tag_id))					
				group_control.group_list.item_activated.connect(collection_item_activated.bind(group_control.group_list))
				group_control.name = tag_name
			else:
				group_control = groups.get_node(tag_name)			
				group_control.group_list.clear()
			for collection_id in asset_library.tag_get_collections_in_collections(filtered_collections, tag_id):
				var thumbnail = null								
				group_control.add_item(asset_library.collection_get_name(collection_id), thumbnail, collection_id)							
		ungrouped.group_list.clear()
		for id in filtered_collections:
			if not id in asset_library.tags_get_collections_any(asset_library.group_get_tags(group)):
				var thumbnail = null
				ungrouped.add_item(asset_library.collection_get_name(id), thumbnail, id )
	current_group = group

func collection_item_activated(id, group_list:ItemList):					
	var node = AssetIO.collection_instantiate(group_list.get_item_metadata(id))	
	#node.set_meta("collection_id", group_list.get_item_metadata(id))	
	var selected_nodes = EditorInterface.get_selection().get_selected_nodes()	
	if len(selected_nodes) == 0:
		EditorInterface.get_edited_scene_root().add_child(node)
	elif len(selected_nodes) == 1:
		selected_nodes[0].add_child(node)
	node.owner = EditorInterface.get_edited_scene_root()
	node.name = group_list.get_item_text(id)	

func process_selection(who:ItemList, id, selected):
	current_selection = []
	var all_groups = groups.get_children().map(func(a): return a.group_list)
	all_groups.push_back(ungrouped.group_list)
	for group in all_groups:
		if not Input.is_key_pressed(KEY_SHIFT) and not Input.is_key_pressed(KEY_CTRL) and group != who:
			group.deselect_all()	
		else:
			for item in	group.get_selected_items():
				current_selection.push_back( group.get_item_text(item) )
	selection_changed.emit()

func remove_asset(collection_id):
	for i in asset_library.collection_get_mesh_items_ids(collection_id):
		asset_library.mesh_item_remove(i)			
	asset_library.collection_remove(collection_id)
	
#region Thumbnails
##############
# THUMBNAILS #
##############
func generate_thumbnails_for_selected_collections():
	for collection_name in current_selection:
		var collection_id = asset_library.collection_get_id(collection_name)
		if collection_id in asset_library.tag_get_collections(0):
			var mesh_item = asset_library.collection_get_mesh_items_info(collection_id)
			var i = 0
			while i < len(mesh_item[0].mesh):
				var mesh_path = MHlod.get_mesh_path(mesh_item[0].mesh[i])													
				var mesh:Mesh = load(mesh_path)
				if mesh.get_surface_count() > 0:												
					EditorInterface.get_resource_previewer().queue_edited_resource_preview(mesh, self, "save_thumbnail", collection_id)								
					break
				i += 1
		else:							
			var data = {"meshes":[], "transforms":[]}
			combine_collection_meshes_and_transforms_recursive(collection_id, data, Transform3D.IDENTITY)											
			var mesh_joiner := MMeshJoiner.new()					
			mesh_joiner.insert_mesh_data(data.meshes, data.transforms, data.transforms.map(func(a):return -1))
			var mesh = mesh_joiner.join_meshes()	
			EditorInterface.get_resource_previewer().queue_edited_resource_preview(mesh, self, "save_thumbnail", collection_id)								
			var selected = EditorInterface.get_selection().get_selected_nodes()[0]
			if selected is MeshInstance3D:
				selected.mesh = mesh


func combine_collection_meshes_and_transforms_recursive(collection_id, data, combined_transform):
	var subcollection_ids = asset_library.collection_get_sub_collections(collection_id)
	var subcollection_transforms = asset_library.collection_get_sub_collections_transforms(collection_id)
	if len(subcollection_ids) > 0:
		for i in len(subcollection_ids):
			combine_collection_meshes_and_transforms_recursive(subcollection_ids[i], data, combined_transform * subcollection_transforms[i])
	else:
		var mesh_items = asset_library.collection_get_mesh_items_info(collection_id)
		var i = 0
		while i < len(mesh_items[0].mesh):
			var mesh_path = MHlod.get_mesh_path(mesh_items[0].mesh[i])													
			var mesh:Mesh = load(mesh_path)
			if mesh.get_surface_count() > 0:		
				data.meshes.push_back(mesh)
				data.transforms.push_back(combined_transform)
				break	
			
func save_thumbnail(path, preview, thumbnail_preview, collection_id):	
	if not DirAccess.dir_exists_absolute("res://massets/thumbnails/"):
		DirAccess.make_dir_recursive_absolute("res://massets/thumbnails/")
	ResourceSaver.save(preview, str("res://massets/thumbnails/", collection_id,".png") )								
	var fs := EditorInterface.get_resource_filesystem()	
	if not fs.resources_reimported.is_connected(resources_reimported):
		fs.resources_reimported.connect(resources_reimported)	
	fs.scan()	

func resources_reimported(paths):
	for path in paths:
		if "res://massets/thumbnails" in path:
			regroup()
			return
#endregion
#region Debug	
#########
# DEBUG #
#########			
func init_debug_buttons():
	%clear_assets.pressed.connect(func():
		for collection_id in asset_library.collection_get_list():
			remove_asset(collection_id)
			asset_library.import_info = {}
			asset_library.save()
		regroup()
	)	
	%remove_asset.pressed.connect(func():
		for collection_name in current_selection:
			var collection_id = asset_library.collection_get_id(collection_name)			
			remove_asset(collection_id)
		regroup()
	)
	%generate_thumbnails_button.pressed.connect(generate_thumbnails_for_selected_collections)

func init_debug_tags():
	var groups = {"colors": [0,1,2], "sizes":[3,4,5], "building_parts": [6,7,8,9]}   #data.categories
	var tags = ["red", "green", "blue", "small", "medium", "large", "wall", "floor", "roof", "door"]#data.tags		
	asset_library.tag_set_name(0, "single_item_collection")
	asset_library.tag_set_name(1, "hidden")
	for tag in tags:
		if asset_library.tag_get_id(tag) == -1:
			for j in 256:
				if j < 2: continue #0: single_item_collection, 1: hidden
				if asset_library.tag_get_name(j) == "":
					asset_library.tag_set_name(j, tag)
					break
			#asset_library.tag_add(tag)					
	for group in groups:
		if not asset_library.group_exist(group):			
			asset_library.group_create(group)
		for i in groups[group]:				
			var tag_name = tags[i]
			var tag_id = asset_library.tag_get_id(tag_name)
			asset_library.group_add_tag(group, tag_id)			
	asset_library.save()	
#endregion
