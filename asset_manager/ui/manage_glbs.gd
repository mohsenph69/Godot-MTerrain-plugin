@tool
extends Control

@onready var glb_tree:Tree = find_child("glb_tree")
@onready var glb_details:Tree = find_child("glb_details")
@onready var show_materials_toggle:CheckButton = find_child("show_materials_toggle")

var asset_library = MAssetTable.get_singleton()
var close_button_texture: Texture2D
var search_button_texture: Texture2D
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
		if id == 0:
			EditorInterface.get_file_system_dock().navigate_to_path(glb_path)
		elif id == 1:
			var meta = item.get_metadata(0)
			if meta:
				# TODO add undo capability								
				var popup := ConfirmationDialog.new()
				popup.dialog_text = "Are you sure you want to remove all history of this glb path from the asset library?"
				popup.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
				popup.get_cancel_button().get_parent().move_child(popup.get_cancel_button(),1)
				popup.get_cancel_button().get_parent().move_child(popup.get_ok_button(),3)
				add_child(popup)
				popup.confirmed.connect(func():					
					asset_library.import_info.erase(meta)
					init_tree()
				)				
				popup.popup_centered()
			else:
				var popup := ConfirmationDialog.new()
				popup.dialog_text = "Are you sure you want to remove this glb from the asset browser?\nA backup of the asset info will be kept in case you change your mind"
				popup.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
				popup.get_cancel_button().get_parent().move_child(popup.get_cancel_button(),1)
				popup.get_cancel_button().get_parent().move_child(popup.get_ok_button(),3)
				add_child(popup)
				popup.confirmed.connect(func():					
					AssetIO.glb_load_assets(null, glb_path,{}, true)
					asset_library.import_info[glb_path]['__removed'] = true			
					init_tree()
				)								
				popup.popup_centered()
				
		init_tree()
	)
	#glb_details.button_clicked.connect(func(item:TreeItem, column, id, mouse_button_index):		
		#AssetIO.remove_collection(item.get_metadata(0))
		#glb_details.get_root().remove_child(item)
	#)
	
	find_child("glb_search").text_changed.connect(func(new_text):
		for item in glb_tree.get_root().get_children():
			item.visible = item.get_text(0).containsn(new_text) or new_text == ""
	)
	find_child("collection_search").text_changed.connect(func(new_text):
		for item in glb_details.get_root().get_children():
			item.visible = item.get_text(0).containsn(new_text) or new_text == ""
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
				#item.add_button(2, close_button_texture)
	
	if glb_path == "(orphans)":			
		for id in AssetIO.get_orphaned_collections():				
			var texture = asset_library.collection_get_cache_thumbnail(id)
			var item = root.create_child() 
			if asset_library.has_collection(id):
				item.set_text(0, asset_library.collection_get_name(id))
				item.set_icon(0, texture)
				item.set_metadata(0, id)					
				item.add_button(1, close_button_texture)
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
			item.add_button(1, close_button_texture)
	
func on_finish_import(path):	
	init_tree()
	
func init_tree():
	glb_tree.clear()
	glb_details.clear()
	var root := glb_tree.create_item()
	if not close_button_texture:
		close_button_texture = load("res://addons/m_terrain/icons/trash.svg")
		var image := close_button_texture.get_image()
		image.resize(32,32)
		close_button_texture = ImageTexture.create_from_image(image)						
	if not search_button_texture:
		search_button_texture = load("res://addons/m_terrain/icons/search_icon.svg")
		var image := search_button_texture.get_image()
		image.resize(32,32)
		search_button_texture = ImageTexture.create_from_image(image)						
	var removed_glbs = []
	for glb_path in asset_library.import_info.keys():		
		if glb_path.begins_with("__"): continue
		if asset_library.import_info[glb_path].has("__removed"): 
			removed_glbs.push_back(glb_path)
			continue
		var item = root.create_child()
		item.set_text(0, glb_path)						
		item.add_button(1, search_button_texture,0)
		item.add_button(1, close_button_texture,1)
	#if DirAccess.dir_exists_absolute(MAssetTable.get_hlod_res_dir()):
		#for hlod_path in DirAccess.get_files_at(MAssetTable.get_hlod_res_dir()):
			#var item = root.create_child()
			#item.set_text(0, hlod_path + " (hlod)")				
			#item.add_button(1, close_button_texture)
	#if DirAccess.dir_exists_absolute(MAssetTable.get_hlod_res_dir()):
		#for hlod_path in DirAccess.get_files_at(MAssetTable.get_hlod_res_dir()):
			#var item = root.create_child()
			#item.set_text(0, hlod_path + " (hlod)")				
			#item.add_button(1, close_button_texture)	
	for glb_path in removed_glbs:	
		var item = root.create_child()	
		item.set_text(0, glb_path + " (removed)")				
		item.set_metadata(0, glb_path)				
		item.add_button(1, search_button_texture,0)
		item.add_button(1, close_button_texture, 1)
		item.set_custom_bg_color(0, Color(1,0,0,0.2))
		
	#if len(AssetIO.get_orphaned_collections())>0:
		#var item = root.create_child()
		#item.set_text(0, "(orphans)")				
		#item.add_button(1, close_button_texture)

	
