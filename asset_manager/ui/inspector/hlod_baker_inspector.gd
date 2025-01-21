@tool
extends VBoxContainer

var baker: HLod_Baker

func _ready():	
	if EditorInterface.get_edited_scene_root() == self or EditorInterface.get_edited_scene_root().is_ancestor_of(self): return

	if not is_instance_valid(baker) or not baker.has_method("bake_to_hlod_resource"): return		
		
	
	%Bake.pressed.connect(baker.bake_to_hlod_resource)		
	%Bake.pressed.connect(func():
		var tween:Tween = create_tween()
		%bake_successful.visible = true
		%bake_successful.modulate = Color(1,1,1,1)
		tween.tween_property(%bake_successful, "modulate", Color(1,1,1,1),1.2)
		tween.set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(%bake_successful, "modulate", Color(1,1,1,0),2)
		
	)	
	%bake_successful.visible=false		
	
	%export_baker_button.pressed.connect(AssetIOBaker.baker_export_to_glb.bind(baker))		
	%export_baker_button.pressed.connect(func():
		var tween:Tween = create_tween()
		%export_baker_successful.visible = true
		%export_baker_successful.modulate = Color(1,1,1,1)
		tween.tween_property(%export_baker_successful, "modulate", Color(1,1,1,1),1.2)
		tween.set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(%export_baker_successful, "modulate", Color(1,1,1,0),2)
		
	)	
	%export_baker_successful.visible=false	
	
	%export_join_mesh_button.pressed.connect(AssetIOBaker.export_join_mesh_only.bind(baker))		
	%export_join_mesh_button.pressed.connect(func():
		var tween:Tween = create_tween()
		%export_join_mesh_successful.visible = true
		%export_join_mesh_successful.modulate = Color(1,1,1,1)
		tween.tween_property(%export_join_mesh_successful, "modulate", Color(1,1,1,1),1.2)
		tween.set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(%export_join_mesh_successful, "modulate", Color(1,1,1,0),2)
		
	)	
	%export_join_mesh_successful.visible=false	
	
	validate_bake_button()
	baker.renamed.connect(validate_bake_button.call_deferred)	
	%create_join_mesh_button.pressed.connect( show_join_mesh_window )			
	
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
	%disable_joined_mesh_button.toggled.connect(func(toggle):
		baker.toggle_joined_mesh_disabled(toggle)
		validate_show_joined_mesh_button(toggle)
		if toggle:
			%disable_joined_mesh_button.icon = preload("res://addons/m_terrain/icons/eye-close.svg")
		else:
			%disable_joined_mesh_button.icon = preload("res://addons/m_terrain/icons/eye.svg")
			
	)
	if not baker.joined_mesh_disabled:
		baker.joined_mesh_disabled = false
	%disable_joined_mesh_button.button_pressed = baker.joined_mesh_disabled 		
		
	%show_joined_button.pressed.connect(func():
		baker.force_lod(baker.asset_mesh_updater.get_join_at_lod())
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
	var hlod_path = MAssetTable.get_hlod_res_dir().path_join(baker.name+".res")
	%show_hlod_button.disabled = not FileAccess.file_exists(hlod_path)
		
	%show_hlod_button.pressed.connect(func():
		EditorInterface.get_file_system_dock().navigate_to_path(hlod_path)
	)
	%show_baker_glb_button.pressed.connect(func():
		EditorInterface.get_file_system_dock().navigate_to_path(baker.scene_file_path.get_base_dir().path_join(baker.name+".glb"))
	)
	%show_join_mesh_glb_button.pressed.connect(func():
		EditorInterface.get_file_system_dock().navigate_to_path(baker.scene_file_path.get_base_dir().path_join(baker.name+"_joined_mesh.glb"))
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
		%hlod_bake_warning.text = ""
		%Bake.tooltip_text = "Bake scene to hlod resource"
	else:
		#%hlod_bake_warning.text= "Baker name must be unique!"		
		%Bake.tooltip_text = "HLod with the name " + baker.name + " is already used by another baker scene. please rename the baker scene"
		
