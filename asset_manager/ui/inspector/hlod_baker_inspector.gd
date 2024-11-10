@tool
extends VBoxContainer

var baker: HLod_Baker

func _ready():	
	if EditorInterface.get_edited_scene_root() == self: return
	if not is_instance_valid(baker) or not baker.has_method("bake_to_hlod_resource"): return	
	%Bake.pressed.connect(baker.bake_to_hlod_resource)				
	%Join.pressed.connect( show_join_mesh_window )			
	
	var force_lod_checkbox = %force_lod_checkbox
	var force_lod_value = %force_lod_value
	force_lod_checkbox.toggled.connect(func(toggle_on):
		force_lod_value.editable = toggle_on
		baker.force_lod_enabled = toggle_on
		force_lod_value.visible = toggle_on
		if toggle_on:			
			baker.force_lod(force_lod_value.value)		
		else:
			baker.force_lod(-1)
	)
	
	force_lod_value.value = baker.force_lod_value if baker.force_lod_value else 0
	force_lod_checkbox.button_pressed = baker.force_lod_enabled		
	force_lod_value.visible = force_lod_checkbox.button_pressed
	force_lod_value.max_value = AssetIO.LOD_COUNT-1
	force_lod_value.value_changed.connect(baker.force_lod)
	
	%disable_joined_mesh_button.visible = baker.has_joined_mesh_glb()	
	%disable_joined_mesh_button.toggled.connect(baker.toggle_joined_mesh_disabled)
	if not baker.joined_mesh_disabled:
		baker.joined_mesh_disabled = false
	%disable_joined_mesh_button.button_pressed = baker.joined_mesh_disabled 		
	
	var preview_scene = preload("res://addons/m_terrain/asset_manager/ui/inspector/hlod_baker_inspector_joined_mesh_preview.tscn").instantiate()
	preview_scene.mesh = baker.get_joined_mesh()	
	if preview_scene.mesh is Mesh:
		add_child(preview_scene)
		%joined_mesh_thumbnail.texture = preview_scene.get_texture()				
		%joined_mesh_thumbnail.gui_input.connect(preview_scene.on_thumbnail_gui_input)
	var remove_joined_mesh = %remove_joined_mesh
	remove_joined_mesh.visible = baker.has_joined_mesh_glb()
	remove_joined_mesh.pressed.connect(func():
		if remove_joined_mesh.text == "Remove":
			remove_joined_mesh.text = "Remove\nAre you sure?\nThis will delete the glb file for this joined mesh"
		else:
			baker.remove_joined_mesh()
			remove_joined_mesh.visible = false
	)
func show_join_mesh_window():	
	var window = preload("res://addons/m_terrain/asset_manager/ui/mesh_join_window.tscn").instantiate()	
	window.baker = baker
	add_child(window)	
