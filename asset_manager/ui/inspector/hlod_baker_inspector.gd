@tool
extends VBoxContainer

var baker: HLod_Baker
var rotating = false
func _ready():	
	if EditorInterface.get_edited_scene_root() == self: return
	if not is_instance_valid(baker) or not baker.has_method("bake_to_hlod_resource"): return	
	%Bake.pressed.connect(baker.bake_to_hlod_resource)				
	%Join.pressed.connect( show_join_mesh_window )		
	baker.asset_mesh_updated.connect(func():
		%debug_lod.text = str("DEBUG Current Lod is ???", ) 
	)
	%Join.tooltip_text = str(baker.meshes_to_join_overrides)
	
	%force_lod_checkbox.toggled.connect(func(toggle_on):
		%force_lod_value.editable = toggle_on
		baker.force_lod_enabled = toggle_on
		if toggle_on:			
			baker.force_lod(%force_lod_value.value)		
		else:
			baker.force_lod(-1)
	)	
	%force_lod_checkbox.button_pressed = baker.force_lod_enabled
	%force_lod_value.value = baker.force_lod_value
	print(baker.force_lod_value)
	
	%force_lod_value.max_value = AssetIO.LOD_COUNT-1
	%force_lod_value.value_changed.connect(baker.force_lod)
	
	#%joined_mesh_thumbnail.texture = baker.get_joined_mesh_thumbnail()
	%disable_joined_mesh_button.toggled.connect(baker.toggle_joined_mesh_disabled)
	if not baker.joined_mesh_disabled:
		baker.joined_mesh_disabled = false
	%disable_joined_mesh_button.button_pressed = baker.joined_mesh_disabled 
	%joined_mesh_preview.mesh = baker.get_joined_mesh()	
	%joined_mesh_thumbnail.gui_input.connect(on_thumbnail_gui_input)

func show_join_mesh_window():	
	var window = preload("res://addons/m_terrain/asset_manager/ui/mesh_join_window.tscn").instantiate()	
	window.baker = baker
	add_child(window)	

func on_thumbnail_gui_input(event: InputEvent):
	if event is InputEventMouseButton: 
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			%joined_mesh_preview_camera.position -= %joined_mesh_preview_camera.basis.z
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			%joined_mesh_preview_camera.position += %joined_mesh_preview_camera.basis.z
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				rotating = true
			else:
				rotating = false
	elif event is InputEventMouseMotion:
		if rotating:
			%joined_mesh_preview_camera_pivot.rotation.y -= event.relative.x / 100
			%joined_mesh_preview_camera_pivot.rotation.x = clamp(%joined_mesh_preview_camera_pivot.rotation.x - event.relative.y / 100, -0.7,1)				
