@tool
extends Tree

func _can_drop_data(at_position: Vector2, data: Variant):		
	if "files" in data and ".glb" in data.files[0].to_lower():
		return true

func _drop_data(at_position, data):		
	for file in data.files:
		AssetIO.glb_load(file)
