@tool
extends Button

func _ready():
	if not owner.baker is HLod_Baker_Guest:
		queue_free()
		return
	visible = not owner.baker == EditorInterface.get_edited_scene_root() and owner.baker.scene_file_path
	pressed.connect(owner.baker.replace_baker_with_mhlod_scene)
	
