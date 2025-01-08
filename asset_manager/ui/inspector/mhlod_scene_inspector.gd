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
		EditorInterface.open_scene_from_path(mhlod_scene.hlod.get_baker_path())
	)		
	set_variation_layer_names()
	
func set_variation_layer_names():
	var path = mhlod_scene.hlod.get_baker_path()
	if not FileAccess.file_exists(path): return
	var baker_scene:PackedScene = load(path)
	var state = baker_scene.get_state()
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0,i) == "variation_layers":
			layers_control.layer_names = state.get_node_property_value(0,i)
			return
