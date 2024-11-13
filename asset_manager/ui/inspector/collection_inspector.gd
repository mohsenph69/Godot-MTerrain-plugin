@tool
extends VBoxContainer

var object: MAssetMesh

func _ready():
	if EditorInterface.get_edited_scene_root() == self or EditorInterface.get_edited_scene_root().is_ancestor_of(self): return
	var asset_library: MAssetTable = MAssetTable.get_singleton()
	if not object: return
	if asset_library.has_collection(object.collection_id):								
		%collection_name.text = asset_library.collection_get_name(object.collection_id)			
		var details = ""
		var data = asset_library.collection_get_mesh_items_info(object.collection_id)						
		if len(data)>0:
			details += str("mesh array | position: \n")
			for item in data:
				details += str(item.mesh, " | ", item.transform.origin.snappedf(0.01), "\n")			
		var subcollection_ids = asset_library.collection_get_sub_collections(object.collection_id)			
		var subcollection_transforms = asset_library.collection_get_sub_collections_transforms(object.collection_id)				
		
		if len(subcollection_ids)>0:				
			details += "sub_collections | position: \n"
			for i in len(subcollection_ids):								
				details += str(asset_library.collection_get_name(subcollection_ids[i]), ": ", subcollection_transforms[i].origin.snappedf(0.01), "\n")
		%collection_details.text = details
	else:
		%collection_name.text = "Collection doesn't exist"								
