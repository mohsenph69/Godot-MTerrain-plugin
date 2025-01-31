@tool
extends EditorInspectorPlugin

var asset_library: MAssetTable = MAssetTable.get_singleton()# load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))

func _can_handle(object):				
	if object is MAssetTable:return true
	if object is HLod_Baker: return true
	if EditorInterface.get_edited_scene_root() is HLod_Baker: return true
	if object is MHlodScene: return true
	if object is MAssetMesh: return true	
	if object is MMesh: return true		
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
	elif object is MHlodScene:
		control = preload("res://addons/m_terrain/asset_manager/ui/inspector/mhlod_scene_inspector.tscn").instantiate()
		control.mhlod_scene = object
	elif object is MAssetMesh:		
		control = preload("res://addons/m_terrain/asset_manager/ui/inspector/collection_inspector.tscn").instantiate()
		control.object = object		
	elif object is MMesh:		
		control = preload("res://addons/m_terrain/asset_manager/ui/inspector/mmesh_inspector.tscn").instantiate()
		control.mmesh = object		
	elif EditorInterface.get_edited_scene_root() is HLod_Baker:
		if object.get_class() == "Node3D":
			control = Button.new()
			control.text = "Convert to Sub Baker"
			control.pressed.connect(func():
				object.set_script(preload("res://addons/m_terrain/asset_manager/hlod_baker.gd"))
				object._ready()				
			)			
		elif object is OmniLight3D or object is SpotLight3D or object is MHlodNode3D or object is CollisionShape3D:
			control = HBoxContainer.new()
			var label = Label.new()
			label.text = "Cutoff at Lod "
			control.add_child(label)
			var spinbox = SpinBox.new()
			control.add_child(spinbox)
			spinbox.step = 1
			spinbox.max_value = 10
			spinbox.value_changed.connect(func(new_value):
				object.set_meta("lod_cutoff", new_value)
			)
		
	margin.add_child(control)
	add_custom_control(margin)			
		
func save_changes(object):
	pass
			 	
