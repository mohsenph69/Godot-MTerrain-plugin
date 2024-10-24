@tool
extends VBoxContainer

var object

func _ready():
	if not is_instance_valid(object) or not object.has_method("bake_to_hlod_resource"): return	
	%BakePath.text = object.bake_path
	%BakePath.text_changed.connect(	func(text): 
		object.bake_path = text
		%Bake.disabled = not text.ends_with(".res")
	)
	%select_bake_path.pressed.connect(func():
		var popup := FileDialog.new()
		popup.access = FileDialog.ACCESS_RESOURCES
		popup.add_filter("*.res")
		popup.file_mode =FileDialog.FILE_MODE_SAVE_FILE
		popup.file_selected.connect(func(path):
			%BakePath.text = path
			object.bake_path = path
		)
		add_child(popup)	
		popup.popup_centered(Vector2i(300,500))		
	)	
	%Bake.pressed.connect(object.bake_to_hlod_resource)		
		
	%JoinLod.value = object.join_at_lod
	%JoinLod.max_value = AssetIO.LOD_COUNT-1
	%JoinLod.value_changed.connect(func(value): 
		object.join_at_lod = value
		%Join.disabled = not can_join_mesh() 
	)	
	%Join.pressed.connect(func():		
		var root_node = Node3D.new()
		var mesh_instance = MeshInstance3D.new()
		root_node.add_child(mesh_instance)
		
		mesh_instance.name = object.name.to_lower() + "_joined_mesh_lod_" + str(object.join_at_lod)
		mesh_instance.mesh = object.make_joined_mesh()				
		mesh_instance.mesh.resource_name = mesh_instance.name		
		AssetIO.glb_export(root_node, object.joined_mesh_export_path)
		AssetIO.glb_load(object.joined_mesh_export_path)
		var collection_name = object.name.to_lower() + "_joined_mesh"
		var collection_id = MAssetTable.get_singleton().collection_get_id(collection_name)
		if collection_id != -1:
			var joined_mesh_collection = AssetIO.collection_instantiate(collection_id)
			var current_joined_mesh_node = object.find_child(joined_mesh_collection.name + "*")
			if is_instance_valid(current_joined_mesh_node):
				object.remove_child(current_joined_mesh_node)
				current_joined_mesh_node.queue_free()
			object.add_child(joined_mesh_collection)
			joined_mesh_collection.owner = object				
			object.joined_mesh_node = joined_mesh_collection
			for node in object.meshes_to_join:
				node.set_meta("max_lod", object.join_at_lod-1 )		
	)
	
	%joined_mesh_export_path.text = object.joined_mesh_export_path
	%joined_mesh_export_path.text_changed.connect(func(text):
		object.joined_mesh_export_path = text
		%Join.disabled = not can_join_mesh()
	)
	%select_joined_mesh_export_path.pressed.connect(func():
		var popup := FileDialog.new()
		popup.access = FileDialog.ACCESS_RESOURCES
		popup.add_filter("*.glb")
		popup.file_mode =FileDialog.FILE_MODE_SAVE_FILE
		popup.file_selected.connect(func(path):
			%joined_mesh_export_path.text = path
			object.joined_mesh_export_path = path
		)
		add_child(popup)	
		popup.popup_centered(Vector2i(300,500))		
	)	
	
	%export_path.text = object.export_path
	%export_path.text_changed.connect(func(text):
		%Export.disabled = not text.ends_with(".glb")		
	)
	%select_export_path.pressed.connect(func():
		var popup := FileDialog.new()
		popup.access = FileDialog.ACCESS_RESOURCES
		popup.add_filter("*.res")
		popup.file_mode =FileDialog.FILE_MODE_SAVE_FILE
		popup.file_selected.connect(func(path):
			%export_path.text = path
			object.export_path = path
		)
		add_child(popup)	
		popup.popup_centered(Vector2i(300,500))		
	)	
	%Export.disabled = not object.export_path.ends_with(".glb")
	%Export.pressed.connect(AssetIO.glb_export.bind(object, object.export_path))
	
func can_join_mesh():
	if not %joined_mesh_export_path.text.ends_with(".glb") or object.join_at_lod == -1 or len(object.meshes_to_join) == 0:
		return false
	return true
	
