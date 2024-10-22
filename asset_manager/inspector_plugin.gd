@tool
extends EditorInspectorPlugin

var asset_library: MAssetTable = MAssetTable.get_singleton()# load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))

func _can_handle(object):		
	if object.has_meta("collection_id") and object.get_meta("collection_id") != -1: return true
	if object.has_meta("mesh_id") and object.get_meta("mesh_id") != -1: return true
	if object is MAssetTable:return true
	if object is HLod_Baker: return true
	if object is MHlodScene: return true
	if object is MMaterialTable: return true
	var nodes = EditorInterface.get_selection().get_selected_nodes()
	if len(nodes) > 1 and EditorInterface.get_edited_scene_root() is HLod_Baker: return true
	#if len(nodes) > 1 and EditorInterface.get_edited_scene_root() is : return true
func _parse_begin(object):
	var control
	if object is MAssetTable:
		control = preload("res://addons/m_terrain/asset_manager/ui/inspector/asset_table_inspector.tscn").instantiate()
	elif object is MMaterialTable: 		
		control = preload("res://addons/m_terrain/asset_manager/ui/inspector/material_table_inspector.tscn").instantiate()				
		control.material_table = object
	elif object is HLod_Baker:	
		control = preload("res://addons/m_terrain/asset_manager/ui/inspector/hlod_baker_inspector.tscn").instantiate()
		control.object = object
	elif object is MHlodScene:
		control = Button.new()
		var validate_button = func():			
			if is_instance_valid(object.hlod) and FileAccess.file_exists(object.hlod.get_baker_path()):
				control.disabled = false
			else:
				control.disabled = true
		validate_button.call()
		object.property_list_changed.connect(validate_button)					
		control.text = "Edit HLOD"				
		control.pressed.connect(func():			
			EditorInterface.open_scene_from_path(object.hlod.get_baker_path())
		)		
	elif object.has_meta("collection_id"):		
		control = preload("res://addons/m_terrain/asset_manager/ui/inspector/collection_inspector.tscn").instantiate()
		control.object = object	
	else:
		var nodes:Array[Node3D] = []
		for node in EditorInterface.get_selection().get_selected_nodes():
			if node is Node3D:
				nodes.push_back(node)
		
		if len(nodes) < 2: return
		var root = EditorInterface.get_edited_scene_root() 
		var vbox = VBoxContainer.new()
		var button = Button.new()
		button.text = "reload collections"		
		button.pressed.connect(func():
			for child in nodes:
				if child.has_meta("collection_id"):
					AssetIO.reload_collection(child, child.get_meta("collection_id"))
		)
		vbox.add_child(button)
		if root is HLod_Baker:
			button = Button.new()
			button.text = "set as joiner meshes"
			if root in nodes:
				nodes.erase(root)
			button.pressed.connect(func():
				EditorInterface.get_edited_scene_root().meshes_to_join = nodes
			)
			vbox.add_child(button)
		control = vbox
	add_custom_control(control)			
		
func save_changes(object):
	pass
			 	
