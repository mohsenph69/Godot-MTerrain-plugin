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
	margin.add_child(control)
	add_custom_control(margin)			
		
func save_changes(object):
	pass
			 	
