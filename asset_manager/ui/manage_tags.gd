@tool
extends Control

@onready var tree:Tree = find_child("Tree")
@onready var tags = find_child("Tags")
var asset_library = MAssetTable.get_singleton()
var items := {}
var active_collections = []

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
	tags.set_options(asset_library.tag_get_names())			
	tags.tag_changed.connect(func(tag_id, toggle_on):		
		if toggle_on:
			for id in active_collections:
				asset_library.collection_add_tag(id, tag_id)
		else:
			for id in active_collections:
				asset_library.collection_remove_tag(id, tag_id)
	)
	tree.multi_selected.connect(func(item, column, selected):		
		var id = item.get_metadata(0)
		if selected and not id in active_collections:
			active_collections.push_back(id)
		elif not selected and id in active_collections:
			active_collections.erase(id)		
		if len(active_collections)>0:
			tags.set_tags_from_data( asset_library.collection_get_tags(active_collections[-1]))		
	)
	visibility_changed.connect(update_tag_options)	
	
	tags.set_options(asset_library.tag_get_names())
	var add_tag_button = find_child("add_tag_button")
	add_tag_button.pressed.connect(add_tag)			
	tags.tag_option_renamed.connect(func(id, new_name):
		asset_library.tag_set_name(id, new_name)
		asset_library.save()		
	)
	tags.tag_option_removed.connect(func(id):
		asset_library.tag_set_name(id, "")
		asset_library.save()
	)
func add_tag():	
	var i = 0
	var tag_name = "new tag 0"		
	while tag_name in asset_library.tag_get_names():
		i += 1
		tag_name = str("new tag ", i)
	for j in 256:
		if j < 2: continue #0: single_item_collection, 1: hidden
		if asset_library.tag_get_name(j) == "":
			asset_library.tag_set_name(j, tag_name)
			break
	tags.set_options(asset_library.tag_get_names())
	
func update_tag_options():
	if visible:
		tags.set_options(asset_library.tag_get_names())			
