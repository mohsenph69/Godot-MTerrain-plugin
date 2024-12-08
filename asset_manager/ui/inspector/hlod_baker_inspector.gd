@tool
extends VBoxContainer

var baker: HLod_Baker

func _ready():	
	if EditorInterface.get_edited_scene_root() == self or EditorInterface.get_edited_scene_root().is_ancestor_of(self): return

	if not is_instance_valid(baker) or not baker.has_method("bake_to_hlod_resource"): return		
	%Bake.pressed.connect(baker.bake_to_hlod_resource)		
	validate_bake_button()
	baker.renamed.connect(validate_bake_button.call_deferred)	
	%Join.pressed.connect( show_join_mesh_window )			
	
	var force_lod_checkbox = %force_lod_checkbox
	var force_lod_value = %force_lod_value
	%show_joined_button.visible = false
	force_lod_checkbox.toggled.connect(func(toggle_on):
		validate_show_joined_mesh_button()			
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
	%disable_joined_mesh_button.toggled.connect(validate_show_joined_mesh_button)
	if not baker.joined_mesh_disabled:
		baker.joined_mesh_disabled = false
	%disable_joined_mesh_button.button_pressed = baker.joined_mesh_disabled 		
		
	%show_joined_button.pressed.connect(func():
		baker.force_lod(baker.join_at_lod)
		baker.notify_property_list_changed()		
	)
	%variation_layers_button.pressed.connect(func():
		var dialog = preload("res://addons/m_terrain/asset_manager/ui/inspector/variation_layers/variation_layers_dialog.tscn").instantiate()
		dialog.baker = baker
		add_child(dialog)
	)	
	var layers = find_child("Layers")
	layers.set_value(baker.variation_layers_preview_value)
	layers.value_changed.connect(func(value):
		baker.set_variation_layers_visibility(value)
	)
	layers.layer_names = baker.variation_layers
	%show_hlod_button.pressed.connect(func():
		EditorInterface.get_file_system_dock().navigate_to_path("res://massets/hlod/"+baker.name+".res")
	)

	
func show_join_mesh_window():	
	var window = preload("res://addons/m_terrain/asset_manager/ui/mesh_join_window.tscn").instantiate()	
	window.baker = baker
	add_child(window)	

func validate_show_joined_mesh_button(toggle_on = null):	
	%disable_joined_mesh_button.tooltip_text = "disable joined mesh" if not toggle_on else "enable joined mesh"
	%show_joined_button.visible = %force_lod_checkbox.button_pressed and baker.has_joined_mesh_glb() and not baker.joined_mesh_disabled

func bake_button_gui_input(event):
	if event is InputEventMouse:
		%Bake.disabled = not validate_bake_button()
		
func validate_bake_button():
	%Bake.disabled = not baker.can_bake
	if baker.can_bake:
		%Bake.text = "Bake"
		%Bake.tooltip_text = "Bake scene to hlod resource"
	else:
		%Bake.text= "Baker name must be unique!"
		%Bake.tooltip_text = "HLod with the name " + baker.name + " is already used by another baker scene. please rename the baker scene"
		
