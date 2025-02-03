@tool extends Node

var mhlod_node: MHlodNode3D
var asset_placer
var renamed_name: String =""
var asset_library = MAssetTable.get_singleton()

func _ready():		
	if not mhlod_node: 
		push_error("inspector plugin error: No mhlod_node3d node")
		queue_free()
		return		
	var collection_id = mhlod_node.get_meta("collection_id") if mhlod_node.has_meta("collection_id") else -1		
	if collection_id == -1:
		create_packed_scene_collection()
	if mhlod_node.scene_file_path.is_empty() or mhlod_node.scene_file_path != MHlod.get_packed_scene_path( int(mhlod_node.scene_file_path.get_file())):				
		var id = mhlod_node.get_meta("packed_scene_id") if mhlod_node.has_meta("packed_scene_id") else MAssetTable.get_last_free_packed_scene_id()		
		mhlod_node.set_meta("packed_scene_id", id)
		var new_path = MHlod.get_packed_scene_path(id)
		var old_path = mhlod_node.scene_file_path
		var packed_scene := PackedScene.new()
		mhlod_node.scene_file_path = new_path					
		packed_scene.pack(mhlod_node)		
		if not DirAccess.dir_exists_absolute(new_path.get_base_dir()):
			DirAccess.make_dir_absolute(new_path.get_base_dir())
		if old_path.is_empty():			
			ResourceSaver.save(packed_scene, new_path)
		else:											
			packed_scene.take_over_path(old_path)										
			if mhlod_node == EditorInterface.get_edited_scene_root():						
				DirAccess.rename_absolute(old_path, new_path)						
				EditorInterface.reload_scene_from_path.call_deferred(new_path)
			else:
				ResourceSaver.save(packed_scene, new_path)		
		EditorInterface.get_resource_filesystem().scan.call_deferred()				
					
	#var label = Label.new()
	#label.text= mhlod_node.scene_file_path
	#add_child(label)
		
func _enter_tree():		
	if not EditorInterface.get_edited_scene_root().renamed.is_connected(rename_packed_scene):	 
		EditorInterface.get_edited_scene_root().renamed.connect(rename_packed_scene)

func _exit_tree():
	if EditorInterface.get_edited_scene_root().renamed.is_connected(rename_packed_scene):	 
		EditorInterface.get_edited_scene_root().renamed.disconnect(rename_packed_scene)
	
func create_packed_scene_collection():
	var i = 0
	var new_name = mhlod_node.name
	var new_collection_id = asset_library.collection_get_id(new_name)
	while new_collection_id != -1:			
		new_collection_id = asset_library.collection_get_id(new_name)
		i+= 1
		new_name = mhlod_node.name + "_" + str(i)
	var item_id = int(mhlod_node.scene_file_path.get_file())		
	new_collection_id = asset_library.collection_create(new_name, item_id, MAssetTable.PACKEDSCENE,-1)
	
	asset_library.save()	
	mhlod_node.set_meta("collection_id", new_collection_id)
	renamed_name = new_name
	mhlod_node.name = new_name
	
func rename_packed_scene():		
	if renamed_name == mhlod_node.name:
		renamed_name = ""
		return	
	var collection_id = mhlod_node.get_meta("collection_id") if mhlod_node.has_meta("collection_id") else -1		
	# If creating a new collection
	if collection_id == -1:
		create_packed_scene_collection()		
	# If new name is taken by other collection, reset to old name
	elif not asset_library.collection_get_id(mhlod_node.name) in [-1, collection_id]:
		mhlod_node.name = asset_library.collection_get_name(collection_id)
	# If renaming existing collection
	else:		
		asset_library.collection_create(mhlod_node.name, int(mhlod_node.scene_file_path.get_file()), MAssetTable.PACKEDSCENE,-1)
		asset_placer.regroup()
		
