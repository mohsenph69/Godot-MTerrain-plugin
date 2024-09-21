@tool
extends EditorInspectorPlugin

var asset_library: MAssetTable = load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))

func _can_handle(object):
	if object.has_meta("collection_id") and object.get_meta("collection_id") != -1: return true
	if object.has_meta("mesh_id") and object.get_meta("mesh_id") != -1: return true
	if object is MAssetTable:return true
		

func _parse_begin(object):
	if object is MAssetTable:
		add_custom_control(preload("res://addons/m_terrain/asset_manager/debug/asset_table_inspector.tscn").instantiate())
	elif object.has_meta("collection_id"):
		var collection_id = object.get_meta("collection_id")
		if collection_id == -1: return
		if object.get_parent().has_meta("collection_id"):
			if not object.property_list_changed.is_connected(update_overrides.bind(object)):
				object.property_list_changed.connect(update_overrides.bind(object))
		else:
			if object.property_list_changed.is_connected(update_overrides.bind(object)):
				object.property_list_changed.disconnect(update_overrides.bind(object))
		
		var vbox = VBoxContainer.new()
		var hbox = HBoxContainer.new()
		vbox.add_child(hbox)
		var label = Label.new()
		vbox.add_child(label)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		var has_collection = asset_library.has_collection(collection_id)
		if has_collection:
			label.text = asset_library.collection_get_name(collection_id)
			var label_details = Label.new()
			var data = asset_library.collection_get_mesh_items_info(collection_id)
			label_details.text = str("items: ", data.size(), "\npositions: ", data.map(func(a): return a.transform.origin))
			label_details.autowrap_mode = TextServer.AUTOWRAP_WORD
			vbox.add_child(label_details)
		else:
			label.text = "Collection doesn't exist"
		
		if has_collection:
			var button = Button.new()
			hbox.add_child(button)
			button.text = "remove collection"
			button.pressed.connect(func():
				asset_library.remove_collection(collection_id)
				object.set_meta("collection_id", collection_id-1)
				object.remove_meta("overrides")
			)
			if object.has_meta("overrides"):
				button = Button.new()
				hbox.add_child(button)
				button.text = "update"
				button.pressed.connect(func():
					AssetIO.collection_save_from_nodes(object)
					object.remove_meta("overrides")
				)
				button = Button.new()
				hbox.add_child(button)
				button.text = "save as new"
				button.pressed.connect(func():
					object.name = object.name.trim_suffix("*")
					object.set_meta("collection_id", asset_library.collection_create(object.name))
					AssetIO.collection_save_from_nodes(object)
					object.remove_meta("overrides")
				)
			button = Button.new()
			hbox.add_child(button)
			button.text = "reload"
			button.pressed.connect(func():
				AssetIO.reload_collection(object, object.get_meta("collection_id"))
				object.remove_meta("overrides")
			)
		else:
			var button = Button.new()
			hbox.add_child(button)
			button.text = "create collection"
			button.pressed.connect(func():
				object.set_meta("collection_id", asset_library.collection_create(object.name))
				object.notify_property_list_changed()
			)
		add_custom_control(vbox)
		#var edit_button = CheckButton.new()
		#edit_button.text = "edit"
		#add_custom_control(edit_button)
		#if object.get_child_count() > 0 and object.get_child(0).owner == object.owner:
		#	edit_button.button_pressed = true
		#edit_button.toggled.connect(func(toggle_on): AssetIO.edit_collection(object,toggle_on)	)		

	elif object.has_meta("mesh_id"):
		var mesh_id = object.get_meta("mesh_id")
		if mesh_id != -1: return
		var hbox = HBoxContainer.new()
		var label = Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var has_item = asset_library.has_mesh_item(mesh_id)
		if has_item:
			label.text = str(asset_library.mesh_item_get_info(mesh_id))
		else:
			label.text = "mesh item doesn't exist"
		hbox.add_child(label)
		if has_item:
			var button = Button.new()
			hbox.add_child(button)
			button.text = "remove item"
			button.pressed.connect(func():
				asset_library.remove_mesh_item(mesh_id)
				object.set_meta("mesh_id", -1)
			)
			button = Button.new()
			hbox.add_child(button)
			button.text = "save mesh item"
			button.pressed.connect(func():
				object.save_changes()
			)
		else:
			pass
			#var button = Button.new()
			#hbox.add_child(button)
			#button.text = "create mesh item"		
			#button.pressed.connect(func():
				##object.collection_id = asset_library.collection_create(object.name)				
				#object.notify_property_list_changed()
			#)
		add_custom_control(hbox)

func save_changes(object):
	pass
			 	
func update_overrides(node:Node3D):
	var parent = node.get_parent()
	#if not parent.has_meta("collection_id"): return
	var overrides = parent.get_meta("overrides") if parent.has_meta("overrides") else {}
	overrides[node.name.trim_suffix("*")] = {
		"transform": node.transform
	}
	parent.set_meta("overrides",overrides)
