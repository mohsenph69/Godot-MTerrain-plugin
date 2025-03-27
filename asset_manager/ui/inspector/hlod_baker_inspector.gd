@tool
extends VBoxContainer

var baker: HLod_Baker
var asset_placer

func _ready():	
	if EditorInterface.get_edited_scene_root() == self or EditorInterface.get_edited_scene_root().is_ancestor_of(self): return

	if not is_instance_valid(baker) or not baker.has_method("bake_to_hlod_resource"): return		
	
	baker.renamed.connect(baker_renamed)	
		
	%show_boundary_btn.button_pressed = baker.asset_mesh_updater.show_boundary
	%show_boundary_btn.toggled.connect(func(toggle):
		baker.asset_mesh_updater.show_boundary = toggle
	)
	%Bake.pressed.connect(func():
		if baker.bake_to_hlod_resource() == OK:			
			var tween:Tween = create_tween()
			%bake_successful.visible = true
			%bake_successful.modulate = Color(1,1,1,1)
			tween.tween_property(%bake_successful, "modulate", Color(1,1,1,1),1.2)
			tween.set_ease(Tween.EASE_OUT)
			tween.chain().tween_property(%bake_successful, "modulate", Color(1,1,1,0),2)	
			asset_placer.assets_changed.emit(baker)
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
	
	%import_join_mesh_button.pressed.connect(AssetIOBaker.import_join_mesh_only.bind(baker))
	%import_join_mesh_button.pressed.connect(func():
		var tween:Tween = create_tween()
		%import_join_mesh_successful.visible = true
		%import_join_mesh_successful.modulate = Color(1,1,1,1)
		tween.tween_property(%import_join_mesh_successful, "modulate", Color(1,1,1,1),1.2)
		tween.set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(%import_join_mesh_successful, "modulate", Color(1,1,1,0),2)		
	)		
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
	
	%disable_joined_mesh_button.visible = baker.has_joined_mesh()	
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
	var hlod_path = MAssetTable.get_hlod_res_dir().path_join(str(baker.hlod_id, ".res"))
	%show_hlod_button.disabled = not FileAccess.file_exists(hlod_path)
		
	%show_hlod_button.pressed.connect(func():
		EditorInterface.get_file_system_dock().navigate_to_path(hlod_path)
	)
	%show_baker_glb_button.pressed.connect(func():
		EditorInterface.get_file_system_dock().navigate_to_path(baker.scene_file_path.get_base_dir().path_join(baker.name+".glb"))
	)
	%show_join_mesh_glb_button.disabled = not FileAccess.file_exists(AssetIOBaker.get_glb_path_by_baker_node(baker))
	%show_join_mesh_glb_button.pressed.connect(func():
		EditorInterface.get_file_system_dock().navigate_to_path(AssetIOBaker.get_glb_path_by_baker_node(baker))
	)
	
	%edit_joined_mesh_in_blender_button.pressed.connect(open_baker_joined_mesh_gltf_with_blender)
	
func show_join_mesh_window():	
	var window = preload("res://addons/m_terrain/asset_manager/ui/mesh_join_window.tscn").instantiate()	
	window.baker = baker
	add_child(window)	

func validate_show_joined_mesh_button(toggle_on = null):	
	%disable_joined_mesh_button.tooltip_text = "disable joined mesh" if not toggle_on else "enable joined mesh"
	%show_joined_button.visible = %force_lod_checkbox.button_pressed and baker.has_joined_mesh() and not baker.joined_mesh_disabled

func bake_button_gui_input(event):
	if event is InputEventMouse:
		%Bake.disabled = not validate_bake_button()
#var cid = MAssetTable.get_singleton().collection_find_with_item_type_item_id(MAssetTable.HLOD,hitem_id)
func baker_renamed():
	if baker.ignore_rename or not baker.scene_file_path: return	
	if not baker.scene_file_path.get_file() == baker.name+".tscn":
		if not FileAccess.file_exists(baker.scene_file_path.get_base_dir().path_join(baker.name+".tscn")):			
			var old_join_mesh_glb_path = AssetIOBaker.get_glb_path_by_baker_path(baker.scene_file_path)
			var old_path = baker.scene_file_path
			var new_path = old_path.get_base_dir().path_join(baker.name+".tscn")
			DirAccess.rename_absolute(baker.scene_file_path, new_path)
			baker.scene_file_path = new_path
			var hitem_id:int=baker.hlod_id
			if hitem_id>=0:
				var hpath = MHlod.get_hlod_path(hitem_id)
				if FileAccess.file_exists(hpath):
					var hlod = load(hpath)
					if hlod:
						hlod.baker_path = new_path
						ResourceSaver.save(hlod)
			if FileAccess.file_exists(old_join_mesh_glb_path):
				var new_join_mesh_glb_path = AssetIOBaker.get_glb_path_by_baker_path(new_path)
				DirAccess.rename_absolute(old_join_mesh_glb_path, new_join_mesh_glb_path)
			EditorInterface.get_resource_filesystem().scan()
			## rename in asset table
			var at:= MAssetTable.get_singleton()
			var cid =at.collection_find_with_item_type_item_id(MAssetTable.HLOD,hitem_id)
			if cid!=-1:
				at.collection_set_name(cid,MAssetTable.HLOD,baker.name)
				MAssetTable.save()
				if AssetIO.asset_placer: 
					AssetIO.asset_placer.regroup()
		elif false: # If returning to old name creates a conflict, ahhhh! TODO
			pass
		else: #Return to old name
			var new_name = baker.name
			baker.name = baker.scene_file_path.get_file().trim_suffix(".tscn")
			MTool.print_edmsg(str(new_name, " already exists. Please pick a different name"))						

func validate_bake_button():
	%Bake.disabled = not baker.can_bake
	if baker.can_bake:								
		%hlod_bake_warning.text = ""
		%Bake.tooltip_text = "Bake scene to hlod resource"
	else:		
		%Bake.tooltip_text = baker.cant_bake_reason
		

func get_blender_path():
	var blender_path:String=  EditorInterface.get_editor_settings().get_setting("filesystem/import/blender/blender_path")
	if blender_path.is_empty():
		MTool.print_edmsg("Blender path is empty! please set blender path in editor setting")
		return
	if not FileAccess.file_exists(blender_path):
		MTool.print_edmsg("Blender path is not valid: "+blender_path)
		return
	return blender_path
	
func write_to_tmp_file(path, py_script):
	if FileAccess.file_exists(path):DirAccess.remove_absolute(path) # good idea to clear to make sure eveyrthing go well
	if not DirAccess.dir_exists_absolute(path.get_base_dir()):
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmpf = FileAccess.open(path,FileAccess.WRITE)
	if not tmpf:
		MTool.print_edmsg("Can not create tmp file for blender python script")
		return
	tmpf.store_string(py_script)
	tmpf.close()
	
func open_baker_scene_with_blender():		
	if Input.is_physical_key_pressed(KEY_CTRL) and not Input.is_physical_key_pressed(KEY_SHIFT):
		var blender_path:String = get_blender_path()	
		var py_script = FileAccess.get_file_as_string("res://addons/m_terrain/asset_manager/blender_addons/open_baker_scene.py") 		
		var tmp_path = "res://addons/m_terrain/tmp/pytmp.py"
		write_to_tmp_file(tmp_path, py_script)	
		OS.create_process(blender_path,["--python",ProjectSettings.globalize_path(tmp_path)])

func open_baker_joined_mesh_gltf_with_blender():
	var blender_path:String = get_blender_path()	
	
	var glb_path = AssetIOBaker.get_glb_path_by_baker_node(baker)
	if not FileAccess.file_exists(glb_path):
		MTool.print_edmsg("File path %s does not exist, please first create and then export the glb file!" % glb_path)
		return	
	glb_path = ProjectSettings.globalize_path(glb_path)
	
	var settings = MAssetTable.get_singleton().import_info["__settings"]
	var materials_blend_path:String = settings["Materials blend file"].value if  "Materials blend file" in settings else null	
	
	var py_script = FileAccess.get_file_as_string("res://addons/m_terrain/asset_manager/blender_addons/open_gltf_file.py") 		
	py_script = py_script.replace("_GLB_FILE_PATH",glb_path)
	py_script = py_script.replace("_BAKER_NAME",baker.name)		
	py_script = py_script.replace("_REPLACE_MATERIALS", "True" if materials_blend_path and FileAccess.file_exists(materials_blend_path) else "False")
	py_script = py_script.replace("_MATERIALS_BLEND_PATH", str(materials_blend_path))
	var tmp_path = "res://addons/m_terrain/tmp/pytmp.py"
	write_to_tmp_file(tmp_path, py_script)
	
	OS.create_process(blender_path,["--python",ProjectSettings.globalize_path(tmp_path)])
	
