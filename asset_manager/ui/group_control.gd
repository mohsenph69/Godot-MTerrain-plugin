@tool
extends VBoxContainer

signal collection_activated

@onready var group_button:Button = find_child("group_button")
@onready var group_container = find_child("group_container")
@onready var group_list:ItemList = find_child("group_list")

func _ready():
	#if not EditorInterface.get_edited_scene_root() or EditorInterface.get_edited_scene_root() == self or EditorInterface.get_edited_scene_root().is_ancestor_of(self): return

	group_button.toggled.connect(func(toggle_on):
		group_container.visible = toggle_on	
	)
	group_list.clear()			
	
func set_group(group_name):
	name = group_name
	group_button.text = group_name

func add_item(item_name, item):
	var i = group_list.add_item(item_name)	
	group_list.set_item_tooltip(i, item_name)
	group_list.set_item_metadata(i, item)
	var asset_library:MAssetTable = MAssetTable.get_singleton() #load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))
	group_list.set_item_tooltip(i, str(item_name))
	set_icon(i) # should be called last

func get_item_collection_id(item_index:int)->int:
	return group_list.get_item_metadata(item_index)

## Set icon with no dely if thumbnail is valid
func set_icon(item_index:int)->void:
	var current_item_collection_id:int= get_item_collection_id(item_index)
	var tex:Texture2D= ThumbnailManager.get_valid_thumbnail(current_item_collection_id)
	if tex != null:
		group_list.set_item_icon(item_index,tex)
		group_list.set_item_text(item_index, "")
		return
	var _cmesh = MAssetMesh.get_collection_merged_mesh(current_item_collection_id,true)
	if _cmesh:		
		ThumbnailManager.thumbnail_queue.push_back({"resource": _cmesh, "caller": item_index, "callback": update_thumbnail, "collection_id": current_item_collection_id})	
		
func update_thumbnail(data):
	if not data.texture is Texture2D:
		push_warning("thumbnail error: ", group_button.name, " item ", data.caller)
	var asset_library = MAssetTable.get_singleton()
	var thumbnail_path = asset_library.get_asset_thumbnails_path(data.collection_id)
	### Updating Cache
	ThumbnailManager.save_thumbnail(data.texture, thumbnail_path)
	## This function excute with delay we should check if item collection id is not changed	
	if get_item_collection_id(data.caller) == data.collection_id:			
		group_list.set_item_icon(data.caller,data.texture)
		group_list.set_item_text(data.caller, "")
