@tool
extends EditorInspectorPlugin

var asset_library: MAssetTable = MAssetTable.get_singleton()# load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))
var asset_placer
var variation_layers_scene = preload("res://addons/m_terrain/asset_manager/ui/inspector/variation_layers/variation_layers.tscn")

func _can_handle(object):				
	if object is MAssetTable:return true
	if object is HLod_Baker: return true
	if EditorInterface.get_edited_scene_root() is HLod_Baker: return true
	if object is MHlodNode3D: return true	
	if object is MHlodScene: return true
	if object is MAssetMesh: return true	
	if object is MMesh: return true		
	if object is CollisionShape3D: return true		
	if object is MDecalInstance: return true		
	if object is MDecal: return true		
	var nodes = EditorInterface.get_selection().get_selected_nodes()
	if len(nodes) > 1 and EditorInterface.get_edited_scene_root() is HLod_Baker: return true
	
func _parse_begin(object):
	var control	
	var margin = MarginContainer.new()			
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_bottom", 4)	

	if object is MAssetTable:
		control = preload("res://addons/m_terrain/asset_manager/ui/inspector/asset_table_inspector.tscn").instantiate()	
	elif object is HLod_Baker:	
		control = preload("res://addons/m_terrain/asset_manager/ui/inspector/hlod_baker_inspector.tscn").instantiate()		
		control.baker = object
		control.asset_placer = asset_placer
		if not object == EditorInterface.get_edited_scene_root():
			if EditorInterface.get_edited_scene_root() is HLod_Baker:
				control.add_child(make_variation_layer_control_for_assigning(object))
		else:
			var tag_control = make_tag_collection_control(object)
			control.add_child(tag_control)			
			if object.hlod_id == -1:
				tag_control.disabled = true
				tag_control.tooltip_text = "Please bake hlod first"
				
	elif object is MHlodScene:
		control = preload("res://addons/m_terrain/asset_manager/ui/inspector/mhlod_scene_inspector.tscn").instantiate()
		control.mhlod_scene = object
		# TO DO - add variation layer feature to mhlod_scene to assign it to parent baker's layers.
		#if EditorInterface.get_edited_scene_root() is HLod_Baker:
			#control.add_child(make_variation_layer_control_for_assigning(object))				
		control.add_child(make_tag_collection_control(object))		
	elif object is MAssetMesh:						
		control = VBoxContainer.new()		
		if EditorInterface.get_edited_scene_root() is HLod_Baker:
			control.add_child(make_variation_layer_control_for_assigning(object))						
		control.add_child(make_tag_collection_control(object))						
	elif object is MMesh:		
		control = preload("res://addons/m_terrain/asset_manager/ui/inspector/mmesh_inspector.tscn").instantiate()
		control.mmesh = object		
	elif object is MHlodNode3D:				
		control = preload("res://addons/m_terrain/asset_manager/ui/inspector/mhlod_node_inspector.tscn").instantiate()		
		control.mhlod_node = object				
		control.asset_placer = asset_placer
		if EditorInterface.get_edited_scene_root() is HLod_Baker:
			control.add_child(make_variation_layer_control_for_assigning(object))				
		control.add_child(make_tag_collection_control(object))		
	elif object is CollisionShape3D:
		control = VBoxContainer.new()
		control.add_child( make_cutoff_lod_control(object) )
		control.add_child( make_physics_settings_control(object))		
		if EditorInterface.get_edited_scene_root() is HLod_Baker:
			control.add_child( make_variation_layer_control_for_assigning(object))
	elif object is MDecal or object is MDecalInstance: 
		control = VBoxContainer.new()
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal =Control.SIZE_EXPAND_FILL		
		var name_label = Label.new()
		name_label.text = "Name:"
		var name_edit = LineEdit.new()
		name_edit.size_flags_horizontal =Control.SIZE_EXPAND_FILL
		name_edit.text = object.resource_name if object is MDecal else object.decal.resource_name
		name_edit.text_submitted.connect(func(text):
			var decal = object if object is MDecal else object.decal
			if decal.resource_name == text: return
			if asset_library.collection_get_id(text) != -1: 
				MTool.print_edmsg("Trying to rename an MDecal, but name already exist")						
				return				
			decal.resource_name = text
			#var item id = int(decal.resource_path.get_file())			
			var item_id = int(decal.resource_path.get_file())
			var collection_id = asset_library.collection_find_with_item_type_item_id(MAssetTable.DECAL, item_id)
			if collection_id == -1:
				MTool.print_edmsg("Trying to rename an MDecal, but can't find collection_id")					
			asset_library.collection_create(decal.resource_name, item_id, MAssetTable.DECAL, -1)									
			asset_placer.assets_changed.emit(decal)
		)
		hbox.add_child(name_label)
		hbox.add_child(name_edit)
		control.add_child(hbox)
		control.add_child(make_variation_layer_control_for_assigning(object))							
	elif EditorInterface.get_edited_scene_root() is HLod_Baker:
		if object.get_class() == "Node3D":
			control = Button.new()
			control.text = "Convert to Sub Baker"
			control.pressed.connect(func():
				object.set_script(preload("res://addons/m_terrain/asset_manager/hlod_baker.gd"))
				object._ready()				
			)			
		elif object is OmniLight3D or object is SpotLight3D:
			control = VBoxContainer.new()
			control.add_child(make_cutoff_lod_control(object))
			if EditorInterface.get_edited_scene_root() is HLod_Baker:
				control.add_child(make_variation_layer_control_for_assigning(object))							
	if control:
		margin.add_child(control)
		add_custom_control(margin)			

