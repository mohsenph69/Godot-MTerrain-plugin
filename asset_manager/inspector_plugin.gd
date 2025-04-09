@tool
extends EditorInspectorPlugin

var asset_library: MAssetTable = MAssetTable.get_singleton()# load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))
var asset_placer
var variation_layers_scene = preload("res://addons/m_terrain/asset_manager/ui/inspector/variation_layers/variation_layers.tscn")

func _can_handle(object):				
	if object is MAssetTable:return true
	if object is HLod_Baker: return true
	if object is Node and object.owner and object.owner  is HLod_Baker: return true
	if object is MHlodNode3D: return true	
	if object is MHlodScene: return true
	if object is MAssetMesh: return true	
	if object is CollisionShape3D: return true		
	if object is MDecalInstance: return true		
	if object is MDecal: return true		
	if object is Material: return true
	
	var nodes = EditorInterface.get_selection().get_selected_nodes()
	var selection_type
	for node in nodes:
		if not selection_type:
			selection_type = node.get_class()
		else:
			if selection_type != node.get_class():
				return false
	if len(nodes) > 1 and nodes[-1].owner and nodes[-1].owner is HLod_Baker: return true
	
func _parse_begin(object):
	var nodes = EditorInterface.get_selection().get_selected_nodes()
	if len(nodes) > 1:		
		object = nodes[-1]
	var control	
	var margin = MarginContainer.new()			
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_bottom", 4)	
	if object is MAssetTable:
		control = preload("res://addons/m_terrain/asset_manager/ui/inspector/asset_table_inspector.tscn").instantiate()	
	elif object is HLod_Baker:	
		if object is HLod_Baker_Guest:
			control = preload("res://addons/m_terrain/asset_manager/ui/inspector/hlod_baker_guest_inspector.tscn").instantiate()		
		else:
			control = preload("res://addons/m_terrain/asset_manager/ui/inspector/hlod_baker_inspector.tscn").instantiate()		
		control.baker = object
		control.asset_placer = asset_placer
		if not object.scene_file_path:
			if object.owner and object.owner is HLod_Baker:
				control.add_child(make_variation_layer_control_for_assigning(object))
		else:
			var tag_control = make_tag_collection_control(object)
			control.add_child(tag_control)			
			if object.hlod_id == -1:
				tag_control.disabled = true
				tag_control.tooltip_text = "Please bake hlod first"
				
	elif object is MHlodScene:
		control = preload("res://addons/m_terrain/asset_manager/ui/inspector/mhlod_scene_inspector.tscn").instantiate()
		control.mhlod_scenes = nodes
		control.active_mhlod_scene = object

		control.add_child(make_tag_collection_control(object))		
		#if object.owner and object.owner is HLod_Baker:
			#TODO - add variation layer feature to mhlod_scene to assign it to parent baker's layers.
			#control.add_child(make_variation_layer_control_for_assigning(object))						
			#control.add_child(make_cutoff_lod_control(object))									
	elif object is MAssetMesh:						
		control = VBoxContainer.new()		
		if object.owner and object.owner is HLod_Baker:
			control.add_child(make_variation_layer_control_for_assigning(object))						
			control.add_child(make_masset_mesh_cutoff_lod_control(object))									
			control.add_child(make_masset_collision_cutoff_lod_control(object))
		control.add_child(make_tag_collection_control(object))						
	elif object is MHlodNode3D:				
		control = preload("res://addons/m_terrain/asset_manager/ui/inspector/mhlod_node_inspector.tscn").instantiate()		
		control.mhlod_node = object				
		control.asset_placer = asset_placer
		if object.owner and object.owner is HLod_Baker:
			control.add_child(make_variation_layer_control_for_assigning(object))				
			control.add_child(make_cutoff_lod_control(object))
		control.add_child(make_tag_collection_control(object))		
	elif object is CollisionShape3D:
		control = VBoxContainer.new()
		control.add_child( make_cutoff_lod_control(object) )
		control.add_child( make_physics_settings_control(object))		
		if object.owner and object.owner is HLod_Baker:
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
		var decal:MDecal= object if object is MDecal else object.decal
		var item_id = int(decal.resource_path.get_file())
		var collection_id = asset_library.collection_find_with_item_type_item_id(MAssetTable.DECAL, item_id)
		if collection_id == -1:
			MTool.print_edmsg("Trying to rename an MDecal, but can't find collection_id")
			return
		name_edit.text_submitted.connect(func(text):
			if decal.resource_name == text: return
			decal.resource_name = text
			asset_library.collection_set_name(collection_id,MAssetTable.DECAL,decal.resource_name)
			asset_placer.assets_changed.emit(decal)
			object.notify_property_list_changed()
		)
		hbox.add_child(name_label)
		hbox.add_child(name_edit)
		control.add_child(hbox)
		if object is MDecalInstance:
			if object.owner and object.owner is HLod_Baker:
				control.add_child(make_variation_layer_control_for_assigning(object))							
				control.add_child(make_cutoff_lod_control(object))
		var mt:Callable = MAssetTable.get_singleton().collection_update_modify_time.bind(collection_id)
		if object is MDecal and not decal.changed.is_connected(mt):
			decal.changed.connect(mt)
	elif object is Material:
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal =Control.SIZE_EXPAND_FILL		
		var name_label = Label.new()
		name_label.text = "Material Name:"
		var name_edit = LineEdit.new()
		name_edit.size_flags_horizontal =Control.SIZE_EXPAND_FILL
		name_edit.text = object.resource_name
		name_edit.text_submitted.connect(func(text):
			object.resource_name = text
		)
		hbox.add_child(name_label)
		hbox.add_child(name_edit)
		control = hbox
	elif object.owner and object.owner is HLod_Baker:
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
			if object.owner and object.owner is HLod_Baker:
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
	dropdown.add_item("(default)")
	var current_physics_setting_name
	if object.has_meta("physics_settings"):
		current_physics_setting_name = object.get_meta("physics_settings") 	
	for physics_setting_name in AssetIOMaterials.get_physics().keys():
		dropdown.add_item(physics_setting_name)		
		if physics_setting_name==current_physics_setting_name:
			dropdown.select(dropdown.item_count-1)		
	dropdown.item_selected.connect(func(id):			
		if id != 0:
			var nodes = EditorInterface.get_selection().get_selected_nodes()				
			for node in nodes:
				node.set_meta("physics_settings", dropdown.get_item_text(id))
		else:
			object.remove_meta("physics_settings")
	)		
	hbox.add_child(dropdown)
	return hbox
	
