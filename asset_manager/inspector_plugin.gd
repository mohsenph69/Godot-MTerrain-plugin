@tool
extends EditorInspectorPlugin

var asset_library: MAssetTable = MAssetTable.get_singleton()# load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))

func _can_handle(object):		
	if object.has_meta("collection_id") and object.get_meta("collection_id") != -1: return true
	if object.has_meta("mesh_id") and object.get_meta("mesh_id") != -1: return true
	if object is MAssetTable:return true
	if object is HLod_Baker: return true
	if object is MHlodScene: return true
	if object is MAssetMesh: return true	
	var nodes = EditorInterface.get_selection().get_selected_nodes()
	if len(nodes) > 1 and EditorInterface.get_edited_scene_root() is HLod_Baker: return true
	#if len(nodes) > 1 and EditorInterface.get_edited_scene_root() is : return true
func _parse_begin(object):
	var control
	if object is MAssetTable:
		control = preload("res://addons/m_terrain/asset_manager/ui/inspector/asset_table_inspector.tscn").instantiate()	
	elif object is HLod_Baker:	
		control = preload("res://addons/m_terrain/asset_manager/ui/inspector/hlod_baker_inspector.tscn").instantiate()
		control.baker = object
	elif object is MHlodScene:
		control = Button.new()		
		if not is_instance_valid(object.hlod):# and FileAccess.file_exists(object.hlod.get_baker_path()):
			control.disabled = true			
		
		control.text = "Edit HLOD"				
		control.pressed.connect(func():		
			print(object.hlod.get_baker_path())	
			#EditorInterface.open_scene_from_path(object.hlod.get_baker_path())
		)		
	elif object is MAssetMesh:		
		control = preload("res://addons/m_terrain/asset_manager/ui/inspector/collection_inspector.tscn").instantiate()
		control.object = object		
	add_custom_control(control)			
		
func save_changes(object):
	pass
			 	
