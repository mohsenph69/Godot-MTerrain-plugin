@tool
extends Control

@onready var glb_tree:Tree = find_child("glb_tree")
@onready var glb_details:Tree = find_child("glb_details")
@onready var show_materials_toggle:CheckButton = find_child("show_materials_toggle")

var asset_library = MAssetTable.get_singleton()
var button_texture: Texture2D
var empty_click_debounce_time := 0

var glb_path

func _ready():
	visibility_changed.connect(init_tree)
	glb_tree.set_column_expand(1, false)
	glb_details.set_column_expand(1, false)	
	glb_tree.empty_clicked.connect(func(_click_position, _mouse_button):
		if Time.get_ticks_msec() - empty_click_debounce_time < 320:
			var dialog := EditorFileDialog.new()
			dialog.access = EditorFileDialog.ACCESS_RESOURCES
			dialog.add_filter("*.glb")
			dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
			dialog.file_selected.connect(func(path): AssetIO.glb_load(path))
			add_child(dialog)
			dialog.popup_file_dialog()
			#dialog.close_requested.connect(dialog.queue_free)
		empty_click_debounce_time = Time.get_ticks_msec()	
	)
	#show_materials_toggle.toggled.connect(func(toggle_on):		
		#update_details()
	#)
	#glb_tree.item_selected.connect(update_details)
	glb_tree.item_activated.connect(func():		
		AssetIO.glb_load(glb_tree.get_selected().get_text(0))
	)
	glb_tree.button_clicked.connect(func(item:TreeItem, column, id, mouse_button_index):
		glb_path = item.get_text(0)
		if glb_path == "(orphans)":			
			# THIS SHOULD NEVER HAPPEN
			for collection_id in AssetIO.get_orphaned_collections():												
				AssetIO.remove_collection(collection_id)				
		else:
			AssetIO.remove_glb(glb_path)
			#for collection in asset_library.import_info[glb_path].keys():
				#if "__" in collection: continue
				#var collection_id = asset_library.import_info[glb_path][collection].id
				#AssetIO.remove_collection(collection_id)
			#asset_library.import_info.erase(glb_path)		
		init_tree()
	)
	glb_details.button_clicked.connect(func(item:TreeItem, column, id, mouse_button_index):		
		AssetIO.remove_collection(item.get_metadata(0))
		glb_details.get_root().remove_child(item)
	)
	
	find_child("glb_search").text_changed.connect(func(new_text):
		for item in glb_tree.get_root().get_children():
			item.visible = new_text.to_lower() in item.get_text(0).to_lower() or new_text == ""
	)
	find_child("collection_search").text_changed.connect(func(new_text):
		for item in glb_details.get_root().get_children():
			item.visible = new_text.to_lower() in item.get_text(0).to_lower() or new_text == ""
	)
	if not asset_library.finish_import.is_connected(on_finish_import):
		asset_library.finish_import.connect(on_finish_import)

func update_details():
	var glb_path = glb_tree.get_selected().get_text(0)				
	glb_details.clear()
	var root := glb_details.create_item()
	if show_materials_toggle.button_pressed:
		if asset_library.import_info.has(glb_path) and asset_library.import_info[glb_path].has("__materials"):				
			for material_name in asset_library.import_info[glb_path]["__materials"]:								
				var material_id = asset_library.import_info[glb_path]["__materials"][material_name].path					
				var item = root.create_child() 					
				var path = asset_library.import_info["__materials"][material_id].path if material_id != -1 else "(none)"
				item.set_text(0, "MATERIAL: " + material_name + " -> " + path)
				#item.set_icon(0, texture)
				item.set_metadata(0, material_id)					
				#item.add_button(2, button_texture)
	
	if glb_path == "(orphans)":			
		for id in AssetIO.get_orphaned_collections():				
			var texture = asset_library.collection_get_cache_thumbnail(id)
			var item = root.create_child() 
			if asset_library.has_collection(id):
				item.set_text(0, asset_library.collection_get_name(id))
				item.set_icon(0, texture)
				item.set_metadata(0, id)					
				item.add_button(1, button_texture)
	else:
		for collection_name in asset_library.import_info[glb_path].keys():
			if "__" in collection_name: continue			
			if asset_library.import_info[glb_path][collection_name].has("ignore"): continue
			var collection_id = asset_library.import_info[glb_path][collection_name].id
			var texture = asset_library.collection_get_cache_thumbnail(collection_id)
			var item = root.create_child() 
			item.set_text(0, collection_name)
			item.set_icon(0, texture)
			item.set_metadata(0, collection_id)									
			item.add_button(1, button_texture)
	
func on_finish_import(path):	
	init_tree()
	
func init_tree():
	glb_tree.clear()
	glb_details.clear()
	var root := glb_tree.create_item()
	if not button_texture:
		button_texture = load("res://addons/m_terrain/icons/icon_close.svg")
		var image := button_texture.get_image()
		image.resize(32,32)
		button_texture = ImageTexture.create_from_image(image)						
	for glb_path in asset_library.import_info.keys():
		if glb_path.begins_with("__"): continue
		var item = root.create_child()
		item.set_text(0, glb_path)				
		item.add_button(1, button_texture)
	if DirAccess.dir_exists_absolute(MAssetTable.get_hlod_res_dir()):
		for hlod_path in DirAccess.get_files_at(MAssetTable.get_hlod_res_dir()):
			var item = root.create_child()
			item.set_text(0, hlod_path + " (hlod)")				
			item.add_button(1, button_texture)
	if len(AssetIO.get_orphaned_collections())>0:
		var item = root.create_child()
		item.set_text(0, "(orphans)")				
		item.add_button(1, button_texture)

	
