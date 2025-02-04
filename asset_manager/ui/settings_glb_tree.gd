@tool
extends Tree

func _can_drop_data(at_position: Vector2, data: Variant):		
	if "files" in data and data.files[0].containsn(".glb" ):
		return true

func _drop_data(at_position, data):		
	for file in data.files:
		AssetIO.glb_load(file)
