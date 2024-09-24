@tool
extends Node

@onready var tags_label = find_child("tags_label")
@onready var groups_label = find_child("groups_label")
@onready var mesh_items_label = find_child("mesh_items_label")
@onready var collections_label = find_child("collections_label")

@onready var collections_container = find_child("collections_container")
@onready var meshes_container = find_child("meshes_container")



func _ready():	
	var asset_library:MAssetTable = load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))
	tags_label.text = str("tags: ", asset_library.tag_get_names())
	groups_label.text = str("groups: ", asset_library.group_get_list())
	
	var mesh_text = "mesh_items: \n"
	for mesh_item_id in asset_library.mesh_item_get_list():		
		mesh_text += str(mesh_item_id, "| ", asset_library.mesh_item_get_info(mesh_item_id), "\n")
		var mesh_node = preload("res://addons/m_terrain/asset_manager/ui/inspector/collection_item.tscn").instantiate()		
		meshes_container.add_child(mesh_node)
		
		mesh_node.find_child("id").text = str(mesh_item_id)		
		
		mesh_node.find_child("name").queue_free()		
		
		mesh_node.find_child("remove").pressed.connect(func():
			asset_library.remove_mesh_item(mesh_item_id)
			asset_library.notify_property_list_changed()
		)		
		mesh_node.find_child("meshes").text = str(asset_library.mesh_item_get_info(mesh_item_id))
		
		
	mesh_items_label.text = mesh_text
	
	
	
	var collections = asset_library.collection_get_list()
	var collection_text = "collections: \n"
	for collection_id in asset_library.collection_get_list():
		var collection_node = preload("res://addons/m_terrain/asset_manager/ui/inspector/collection_item.tscn").instantiate()		
		collections_container.add_child(collection_node)
		collection_node.find_child("id").text = str(collection_id)
		collection_node.find_child("meshes").text = str(asset_library.collection_get_mesh_items_ids(collection_id))
		
		var name_node = collection_node.find_child("name")
		name_node.text = asset_library.collection_get_name(collection_id)
		name_node.text_submitted.connect(func(new_text):
			if asset_library.collection_get_id(new_text) == -1:
				asset_library.collection_update_name(collection_id, new_text)
			else:
				name_node.text += "!"
			asset_library.notify_property_list_changed()
		)
		collection_node.find_child("remove").pressed.connect(func():
			asset_library.remove_collection(collection_id)
			asset_library.notify_property_list_changed()
		)		
		var mesh_items_info = asset_library.collection_get_mesh_items_info(collection_id)
		collection_text += str(collection_id,"| ", asset_library.collection_get_name(collection_id), " | ", mesh_items_info, "\n","tags: ", asset_library.collection_get_tags(collection_id), "\n")
	collections_label.text = collection_text
