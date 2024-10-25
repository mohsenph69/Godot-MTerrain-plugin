@tool
extends VBoxContainer

var object

func _ready():
	var asset_library: MAssetTable = MAssetTable.get_singleton()# load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))	
	if not object: return
	if object.has_meta("collection_id"):
		var collection_id = object.get_meta("collection_id")
		if collection_id == -1: return
		if object is Node3D:
			object.child_entered_tree.connect(func(child):
				if child.has_meta("collection_id"):
					update_overrides(child)					
			)
		
		if object.get_parent().has_meta("collection_id"):
			if not object.property_list_changed.is_connected(update_overrides.bind(object)):				
				object.property_list_changed.connect(update_overrides.bind(object))
		else:
			if object.property_list_changed.is_connected(update_overrides.bind(object)):
				object.property_list_changed.disconnect(update_overrides.bind(object))
				
		var has_collection = asset_library.has_collection(collection_id)
		if has_collection:
			%collection_name.text = asset_library.collection_get_name(collection_id)			
			var data = asset_library.collection_get_mesh_items_info(collection_id)
			%collection_details.text = str("items: ", data.size(), "\npositions: ", data.map(func(a): return a.transform.origin))						
			data = asset_library.collection_get_sub_collections(collection_id)
			%collection_details.text += str("\nsubcollections: ", data.size())
		else:
			%collection_name.text = "Collection doesn't exist"
		
		if has_collection:						
			%remove_button.disabled = 0 in asset_library.collection_get_tags(collection_id)
			%remove_button.pressed.connect(func():
				asset_library.remove_collection(collection_id)
				object.set_meta("collection_id", -1)
				object.remove_meta("overrides")
			)
			if object.has_meta("overrides"):
				var button = Button.new()
				%button_hbox.add_child(button)
				button.text = "Update"
				button.pressed.connect(func():
					AssetIO.collection_save_from_nodes(object)					
					object.remove_meta("overrides")
					for node in EditorInterface.get_edited_scene_root().find_children("*", "Node3D"):
						if node.has_meta("collection_id") and node != object and node.get_meta("collection_id") == collection_id:
							AssetIO.reload_collection(node, collection_id)
				)
				button = Button.new()
				%button_hbox.add_child(button)
				button.text = "Save As New"
				button.pressed.connect(func():
					object.name = object.name.trim_suffix("*")
					object.set_meta("collection_id", asset_library.collection_create(object.name))
					AssetIO.collection_save_from_nodes(object)
					object.remove_meta("overrides")
				)
			%button_hbox.move_child(%reload_button, -1)
			%reload_button.pressed.connect(func():
				AssetIO.reload_collection(object, collection_id)
				object.remove_meta("overrides")
			)
		else:
			var button = Button.new()
			%button_hbox.add_child(button)
			button.text = "create collection"
			button.pressed.connect(func():
				object.set_meta("collection_id", asset_library.collection_create(object.name))
				object.notify_property_list_changed()
			)		
		
		
		%export_to_glb.pressed.connect(func():
			var path = "res://addons/m_terrain/asset_manager/example_asset_library/export/"
			var collection_name = asset_library.collection_get_name(collection_id)
			if object.has_meta("glb"):				
				path += "_" + object.get_meta("glb") 
			else:
				path += collection_name + ".glb"			
			object.set_meta("glb", path)
			AssetIO.glb_export(object, path)
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
				
			#if object.has_meta("overrides)
		#if has_item:
			#var button = Button.new()
			#hbox.add_child(button)
			#button.text = "remove item"
			#button.pressed.connect(func():
				#asset_library.remove_mesh_item(mesh_id)
				#object.set_meta("mesh_id", -1)
			#)
			#button = Button.new()
			#hbox.add_child(button)
			#button.text = "save mesh item"
			#button.pressed.connect(func():
				#object.save_changes()
			#)
		#else:
			#pass
			#var button = Button.new()
			#hbox.add_child(button)
			#button.text = "create mesh item"		
			#button.pressed.connect(func():
				##object.collection_id = asset_library.collection_create(object.name)				
				#object.notify_property_list_changed()
			#)



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
