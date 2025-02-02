@tool
extends Control

@onready var collection_list:Tree = find_child("collection_list")
@onready var tag_list = find_child("tag_list")
var asset_library = MAssetTable.get_singleton()
var items := {}
var active_collections = []
var grouping = "None"

func _ready():		
	find_child("search").text_changed.connect(func(text):
		for item in items:
			items[item].visible = text == "" or text.to_lower() in items[item].get_text(0).to_lower()
	)		
	tag_list.set_editable(false)
	tag_list.set_options()	
	tag_list.visibility_changed.connect(tag_list.set_options)	
	regroup()	
	tag_list.tag_changed.connect(func(tag_id, toggle_on):		
		var changed = false		
		if toggle_on:
			for id in active_collections:
				asset_library.collection_add_tag(id, tag_id)
				changed = true
		else:
			for id in active_collections:
				asset_library.collection_remove_tag(id, tag_id)
				changed = true
		if changed: regroup()
	)
	collection_list.multi_selected.connect(func(item, column, selected):		
		var id = item.get_metadata(0)
		if id == null: return
		if selected and not id in active_collections:
			active_collections.push_back(id)
		elif not selected and id in active_collections:
			active_collections.erase(id)		
		if len(active_collections)>0:
			tag_list.set_tags_from_data( asset_library.collection_get_tags(active_collections[-1]))		
	)
	find_child("grouping_popup").group_selected.connect(func(group):
		regroup(group)
	)
	
func regroup(group = grouping):
	grouping = group
	collection_list.clear()	
	var root = collection_list.create_item() 	
	if group == "None":
		for collection_id in asset_library.collection_get_list():
			var collection_name = asset_library.collection_get_name(collection_id)
			var item = root.create_child()
			item.set_text(0, collection_name)
			#var thumbnail = asset_library.collection_get_cache_thumbnail(collection_id)
			#item.set_icon(0, thumbnail)
			item.set_metadata(0, collection_id)
			items[collection_id] = item		
	else:
		var remaining_collections = Array(asset_library.collection_get_list())
		for tag_id in asset_library.group_get_tags(group):
			var tag = asset_library.tag_get_name(tag_id)
			var tag_item = root.create_child()
			tag_item.set_text(0, tag)
			for collection_id in asset_library.tags_get_collections_any(asset_library.collection_get_list(),[tag_id],[]):
				if not asset_library.has_collection(collection_id):					
					#asset_library.collection_remove_tag(collection_id, tag_id)
					#push_error("tag get collections returned a collection id that doesn't exist")
					continue
				if collection_id in remaining_collections:
					remaining_collections.erase(collection_id)
				var collection_name = asset_library.collection_get_name(collection_id)
				var item = tag_item.create_child()
				item.set_text(0, collection_name)
				var thumbnail = asset_library.collection_get_cache_thumbnail(collection_id)
				item.set_icon(0, thumbnail)
				item.set_metadata(0, collection_id)
				items[collection_id] = item	
		if len(remaining_collections) > 0:
			var tag_item = root.create_child()
			tag_item.set_text(0, "(other)")
			for collection_id in remaining_collections:
				var item = tag_item.create_child()
				item.set_text(0, asset_library.collection_get_name(collection_id))
				var thumbnail = asset_library.collection_get_cache_thumbnail(collection_id)
				item.set_icon(0, thumbnail)
				item.set_metadata(0, collection_id)
				items[collection_id] = item	
			
func select_collection(id):
	collection_list.deselect_all()
	items[id].select(0)
	collection_list.scroll_to_item(items[id])
	
