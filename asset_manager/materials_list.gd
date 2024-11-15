@tool
extends Tree
signal material_table_changed

func _can_drop_data(at_position: Vector2, data: Variant):	
	return "files" in data

func _drop_data(at_position: Vector2, data: Variant):
	var filesystem = EditorInterface.get_resource_filesystem()
	var materials = AssetIO.get_material_table()
	for file in data.files:		
		if filesystem.get_file_type(file) in ["StandardMaterial3D", "ShaderMaterial", "ORMMaterial3D"]:
			var mat = load(file)
			if not mat is Material: continue
			if materials.find_key(file) == null:			
				AssetIO.update_material(-1, file)								
				material_table_changed.emit()
			
