@tool extends Control

var mhlod_scene:MHlodScene
@onready var edit_baker_scene_button = find_child("edit_baker_scene_button")
@onready var layers_control = find_child("Layers")

func _ready():
	layers_control.set_value(mhlod_scene.scene_layers)
	layers_control.value_changed.connect(func(value): mhlod_scene.scene_layers = value)	
	if not is_instance_valid(mhlod_scene.hlod) or not FileAccess.file_exists(mhlod_scene.hlod.get_baker_path()):
		edit_baker_scene_button.disabled = true			
		return
		
	edit_baker_scene_button.pressed.connect(func():		
		#print(mhlod_scene.hlod.get_baker_path())	
		EditorInterface.open_scene_from_path(mhlod_scene.hlod.get_baker_path())
	)		
