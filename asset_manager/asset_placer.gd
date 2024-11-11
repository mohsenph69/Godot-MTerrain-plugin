#class_name Asset_Placer
@tool
extends PanelContainer

signal selection_changed

@onready var groups = find_child("groups")
@onready var ungrouped = find_child("ungrouped")
@onready var grouping_popup:Popup = find_child("grouping_popup")
@onready var search_collections_node:Control = find_child("search_collections")
@onready var group_by_button:Button = find_child("group_by_button")	

var asset_library := MAssetTable.get_singleton()
var current_selection := [] #array of collection name
var current_search := ""
var current_filter_mode_all := false
var current_filter_tags := []
var current_group := "None" #group name

var queued_thumbnails = {}

var last_regroup = null

func _ready():		
	if EditorInterface.get_edited_scene_root() == self: return

	asset_library.tag_set_name(1, "hidden")
	asset_library.finish_import.connect(func(_arg): 
		regroup()
	)			
	ungrouped.set_group("other")	
	regroup()	
	find_child("sort_popup").sort_mode_changed.connect(func(mode):
		regroup(current_group, mode)
	)
	
	#Connect signals for buttons	
	search_collections_node.text_changed.connect(search_items)	
	find_child("filter_popup").filter_changed.connect(func(tags,mode):		
		current_filter_tags = tags
		current_filter_mode_all = mode
		regroup()		
	)
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
	current_search = text		
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
	var result = []
	var collections_to_exclude = asset_library.tags_get_collections_any(tags_to_excluded) 
	var searched_collections = asset_library.collection_names_begin_with(text) if not text in [null, ""]  else asset_library.collection_get_list()		
	if current_filter_tags and len(current_filter_tags)>0:
		if current_filter_mode_all:		
			result = Array(asset_library.tags_get_collections_all(current_filter_tags))
		else:		
			result = Array(asset_library.tags_get_collections_any(current_filter_tags))	
	else:
		result = Array(searched_collections)		
	for id in result.duplicate():				
		if not id in searched_collections:			
			result.erase(id)		
		if id in collections_to_exclude:
			result.erase(id)			
	return result
	
func debounce_regroup():
	if last_regroup is int and Time.get_ticks_msec() - last_regroup < 1000:
		last_regroup = get_tree().create_timer(1)
		last_regroup.timeout.connect(func():
			last_regroup = 0
			regroup()
		)
		return false
	elif last_regroup is SceneTreeTimer:
		return false
	last_regroup = Time.get_ticks_msec()
	return true
	
func regroup(group = current_group, sort_mode="asc"):	
	if not debounce_regroup(): 
		return
	var filtered_collections = get_filtered_collections(current_search, [0])
	if current_group != group:		
		for child in groups.get_children():
			groups.remove_child(child)
			child.queue_free()
	if group == "None":		
		ungrouped.group_list.clear()	
		var sorted_items = []				
		for collection_id in filtered_collections:
			var collection_name = asset_library.collection_get_name(collection_id)
			var thumbnail = AssetIO.generate_collection_thumbnail(collection_id)			
			if not thumbnail:
				regroup.call_deferred()
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
			if current_filter_tags and len(current_filter_tags) >0:
				if not tag_id in current_filter_tags: 
					continue							
			var tag_name = asset_library.tag_get_name(tag_id)
			if tag_name == "": continue
			var group_control
			var sorted_items = []
			if not groups.has_node(tag_name):				
				group_control = group_control_scene.instantiate()								
				groups.add_child(group_control)							
				if not group_control.group_list:
					continue
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
				var thumbnail = AssetIO.generate_collection_thumbnail(collection_id)							
				if not thumbnail:
					regroup.call_deferred()
				sorted_items.push_back({"name": asset_library.collection_get_name(collection_id), "thumbnail":thumbnail, "id":collection_id})
				#group_control.add_item(asset_library.collection_get_name(collection_id), thumbnail, collection_id)							
			if sort_mode == "asc":
				sorted_items.sort_custom(func(a,b): return a.name < b.name)
			elif sort_mode == "desc":
				sorted_items.sort_custom(func(a,b): return a.name > b.name)
			for item in sorted_items:
				group_control.add_item(item.name, item.thumbnail, item.id)		
		ungrouped.group_list.clear()
		var sorted_items = []
		for id in filtered_collections:
			if not id in asset_library.tags_get_collections_any(asset_library.group_get_tags(group)):
				var thumbnail = AssetIO.generate_collection_thumbnail(id)
				print("generating thumbnail")
				sorted_items.push_back({"name": asset_library.collection_get_name(id), "thumbnail":thumbnail, "id":id})				
		if sort_mode == "asc":
			sorted_items.sort_custom(func(a,b): return a.name < b.name)
		elif sort_mode == "desc":
			sorted_items.sort_custom(func(a,b): return a.name > b.name)
		for item in sorted_items:			
			ungrouped.add_item(item.name, item.thumbnail, item.id)		
	current_group = group

func collection_item_activated(id, group_list:ItemList):						
	var node = MAssetMesh.new()
	node.collection_id = group_list.get_item_metadata(id)
	var selected_nodes = EditorInterface.get_selection().get_selected_nodes()	
	var scene_root = EditorInterface.get_edited_scene_root()	
	if len(selected_nodes) != 1:
		scene_root.add_child(node)		
	else:
		var parent = selected_nodes[0]
		while parent is MAssetMesh and parent != scene_root:
			parent = parent.get_parent()			
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
	
#region Debug	
#########
# DEBUG #
#########			
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
