@tool
extends HBoxContainer

var assets_tree
var asset_type_tree
var filter_popup
var grouping_popup  

var filter_settings

func _ready():
	if FileAccess.file_exists(AssetIO.filter_settings_path):
		filter_settings = load(AssetIO.filter_settings_path)
	else:
		filter_settings = load("res://addons/m_terrain/asset_manager/ui/filter_settings.gd").new()
		ResourceSaver.save(filter_settings, AssetIO.filter_settings_path)	
	
	%assets_tree_column_count.value = filter_settings.column_count
	%assets_tree_column_count.value_changed.connect(func(value):
		filter_settings.column_count = value
	)
	%asset_type_tree.asset_type_filter_changed.connect(func(types:int):
		filter_settings.current_filter_types = types
	)
	%filter_popup.filter_changed.connect(func(current_filter, match_all):
		filter_settings.current_filter_mode_all = match_all
		filter_settings.set_current_filter_tags(current_filter)
	)
	
	%grouping_popup.group_selected.connect(func(text):
		filter_settings.current_group = text
	)	
	%sort_popup.sort_mode_changed.connect(func(text):
		filter_settings.current_sort_mode = text
	)
	%search_collections.text_changed.connect(func(text):
		filter_settings.current_search = text)			
	
	filter_settings.filter_changed.connect.call_deferred(update_filter_notifications)	
	
func update_filter_notifications():		
	if not has_node("%asset_type_notification_texture"):
		return
	#if not %asset_type_notification_texture or not %filter_notification_texture: return
	%asset_type_notification_texture.visible = filter_settings.current_filter_types < MAssetTable.ItemType.DECAL + MAssetTable.ItemType.HLOD + MAssetTable.ItemType.MESH + MAssetTable.ItemType.PACKEDSCENE 
	%filter_notification_texture.visible = len(filter_settings._current_filter_tags) != 0
