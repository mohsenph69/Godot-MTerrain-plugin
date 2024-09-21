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
		var vbox = VBoxContainer.new()
		var hbox = HBoxContainer.new()
		vbox.add_child(hbox)	
		var label = Label.new()
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
		hbox.add_child(label)
		if has_collection:
			var button = Button.new()
			hbox.add_child(button)
			button.text = "remove collection"		
			button.pressed.connect(func():
				asset_library.remove_collection(collection_id)
				object.set_meta("collection_id", collection_id-1)
			)
			button = Button.new()
			hbox.add_child(button)
			button.text = "save collection"		
			button.pressed.connect(func():
				object.save_changes()
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
		#edit_button.toggled.connect(func(toggle_on): Asset_IO.edit_collection(object,toggle_on)	)
		vbox.tree_exiting.connect(func():
			#if edit_button.button_pressed:
			if false:
				var popup = preload("res://addons/m_terrain/asset_manager/ui/save_changes_popup.tscn").instantiate()				
				EditorInterface.get_editor_main_screen().add_child(popup)
				popup.popup_centered()
				popup.continue_button.pressed.connect(popup.queue_free)
				popup.discard_button.pressed.connect(func():
					for child in object.get_children():
						object.remove_child(child)
						child.queue_free()					
					object = Asset_IO.reload_collection(object, object.get_meta("collection_id"))
					Asset_IO.edit_collection(object, false)
					popup.queue_free()
				)				
				popup.override_button.pressed.connect(func():					
					object.set_meta("collection_id", asset_library.collection_create(object.name))
					Asset_IO.collection_save_from_nodes(object)
					Asset_IO.edit_collection(object, false)
					popup.queue_free()
				)
				popup.update_button.pressed.connect(func():
					Asset_IO.collection_save_from_nodes(object)
					Asset_IO.edit_collection(object, false)
					popup.queue_free()
				)
		)

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
			 	
