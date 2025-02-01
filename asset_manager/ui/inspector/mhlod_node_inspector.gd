@tool extends Node

var mhlod_node: MHlodNode3D

func _ready():		
	if not mhlod_node: 
		print("No node")
		queue_free()
		return
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
		
		print("changed path of mhlodnode3d")	
	
	var label = Label.new()
	label.text= mhlod_node.scene_file_path
	add_child(label)
		
	
