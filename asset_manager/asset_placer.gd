#class_name Asset_Placer
@tool
extends PanelContainer

signal selection_changed

@onready var groups = find_child("groups")
@onready var ungrouped = find_child("ungrouped")
@onready var grouping_popup:Popup = find_child("grouping_popup")
@onready var search_collections:Control = find_child("search_collections")
@onready var group_by_button:Button = find_child("group_by_button")	
var asset_library: MAssetTable = MAssetTable.get_singleton()
var current_selection = [] #array of collection name
var current_filter: String = ""
var current_group = "None" #group name

var queued_thumbnails = {}
var edit_window

func _ready():		
	if EditorInterface.get_edited_scene_root() == self: return

	asset_library.tag_set_name(1, "hidden")
	asset_library.finish_import.connect(func(_arg): 
		regroup()
	)	
	init_debug_buttons()
	
	ungrouped.set_group("other")	
	regroup()	
	find_child("sort_popup_menu").sort_mode_changed.connect(func(mode):
		regroup(current_group, mode)
	)
	
	#Connect signals for buttons	
	search_collections.text_changed.connect(search_items)	
	ungrouped.group_list.multi_selected.connect(func(id, selected):
		process_selection(ungrouped.group_list, id, selected)
	)
	ungrouped.group_list.item_activated.connect(collection_item_activated.bind(ungrouped.group_list))
	grouping_popup.group_selected.connect(regroup)	
			
	#Filters tags control
	var tags_control = find_child("Tags")	
	tags_control.set_options(asset_library.tag_get_names())
	tags_control.set_tags_from_data([])
	for child in tags_control.tag_list.get_children():
		child.set_editable(false)

func search_items(text=""):				
	current_filter = text		
	regroup()	
						
func _can_drop_data(at_position: Vector2, data: Variant):		
	if "files" in data and ".glb" in data.files[0]:
		return true

func _drop_data(at_position, data):		
	for file in data.files:
		AssetIO.glb_load(file)
		
####################
# GROUPS AND ITEMS #
####################
func get_filtered_collections(text="", tags_to_excluded=[]):
	print("filter: ", text)
	var filterered_collections = asset_library.collection_names_begin_with(text) if text != "" else asset_library.collection_get_list()	
	filterered_collections = Array(filterered_collections).filter(func(a): return not a in asset_library.tags_get_collections_any(tags_to_excluded) )	
	return filterered_collections
	
func regroup(group = current_group, sort_mode="asc"):				
	var filtered_collections = get_filtered_collections(current_filter, [0])
	if current_group != group:		
		for child in groups.get_children():
			groups.remove_child(child)
			child.queue_free()
	if group == "None":		
		ungrouped.group_list.clear()	
		var sorted_items = []				
		for collection_id in filtered_collections:
			var collection_name = asset_library.collection_get_name(collection_id)
			var thumbnail = null
			var thumbnail_path = str("res://massets/thumbnails/", collection_id, ".png")
			if FileAccess.file_exists(thumbnail_path):
				thumbnail = load(thumbnail_path)
			sorted_items.push_back({"name":collection_name, "thumbnail":thumbnail, "id":collection_id})			
			collection_id += 1
		if sort_mode == "asc":
			sorted_items.sort_custom(func(a,b): return a.name < b.name)
		elif sort_mode == "desc":
			sorted_items.sort_custom(func(a,b): return a.name > b.name)
		for item in sorted_items:
			ungrouped.add_item(item.name, item.thumbnail, item.id)							
		ungrouped.group_button.visible = false	
	elif group in asset_library.group_get_list():
		ungrouped.group_button.visible = true
		var group_control_scene = preload("res://addons/m_terrain/asset_manager/ui/group_control.tscn")		
		for tag_id in asset_library.group_get_tags(group):
			var tag_name = asset_library.tag_get_name(tag_id)
			if tag_name == "": continue
			var group_control
			var sorted_items = []
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
				sorted_items.push_back({"name": asset_library.collection_get_name(collection_id), "thumbnail":thumbnail, "id":collection_id})
				#group_control.add_item(asset_library.collection_get_name(collection_id), thumbnail, collection_id)							
			if sort_mode == "asc":
				sorted_items.sort_custom(func(a,b): return a.name < b.name)
			elif sort_mode == "desc":
				sorted_items.sort_custom(func(a,b): return a.name > b.name)
			for item in sorted_items:
				group_control.add_item(item.name, item.thumbnail, item.id)		
		ungrouped.group_list.clear()
		for id in filtered_collections:
			if not id in asset_library.tags_get_collections_any(asset_library.group_get_tags(group)):
				var thumbnail = null
				ungrouped.add_item(asset_library.collection_get_name(id), thumbnail, id )
	current_group = group

