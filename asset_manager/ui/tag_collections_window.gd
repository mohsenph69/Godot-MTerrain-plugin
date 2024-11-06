@tool
extends Popup

@onready var tree:Tree = find_child("Tree")
@onready var tags = find_child("Tags")
var asset_library = MAssetTable.get_singleton()
var items := {}
var active_collection = -1

func _ready():		
	var root = tree.create_item()
	for collection_id in asset_library.collection_get_list():
		var collection_name = asset_library.collection_get_name(collection_id)
		var item = root.create_child()
		item.set_text(0, collection_name)
		item.set_metadata(0, collection_id)
		items[collection_id] = item		
	
	find_child("search").text_changed.connect(func(text):
		var filtered_collections = asset_library.collection_names_begin_with(text) if text != "" else asset_library.collection_get_list()
		for item in items.keys():
			items[item].visible = filtered_collections.has(item)
	)
	tags.editable = false		
	tags.set_options(asset_library.tag_get_names())			
	tags.tag_changed.connect(func(tag_id, toggle_on):
		if toggle_on:
			asset_library.collection_add_tag(active_collection, tag_id)
		else:
			asset_library.collection_remove_tag(active_collection, tag_id)
	)
	tree.item_selected.connect(func():
		var item = tree.get_selected()		
		active_collection = item.get_metadata(0)
		tags.set_tags_from_data( asset_library.collection_get_tags(active_collection))		
	)
	
