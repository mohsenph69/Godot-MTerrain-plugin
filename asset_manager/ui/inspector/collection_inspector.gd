@tool
extends VBoxContainer

var object: MAssetMesh

func _ready():	
	return
	if EditorInterface.get_edited_scene_root() == self or EditorInterface.get_edited_scene_root().is_ancestor_of(self): return
	var asset_library: MAssetTable = MAssetTable.get_singleton()	
	if not object: return	
	$Debug.visible = AssetIO.DEBUG_MODE
	if asset_library.has_collection(object.collection_id):			
		if AssetIO.DEBUG_MODE == true:			
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
			
		var baker = object.owner #TODO what if it is subbaker?	
		if baker is HLod_Baker:			
			var layers_label = Button.new()
			layers_label.alignment = HORIZONTAL_ALIGNMENT_LEFT
			layers_label.text = "Variation Layers"			
			var layers =preload("res://addons/m_terrain/asset_manager/ui/inspector/variation_layers/variation_layers.tscn").instantiate()			
			layers.baker = baker					
			layers_label.pressed.connect(func():
				var dialog = preload("res://addons/m_terrain/asset_manager/ui/inspector/variation_layers/variation_layers_dialog.tscn").instantiate()
				dialog.baker = baker
				add_child(dialog)
			)	
			layers.layer_renamed.connect(baker.update_variation_layer_name)
			layers.value_changed.connect(func(value): object.hlod_layers = value)
			add_child(layers_label)
			add_child(layers)
			layers.set_value(object.hlod_layers)
			layers.layer_names = baker.variation_layers if baker is HLod_Baker else []
	else:
		%collection_name.text = "Collection doesn't exist"								
