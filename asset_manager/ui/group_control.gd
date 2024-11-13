@tool
extends VBoxContainer

signal collection_activated

@onready var group_button:Button = find_child("group_button")
@onready var group_container = find_child("group_container")
@onready var group_list:ItemList = find_child("group_list")

func _ready():
	if EditorInterface.get_edited_scene_root() == self or EditorInterface.get_edited_scene_root().is_ancestor_of(self): return

	group_button.toggled.connect(func(toggle_on):
		group_container.visible = toggle_on	
	)
	group_list.clear()			
	
func set_group(group_name):
	name = group_name
	group_button.text = group_name

func add_item(item_name, item_icon, item):
	var i = group_list.add_item(item_name, item_icon)
	group_list.set_item_metadata(i, item)
	var asset_library:MAssetTable = MAssetTable.get_singleton() #load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))
	group_list.set_item_tooltip(i, str(item_name,": ", asset_library.collection_get_mesh_items_info(item) ))
	
