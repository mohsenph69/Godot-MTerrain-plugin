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
		%Join.disabled = value == -1
	)	
	%Join.pressed.connect(object.update_joined_mesh)
	
	%joined_mesh_export_path.text = object.joined_mesh_export_path
	%joined_mesh_export_path.text_changed.connect(func(text):
		object.joined_mesh_export_path = text
		%export_joined_meshes.disabled = not text.ends_with(".glb")
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
	%export_joined_meshes.pressed.connect(func():
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = object.make_joined_mesh()
		mesh_instance.name = object.name
		AssetIO.glb_export(mesh_instance, object.joined_mesh_export_path)
		EditorInterface.get_resource_filesystem().scan()
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
	
	
