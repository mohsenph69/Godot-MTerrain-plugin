@tool
extends Control

@onready var collection_list:Tree = find_child("collection_list")
@onready var tag_list = find_child("tag_list")
@onready var asset_placer = await get_asset_placer()
var asset_library = MAssetTable.get_singleton()
var items := {}
var active_collections = []
var grouping = "None"

@onready var mterrain_theme:Theme = load("res://addons/m_terrain/gui/styles/mterrain_gui_theme.tres")	

func _ready():		
	find_child("search").text_changed.connect(func(text):
		for item in items:
			items[item].visible = text.is_empty() or items[item].get_text(0).containsn(text)
	)		
	tag_list.set_editable(false)
	tag_list.set_options()	
	visibility_changed.connect(tag_list.set_options)	
	visibility_changed.connect(regroup)		
	regroup()	
	asset_placer.assets_changed.connect(func(who): 				
		if who is Dictionary and who.has("tag"):			
			tag_list.set_tags_from_data.call_deferred(asset_library.collection_get_tags(active_collections[-1]))
	)
	
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
		if changed: 
			asset_placer.assets_changed.emit({"tag":active_collections})	
	)	
	collection_list.multi_selected.connect(func(item: TreeItem, column: int, selected: bool):
		update_active_collection.call_deferred()
	)
	find_child("grouping_popup").group_selected.connect(func(group):
		regroup(group)
	)
func update_active_collection():
	active_collections = []
	var from = collection_list.get_next_selected(null)	
	while from != null:
		active_collections.push_back(from.get_metadata(0))
		from = collection_list.get_next_selected(from)
	if len(active_collections)>0:
		tag_list.set_tags_from_data( asset_library.collection_get_tags(active_collections[-1]))		
	else:
		tag_list.set_tags_from_data( [] )	
	
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
			if collection_id in asset_library.collections_get_by_type(MAssetTable.ItemType.PACKEDSCENE):
				item.set_custom_bg_color(0, mterrain_theme.get_color("packed_scene", "asset_placer"))
			if collection_id in asset_library.collections_get_by_type(MAssetTable.ItemType.HLOD):
				item.set_custom_bg_color(0, mterrain_theme.get_color("hlod", "asset_placer") )
			if collection_id in asset_library.collections_get_by_type(MAssetTable.ItemType.DECAL):
				item.set_custom_bg_color(0, mterrain_theme.get_color("decal", "asset_placer"))
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
			
func select_collection(ids: Array = []):
	collection_list.deselect_all()
	for id in ids:
		items[id].select(0)
	collection_list.scroll_to_item(items[ids[-1]])
	update_active_collection()
	
func get_asset_placer():	
	asset_placer = self
	while asset_placer.name != "AssetPlacer" and asset_placer != get_tree().root:
		asset_placer = asset_placer.get_parent()
		if asset_placer == get_tree().root:
			push_error("CCCCCCCCCCCCCCCCCCC: Asset placer is root")
	return asset_placer	
