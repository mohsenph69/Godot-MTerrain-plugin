@tool
extends VBoxContainer

signal collection_activated

@onready var group_button:Button = find_child("group_button")
@onready var group_container = find_child("group_container")
@onready var group_list:ItemList = find_child("group_list")


## item indices which should be generated!
## I think there is a bug in queue_edited_resource_preview which sometimes cause two resource have same thumbnail
## we seperate the work of item generator to each frame and hope that works fine!
var item_thmbnail_queue:PackedInt32Array
var generating_thumbnail:=false ## stop generating when there is a gen process

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
	group_list.set_item_metadata(i, item)
	var asset_library:MAssetTable = MAssetTable.get_singleton() #load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))
	group_list.set_item_tooltip(i, str(item_name))
	set_icon(i) # should be called last

func get_item_collection_id(item_index:int)->int:
	return group_list.get_item_metadata(item_index)

## Set icon with no dely if thumbnail is valid
func set_icon(item_index:int)->void:
	var current_item_collection_id:int= get_item_collection_id(item_index)
	var tex:Texture2D= get_valid_thumbnail(current_item_collection_id)
	if tex != null:
		group_list.set_item_icon(item_index,tex)
		return
	item_thmbnail_queue.push_back(item_index)
	set_process(true)

func _process(delta: float) -> void:
	if item_thmbnail_queue.size() == 0:
		set_process(false)
		return
	if generating_thumbnail:
		return
	var item_index = item_thmbnail_queue[item_thmbnail_queue.size()-1]
	item_thmbnail_queue.remove_at(item_thmbnail_queue.size()-1)
	var current_item_collection_id:int= get_item_collection_id(item_index)
	# gen
	var _cmesh = MAssetMesh.get_collection_merged_mesh(current_item_collection_id,true)
	if not _cmesh:
		printerr("Mesh with collection id of %d is null " % current_item_collection_id)
		return
	var _rp = EditorInterface.get_resource_previewer()
	var _input:PackedInt32Array = [item_index,current_item_collection_id]
	#ResourceSaver.save(_cmesh,MAssetTable.get_asset_thumbnails_dir()+str(current_item_collection_id)+".res")
	generating_thumbnail = true
	_rp.queue_edited_resource_preview(_cmesh,self,"handle_generate_thumbnail",_input)

func handle_generate_thumbnail(path, preview, thumbnail_preview,_input):
	var collection_id = _input[1]
	var item_index = _input[0]
	var thumbnail_path = AssetIO.get_thumbnail_path(collection_id)
	### Updating Cache
	MAssetTable.get_singleton().collection_set_cache_thumbnail(collection_id,preview,Time.get_unix_time_from_system())
	#print("Saving item index ",item_index, " col_id ",collection_id, " to ",thumbnail_path)
	AssetIO.save_thumbnail(preview, thumbnail_path)
	## This function excute with delay we should check if item collection id is not changed
	if get_item_collection_id(item_index) == collection_id:
		group_list.set_item_icon(item_index,preview)
	generating_thumbnail = false

# if return null thumbnail shoud regenrate
func get_valid_thumbnail(collection_id:int)->Texture2D:
	var tex = MAssetTable.get_singleton().collection_get_cache_thumbnail(collection_id)
	var creation_time = MAssetTable.get_singleton().collection_get_thumbnail_creation_time(collection_id)
	if tex==null or creation_time < 0:
		var thumbnail_path = MAssetTable.get_asset_thumbnails_path(collection_id)
		if not FileAccess.file_exists(thumbnail_path): return null
		tex = AssetIO.get_thumbnail(thumbnail_path)
		if tex==null: return null
		creation_time = FileAccess.get_modified_time(thumbnail_path)
		# updating cache
		MAssetTable.get_singleton().collection_set_cache_thumbnail(collection_id,tex,creation_time)
	creation_time += 1.5
	if AssetIO.get_collection_import_time(collection_id) > creation_time:
		return null
	return tex
