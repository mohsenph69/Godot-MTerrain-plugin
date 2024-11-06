@tool
extends VBoxContainer

var baker: HLod_Baker

func _ready():	
	if EditorInterface.get_edited_scene_root() == self: return
	if not is_instance_valid(baker) or not baker.has_method("bake_to_hlod_resource"): return	
	%Bake.pressed.connect(baker.bake_to_hlod_resource)				
	%Join.pressed.connect( show_join_mesh_window )		
	baker.asset_mesh_updated.connect(func():
		%debug_lod.text = str("DEBUG Current Lod is ???", ) 
	)
	%Join.tooltip_text = str(baker.meshes_to_join_overrides)
	
	%joined_mesh_thumbnail.texture = baker.get_joined_mesh_thumbnail()
	%disable_joined_mesh_button.toggled.connect(baker.toggle_joined_mesh_disabled)
	if not baker.joined_mesh_disabled:
		baker.joined_mesh_disabled = false
	%disable_joined_mesh_button.button_pressed = baker.joined_mesh_disabled 
		
func show_join_mesh_window():	
	var window = preload("res://addons/m_terrain/asset_manager/ui/mesh_join_window.tscn").instantiate()	
	window.baker = baker
	add_child(window)	