func make_tag_collection_control(object):
	var tag_button = Button.new()
	tag_button.text = "Tag Collection"
	tag_button.pressed.connect(func():
		asset_placer.settings_button.button_pressed = true
		var collection_ids = []
		var nodes = EditorInterface.get_selection().get_selected_nodes()				
		if object is MAssetMesh:
			for node in nodes:
				if not node.collection_id in collection_ids:
					collection_ids.push_back(node.collection_id)
		elif object is MHlodScene:
			for node in nodes:						
				if node.has_meta("collection_id"):
					var id = node.get_meta("collection_id")
					if not id in collection_ids:
						collection_ids.push_back( id )		
		asset_placer.open_settings_window("tag", collection_ids)
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
	variation_layer_control.layer_names = object.owner.variation_layers
	variation_layer_control.value_changed.connect(func(new_value):
		var nodes = EditorInterface.get_selection().get_selected_nodes()
		for node in nodes:						
			node.set_meta("variation_layers", new_value)
	)
	if object.has_meta("variation_layers"):					
		variation_layer_control.set_value.call_deferred(object.get_meta("variation_layers"))

	return vbox
		
func make_cutoff_lod_control(object):
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = "Cutoff at Lod "
	label.tooltip_text="Will not be shown at this lod and above\n\"-1\" means the default lod\n\"0\" will disable the item\nyou can change the default value in baker inspector"
	label.mouse_filter=Control.MOUSE_FILTER_STOP
	hbox.add_child(label)
	var spinbox = SpinBox.new()
	hbox.add_child(spinbox)
	spinbox.step = 1
	spinbox.max_value = 10
	spinbox.min_value = -1
	spinbox.value = object.get_meta("lod_cutoff") if object.has_meta("lod_cutoff") else -1
	spinbox.value_changed.connect(func(new_value):
		var nodes = EditorInterface.get_selection().get_selected_nodes()
		for node in nodes:						
			node.set_meta("lod_cutoff", new_value)
	)
	return hbox
	
func make_masset_mesh_cutoff_lod_control(object:MAssetMesh):
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = "Mesh Cutoff LOD "
	label.tooltip_text="Will not be shown at this lod and above\n\"-1\" means the default lod\n\"0\" will disable the item\ndefault value is define in GLB imported file"
	label.mouse_filter=Control.MOUSE_FILTER_STOP
	hbox.add_child(label)
	var spinbox = SpinBox.new()
	hbox.add_child(spinbox)
	spinbox.step = 1
	spinbox.max_value = 10
	spinbox.min_value = -1
	spinbox.value = object.mesh_lod_cutoff
	spinbox.value_changed.connect(func(new_value):
		var nodes = EditorInterface.get_selection().get_selected_nodes()
		for node in nodes:			
			node.mesh_lod_cutoff = new_value
	)
	return hbox
func make_masset_collision_cutoff_lod_control(object:MAssetMesh):
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = "Collision Cutoff LOD "
	label.tooltip_text="Collision Will not be disabled at this lod and above\n\"-1\" means the default lod\n\"0\" will disable the item\ndefault value is define in GLB imported file"
	label.mouse_filter=Control.MOUSE_FILTER_STOP
	hbox.add_child(label)
	var spinbox = SpinBox.new()
	hbox.add_child(spinbox)
	spinbox.step = 1
	spinbox.max_value = 10
	spinbox.min_value = -1
	spinbox.value = object.collision_lod_cutoff
	spinbox.value_changed.connect(func(new_value):
		var nodes = EditorInterface.get_selection().get_selected_nodes()
		for node in nodes:
			node.collision_lod_cutoff = new_value
	)
	return hbox
	
func save_changes(object):
	pass
			 	