func collection_item_activated(id, group_list:ItemList):					
	#var node = AssetIO.collection_instantiate(group_list.get_item_metadata(id))		
	#node.set_meta("collection_id", group_list.get_item_metadata(id))	
	var node = MAssetMesh.new()
	node.collection_id = group_list.get_item_metadata(id)
	var selected_nodes = EditorInterface.get_selection().get_selected_nodes()	
	var scene_root = EditorInterface.get_edited_scene_root()	
	if len(selected_nodes) != 1:
		scene_root.add_child(node)
		if scene_root is HLod_Baker:
			update_lod_limit(node)
	else:
		var parent = selected_nodes[0]
		while parent is MAssetMesh and parent != scene_root:
			parent = parent.get_parent()			
		selected_nodes[0].add_child(node)
		update_lod_limit(node)
	node.owner = EditorInterface.get_edited_scene_root()
	node.name = group_list.get_item_text(id)	

func update_lod_limit(node_added: Node3D):	
	if not node_added.is_inside_tree():
		return
	var hlod_baker = node_added
	while not hlod_baker is HLod_Baker and not hlod_baker == EditorInterface.get_edited_scene_root():
		hlod_baker = hlod_baker.get_parent()
	if hlod_baker is HLod_Baker:		
		for child:MAssetMesh in node_added.find_children("*", "MAssetMesh", true, false):
			child.lod_limit = hlod_baker.join_at_lod
	
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
	asset_library.collection_remove_tag(collection_id, 0)	
	asset_library.collection_remove(collection_id)	
	var path = str("res://massets/thumbnails/", collection_id, ".png")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	
#region Thumbnails
##############
# THUMBNAILS #
##############
func generate_thumbnails_for_selected_collections():
	queued_thumbnails = {}
	print(current_selection)
	for collection_name in current_selection:
		var collection_id = asset_library.collection_get_id(collection_name)		
		var data = {"meshes":[], "transforms":[]}
		combine_collection_meshes_and_transforms_recursive(collection_id, data, Transform3D.IDENTITY)													
		var mesh_joiner := MMeshJoiner.new()					
		mesh_joiner.insert_mesh_data(data.meshes, data.transforms, data.transforms.map(func(a):return -1))
		var mesh = mesh_joiner.join_meshes()	
		queued_thumbnails[collection_id] = {"mesh":mesh, "generated": false}		
	var collection_id = queued_thumbnails.keys()[0]
	EditorInterface.get_resource_previewer().queue_edited_resource_preview(queued_thumbnails[collection_id].mesh, self, "save_thumbnail", collection_id)					
	

func combine_collection_meshes_and_transforms_recursive(collection_id, data, combined_transform):
	var subcollection_ids = asset_library.collection_get_sub_collections(collection_id)
	var subcollection_transforms = asset_library.collection_get_sub_collections_transforms(collection_id)
	if len(subcollection_ids) > 0:
		for i in len(subcollection_ids):
			combine_collection_meshes_and_transforms_recursive(subcollection_ids[i], data, combined_transform * subcollection_transforms[i])
	var mesh_items = asset_library.collection_get_mesh_items_info(collection_id)	
	for item in mesh_items:
		var i = 0
		while i < len(item.mesh):			
			if item.mesh[i] == -1: 
				i += 1
				continue
			var mesh_path = MHlod.get_mesh_path(item.mesh[i])													
			var mesh:Mesh = load(mesh_path)
			if mesh.get_surface_count() > 0:		
				data.meshes.push_back(mesh)
				data.transforms.push_back(combined_transform * item.transform)
				break	
			i+= 1
			
func save_thumbnail(path, preview, thumbnail_preview, this_collection_id):			
	#Save the current one 	
	if not DirAccess.dir_exists_absolute("res://massets/thumbnails/"):
		DirAccess.make_dir_recursive_absolute("res://massets/thumbnails/")
	var thumbnail_path = str("res://massets/thumbnails/", this_collection_id,".png")
	if FileAccess.file_exists(thumbnail_path):
		preview.take_over_path(thumbnail_path)
	else:
		ResourceSaver.save(preview, thumbnail_path )										
	queued_thumbnails[this_collection_id].generated = true
	#Queue the next one if there are more
	for collection_id in queued_thumbnails.keys():
		if queued_thumbnails[collection_id].generated == true:
			continue
		EditorInterface.get_resource_previewer().queue_edited_resource_preview(queued_thumbnails[collection_id].mesh, self, "save_thumbnail", collection_id)							
		return
	#If the queue is finished, then refresh	
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
