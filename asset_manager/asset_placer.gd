#class_name Asset_Placer
#
# Asset Library Functionality:
# - Items
#	- add item
#	- remove item
#	- get item id (has item)
#	- get item mesh_array
#	- get item material_array
#	- remove all items
# - Collections
#	- add collection
#	- remove collection
#	- rename collection
#	- remove all collections
#	- add item to collection
#	- remove item from collection
#	- add tag to collection
#	- remove tag from collection
#	- get collection by id
#	- get collection by name
#	- get collections names by ids
# - Tags
#	- add tag
#	- remove tag
#	- rename tag
#	- get all tag names
#	- get tag by name
#	- get tag by id
#	- search tag names
# - Groups
#	- add group
#	- remove group
#	- rename group
#	- add tag to group
#	- remove tag from group
#	- get all groups
#	- get tags in group
#	- get group by name
#	- get group by id
#	- get collections by group ( returns dictionary: {tag1: [collection 0,collection1]}, {tag2:[collection2,collection3]}

@tool
extends PanelContainer

signal selection_changed

@onready var groups = find_child("groups")
@onready var ungrouped: = find_child("other")
@onready var grouping_popup_menu:PopupMenu = find_child("grouping_popup_menu")
@onready var search_collections:LineEdit = find_child("search_collections")

var current_selection = []
var current_category = "None"
#LOAD FROM DB:
#var categories 
var collections= []
#var tags

var asset_library: MAssetTable = Asset_Manager_IO.get_asset_library()

func _ready():	
	#categories = {"colors": [0,1,2], "sizes":[3,4,5], "building_parts": [6,7,8,9]}   #data.categories
	#tags = ["red", "green", "blue", "small", "medium", "large", "wall", "floor", "roof", "door"]#data.tags	
	
	
	#if not asset_library.has_collection(0):
	#	asset_library.collection_create("first collection")
	
#	search_collections.text_changed.connect(func(text):		
#		Array(asset_library.collection_names_begin_with(text)).map(func(a): return asset_library.collection_get_name(a))
#		asset_library.tag_get_collections()
#	)
	
	grouping_popup_menu.index_pressed.connect(func(id):		
		regroup(grouping_popup_menu.get_item_text(id))			
	)
	ungrouped.set_group("other")	

	regroup()	
	ungrouped.group_list.multi_selected.connect(func(id, selected):
		process_selection(ungrouped.group_list, id, selected)
	)
	var tags_control = find_child("Tags")	
	tags_control.set_options(asset_library.tag_get_names())
	tags_control.set_tags_from_data([])
	for child in tags_control.tag_list.get_children():
		child.set_editable(false)

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
		import_gltf(file)
		
func import_gltf(path):		
	Asset_Manager_IO.update_from_glb(asset_library, path)
	regroup(current_category)
			
func regroup(category = "None"):
	current_category = category
	for child in groups.get_children():
		groups.remove_child(child)
		child.queue_free()
	if category == "None":		
		ungrouped.group_list.clear()		
				
		for collection_id in asset_library.collection_get_list():
			var collection_name = asset_library.collection_get_name(collection_id)
			var thumbnail = null # load(.../thumbnails/" + collection_name + ".png")
			ungrouped.add_item(collection_name, thumbnail, collection_id)	
			collection_id += 1
		#for collection in asset_library.data.collections:							
		ungrouped.group_button.visible = false
	#elif category in categories:
	elif category in asset_library.group_get_list():
		ungrouped.group_button.visible = true
		var group_control_scene = preload("res://addons/m_terrain/asset_manager/ui/group_control.tscn")
		for tag_id in asset_library.group_get_tags(category):
			if asset_library.tag_get_name(tag_id) == "": continue
			var group_control = group_control_scene.instantiate()								
			groups.add_child(group_control)			
			group_control.group_list.multi_selected.connect(func(id, selected):
				process_selection(group_control.group_list, id, selected)
			)						
			#group_control.set_group(tags[tag_id])
			group_control.set_group(asset_library.tag_get_name(tag_id))
			print("adding ", asset_library.tag_get_name(tag_id))
			ungrouped.group_list.clear()						
			for collection_id in asset_library.tags_get_collections_any([tag_id]):
				group_control.add_item(asset_library.collection_get_name(collection_id))							
			#else:
				#ungrouped.add_item(collection.resource_name, thumbnail, collection)
					
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

func get_all_items():
	var result = []
	for collection in collections:
		for item in collections[collection].items:
			if not item in result:
				result.push_back(item)
	return result
