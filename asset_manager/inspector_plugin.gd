@tool 
extends EditorInspectorPlugin

var asset_library: MAssetTable = load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))

func _can_handle(object):	
	if object is Asset_Collection_Node: return true
	if object is Mesh_Item:return true
	if object is MAssetTable:return true
		

func _parse_begin(object):
	if object is Asset_Collection_Node:
		var vbox = VBoxContainer.new()
		var hbox = HBoxContainer.new()
		vbox.add_child(hbox)	
		var label = Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL		
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		var has_collection = asset_library.has_collection(object.collection_id)
		if has_collection:			
			label.text = asset_library.collection_get_name(object.collection_id)
			var label_details = Label.new()
			var data = asset_library.collection_get_mesh_items_info(object.collection_id)
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
				asset_library.remove_collection(object.collection_id)
				object.collection_id -= 1				
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
				object.collection_id = asset_library.collection_create(object.name)				
				object.notify_property_list_changed()
			)		
		add_custom_control(vbox)

	elif object is Mesh_Item:
		var hbox = HBoxContainer.new()	
		var label = Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var has_item = asset_library.has_mesh_item(object.mesh_id)
		if has_item:
			label.text = str(asset_library.mesh_item_get_info(object.mesh_id))
		else:
			label.text = "mesh item doesn't exist"
		hbox.add_child(label)
		if has_item:
			var button = Button.new()
			hbox.add_child(button)
			button.text = "remove item"		
			button.pressed.connect(func():
				asset_library.remove_mesh_item(object.mesh_id)
				object.collection_id -= 1				
			)
			button = Button.new()
			hbox.add_child(button)
			button.text = "save mesh item"		
			button.pressed.connect(func():
				object.save_changes()
			)
		else:
			var button = Button.new()
			hbox.add_child(button)
			button.text = "create mesh item"		
			button.pressed.connect(func():
				object.collection_id = asset_library.collection_create(object.name)				
				object.notify_property_list_changed()
			)
		add_custom_control(hbox)

	elif object is MAssetTable:		
		add_custom_control(preload("res://addons/m_terrain/asset_manager/debug/asset_table_inspector.tscn").instantiate())
