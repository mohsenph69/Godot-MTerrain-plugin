@tool
extends Tree
signal material_table_changed

func _can_drop_data(at_position: Vector2, data: Variant):	
	return "files" in data

func _drop_data(at_position: Vector2, data: Variant):
	var filesystem = EditorInterface.get_resource_filesystem()
	var materials = MMaterialTable.get_singleton()
	for file in data.files:		
		if filesystem.get_file_type(file) in ["StandardMaterial3D", "ShaderMaterial", "ORMMaterial3D"]:
			var mat = load(file)
			if not mat is Material: continue
			if materials.table.find_key(file) == null:			
				materials.add_material(file)				
				materials.save()
				material_table_changed.emit()
			
