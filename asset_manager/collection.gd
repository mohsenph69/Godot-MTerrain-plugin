@tool
class_name Asset_Collection_Node extends Node3D

var asset_library: MAssetTable = Asset_Manager_IO.get_asset_library()

@export var edit: bool:
	set(val):
		if edit == val: return
		edit = val			
		for child in get_children():			
			if edit:				
				child.owner = EditorInterface.get_edited_scene_root()
				notify_property_list_changed()
			else:
				child.owner = null
				notify_property_list_changed()
		var n = Node.new()
		add_child(n)
		n.queue_free()
				

@export var collection_id = -1:
	set(val):
		if collection_id == val: return
		collection_id = val
		load_collection()	
		notify_property_list_changed()

func _notification(what):
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		if asset_library.has_collection(collection_id):
			save_changes()

func _enter_tree():	
	load_collection()
	
func save_changes():
	if not edit: return
	asset_library.collection_remove_all_items(collection_id)
	for child in get_children():
		if child is Asset_Collection_Node:
			asset_library.collection_add_sub_collection(collection_id, child.collection_id, child.transform)						
		elif child is Mesh_Item:			
			asset_library.collection_add_item(collection_id, MAssetTable.MESH, child.mesh_id, child.transform)			
		elif child is CollisionShape3D:
			pass 		
func load_collection():	
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if not asset_library.has_collection(collection_id):
		#CHECK IF THERE"S A GLB THAT NEEDS TO BE LOADED
		print("collection doesn't exist")
		#queue_free()	
		if has_meta("extras"):
			var extras = get_meta("extras")
			if "glb" in extras:
				var path = "res://addons/m_terrain/asset_manager/example_asset_library/export/" + extras.glb
				if FileAccess.file_exists(path):
					Asset_Manager_IO.update_from_glb(asset_library, path, [])				
	else:		
		var item_ids = asset_library.collection_get_mesh_items_ids(collection_id)		
		var items_info = asset_library.collection_get_mesh_items_info(collection_id)
		for i in item_ids.size():			
			var mesh_item = preload("res://addons/m_terrain/asset_manager/mesh_item.gd").new()			
			add_child(mesh_item)
			mesh_item.name = name
			mesh_item.mesh_id = item_ids[i]
			mesh_item.owner = EditorInterface.get_edited_scene_root()
			mesh_item.transform = items_info[i].transform
		var sub_collections = asset_library.collection_get_sub_collections(collection_id)
		for id in sub_collections:
			var sub_collection = Asset_Collection_Node.new()
			sub_collection.collection_id = id
			add_child(sub_collection)
	#for hlod in asset_library.collection_get_sub_hlods(collection_id):
		#var hlod_baker_scene = load().instantiate()
		#add_child(hlod_baker_scene)
