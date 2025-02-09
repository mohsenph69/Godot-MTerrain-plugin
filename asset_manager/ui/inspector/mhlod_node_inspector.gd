@tool extends Node

var mhlod_node: MHlodNode3D
var asset_placer
var asset_library = MAssetTable.get_singleton()
var root_node:Node

func _ready():		
	root_node = EditorInterface.get_edited_scene_root()
	if root_node != mhlod_node:
		return
	if not mhlod_node and false:
		push_error("inspector plugin error: No mhlod_node3d node")
		return
	var collection_id = mhlod_node.get_meta("collection_id") if mhlod_node.has_meta("collection_id") else -1		
	if collection_id == -1:
		create_packed_scene_collection()
		asset_placer.assets_changed.emit(mhlod_node)

func _enter_tree():		
	if not EditorInterface.get_edited_scene_root().renamed.is_connected(rename_packed_scene):	 
		EditorInterface.get_edited_scene_root().renamed.connect(rename_packed_scene)

func _exit_tree():
	if EditorInterface.get_edited_scene_root().renamed.is_connected(rename_packed_scene):	 
		EditorInterface.get_edited_scene_root().renamed.disconnect(rename_packed_scene)
	
func create_packed_scene_collection():
	var item_id = int(mhlod_node.scene_file_path.get_file())
	if MHlod.get_packed_scene_path(item_id)!=mhlod_node.scene_file_path:
		printerr("Not a valid MHlodNode3D path!")
		return
	var new_collection_id = asset_library.collection_create(mhlod_node.name, item_id, MAssetTable.PACKEDSCENE,-1)
	asset_library.save()
	mhlod_node.set_meta("collection_id", new_collection_id)
	
func rename_packed_scene():		
	var collection_id = mhlod_node.get_meta("collection_id") if mhlod_node.has_meta("collection_id") else -1		
	# If creating a new collection
	if collection_id == -1:
		create_packed_scene_collection()
	else:
		asset_library.collection_set_name(collection_id,MAssetTable.PACKEDSCENE,mhlod_node.name)
	asset_placer.assets_changed.emit(mhlod_node)
