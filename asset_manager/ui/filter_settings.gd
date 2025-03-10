@tool 
#class_name AssetBrowserFilterSettings 
extends Resource

signal filter_changed

@export var column_count = 3:
	set(val):
		column_count = val
		filter_changed.emit()

@export var current_filter_types := 0:
	set(val):
		current_filter_types = val
		filter_changed.emit()

@export var current_filter_mode_all := false:
	set(val):
		current_filter_mode_all = val
		filter_changed.emit()

@export var _current_filter_tags := []


@export var current_sort_mode = "name_desc":
	set(val):
		current_sort_mode = val
		filter_changed.emit()
		
@export var current_search := "":
	set(val):
		current_search = val
		filter_changed.emit()

@export var current_group := "None": #group name
	set(val):
		current_group = val
		filter_changed.emit()


func set_current_filter_tags(value):
	_current_filter_tags = value
	filter_changed.emit()

func add_current_filter_tag(value):
	_current_filter_tags.push_back(value)
	filter_changed.emit()

func remove_current_filter_tag(value):
	_current_filter_tags.erase(value)
	filter_changed.emit()

func get_filtered_collections(tags_to_excluded=[]):		
	var asset_library = MAssetTable.get_singleton()
	var result = []
	result = asset_library.collections_get_by_type(current_filter_types)
	#var collections_to_exclude = asset_library.tags_get_collections_any(tags_to_excluded) 
	var collection_to_include = null
	if _current_filter_tags and len(_current_filter_tags)>0:
		if current_filter_mode_all:					
			result = asset_library.tags_get_collections_all(result, _current_filter_tags, tags_to_excluded)
		else:		
			result = asset_library.tags_get_collections_any(result, _current_filter_tags, tags_to_excluded)	
		
	if not current_search.is_empty():	
		var max = len(result)
		for i in range(max):									
			var id = max - i -1			
			if not asset_library.collection_get_name(result[id]).containsn(current_search): 				
				result.remove_at(id)				
	return result
