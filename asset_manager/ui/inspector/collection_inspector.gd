@tool
extends VBoxContainer

var object

func _ready():
	if EditorInterface.get_edited_scene_root() == self: return

	var asset_library: MAssetTable = MAssetTable.get_singleton()# load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))	
	if not object: return
	if object.has_meta("collection_id"):
		var collection_id = object.get_meta("collection_id")
		if collection_id == -1: return			
		var has_collection = asset_library.has_collection(collection_id)
		if has_collection:
			%collection_name.text = asset_library.collection_get_name(collection_id)			
			var details = ""
			var data = asset_library.collection_get_mesh_items_info(collection_id)						
			if len(data)>0:
				details += str("mesh array | position: \n")
				for item in data:
					details += str(item.mesh, " | ", item.transform.origin.snappedf(0.01), "\n")			
			var subcollection_ids = asset_library.collection_get_sub_collections(collection_id)			
			var subcollection_transforms = asset_library.collection_get_sub_collections_transforms(collection_id)					
			
			if len(subcollection_ids)>0:				
				details += "sub_collections | position: \n"
				for i in len(subcollection_ids):								
					details += str(asset_library.collection_get_name(subcollection_ids[i]), ": ", subcollection_transforms[i].origin.snappedf(0.01), "\n")
			%collection_details.text = details
		else:
			%collection_name.text = "Collection doesn't exist"
			%reload_button.pressed.connect(func():
				AssetIO.reload_collection(object, collection_id)
				object.remove_meta("overrides")
			)								
		%Tags.editable = false
		%Tags.set_options(asset_library.tag_get_names())
		%Tags.set_tags_from_data(asset_library.collection_get_tags(collection_id))
		%Tags.tag_changed.connect(func(tag_id, toggle_on):
			if toggle_on:
				asset_library.collection_add_tag(collection_id, tag_id)
			else:
				asset_library.collection_remove_tag(collection_id, tag_id)
		)
		if object is Node:
			object.get_tree().node_added.connect(func(node):
				if "*" in node.name:
					node.name = node.name.split("*")[0]
			)
		if object.has_meta("mesh_id"):
			var mesh_id = object.get_meta("mesh_id")
			if mesh_id != -1: return
			var has_item = asset_library.has_mesh_item(mesh_id)
			if has_item:
				%mesh_details.text = asset_library.mesh_item_get_info(mesh_id)
			else:
				%mesh_details.text = "mesh item doesn't exist"	
						
func update_overrides(node:Node3D):
	var parent = node.get_parent()
	#if not parent.has_meta("collection_id"): return
	var overrides = parent.get_meta("overrides") if parent.has_meta("overrides") else {}
	overrides[node.name.trim_suffix("*")] = {
		"transform": node.transform,		
	}
	if node.has_meta("collection_id"):
		overrides[node.name.trim_suffix("*")]["collection_id"] = node.get_meta("collection_id")
	parent.set_meta("overrides",overrides)
