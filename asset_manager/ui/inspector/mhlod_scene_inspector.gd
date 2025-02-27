@tool extends Control



var active_mhlod_scene:MHlodScene
var mhlod_scenes: Array
@onready var edit_baker_scene_button = find_child("edit_baker_scene_button")
@onready var layers_control = find_child("Layers")

func _ready():
	if not active_mhlod_scene: return
	layers_control.set_value(active_mhlod_scene.scene_layers)
	layers_control.value_changed.connect(func(value): 
		for mhlod_scene in mhlod_scenes:
			mhlod_scene.scene_layers = value
	)	
	if not is_instance_valid(active_mhlod_scene.hlod) or not FileAccess.file_exists(active_mhlod_scene.hlod.get_baker_path()):
		edit_baker_scene_button.disabled = true			
		return
		
	edit_baker_scene_button.pressed.connect(func():
		if not active_mhlod_scene:
			MTool.print_edmsg("active_mhlod_scene node is not valid")
			return
		if not active_mhlod_scene.hlod:
			MTool.print_edmsg("MHlod resource is not valid")
			return
		var baker_path = active_mhlod_scene.hlod.get_baker_path()
		if not FileAccess.file_exists(baker_path):
			MTool.print_edmsg("baker path not exist: "+active_mhlod_scene.hlod.get_baker_path())
			return		
		
		
		if AssetIO.EXPERIMENTAL_FEATURES_ENABLED and not Input.is_physical_key_pressed(KEY_CTRL):					
			HLod_Baker_Guest.replace_mhlod_scene_with_baker_guest.call_deferred(baker_path,active_mhlod_scene)
		else:
			EditorInterface.open_scene_from_path.call_deferred(baker_path)
	)
	set_variation_layer_names()
	


func set_variation_layer_names():
	var path = active_mhlod_scene.hlod.get_baker_path()
	if not FileAccess.file_exists(path): return
	var baker_scene:PackedScene = load(path)
	var state = baker_scene.get_state()
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0,i) == "variation_layers":
			layers_control.layer_names = state.get_node_property_value(0,i)
			return