func make_physics_settings_control(object):
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = "Physics Setting: "
	hbox.add_child(label)
	var dropdown = OptionButton.new()
	var dir =MHlod.get_physics_settings_dir()
	var physics_setting_id:int = object.get_meta("physics_settings") if object.has_meta("physics_settings") else -1
	for file in DirAccess.get_files_at(dir):
		var physics_setting: MHlodCollisionSetting = load(dir.path_join(file))
		dropdown.add_item(physics_setting.name)
		dropdown.set_item_metadata(dropdown.item_count-1, int(file))		
		if physics_setting_id != -1 and physics_setting_id == int(file):
			dropdown.select(dropdown.item_count-1)		
	dropdown.item_selected.connect(func(id):			
		object.set_meta("physics_settings", dropdown.get_item_metadata(id))
	)		
	hbox.add_child(dropdown)
	return hbox
	
func make_tag_collection_control(object):
	#var tags_editor = preload("res://addons/m_terrain/asset_manager/ui/tags_editor.tscn").instantiate()
	#tags_editor.set_options(MAssetTable.get_singleton().tag_get_names())
	#control.add_child(tags_editor)	
	var tag_button = Button.new()
	tag_button.text = "Tag Collection"
	tag_button.pressed.connect(func():
		asset_placer.settings_button.button_pressed = true
		var collection_id
		if object is MAssetMesh:
			collection_id = object.collection_id
		elif object is MHlodScene:
			collection_id = object.get_meta("collection_id") if object.has_meta("collection_id") else -1		
		asset_placer.open_settings_window("tag", collection_id)
		#%manage_tags_button.button_pressed = true
	)
	return tag_button
func make_variation_layer_control_for_assigning(object):
	var vbox = VBoxContainer.new()
	var label = Label.new()
	label.text = "Assign to variation layer"
	vbox.add_child(label)						
	var variation_layer_control = variation_layers_scene.instantiate()	
	vbox.add_child(variation_layer_control)
	variation_layer_control.layer_names = EditorInterface.get_edited_scene_root().variation_layers
	variation_layer_control.value_changed.connect(func(new_value):
		object.set_meta("variation_layers", new_value)
	)
	if object.has_meta("variation_layers"):					
		variation_layer_control.set_value.call_deferred(object.get_meta("variation_layers"))

	return vbox
		
func make_cutoff_lod_control(object):
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = "Cutoff at Lod "
	hbox.add_child(label)
	var spinbox = SpinBox.new()
	hbox.add_child(spinbox)
	spinbox.value = object.get_meta("lod_cuttoff") if object.has_meta("lod_cuttoff") else 1
	spinbox.step = 1
	spinbox.max_value = 10
	spinbox.value_changed.connect(func(new_value):
		object.set_meta("lod_cutoff", new_value)
	)
	return hbox
func save_changes(object):
	pass
			 	
