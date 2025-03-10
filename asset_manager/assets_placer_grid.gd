@tool
extends Tree

var asset_library := MAssetTable.get_singleton()

var action_menu
var filter_settings

var mterrain_theme:Theme = load("res://addons/m_terrain/gui/styles/mterrain_gui_theme.tres")

func _ready():
	filter_settings = load(AssetIO.filter_settings_path)			
	mouse_entered.connect(func():
		var changed_thumbnails = ThumbnailManager.revalidate_thumbnails()
		var tag_headers = [get_root()] if filter_settings.current_group == "None" else get_children()			
		for tag_header:TreeItem in tag_headers:
			for item:TreeItem in tag_header.get_children():
				for column in columns:
					if not item.get_metadata(column): continue
					if item.get_metadata(column) in changed_thumbnails:
						set_icon(item, column, columns > 6)				
	)	
	action_menu = load("res://addons/m_terrain/asset_manager/asset_placer_action_menu.gd").new()
	add_child(action_menu)
	item_mouse_selected.connect(func(mouse_position, button_index):		
		var item = get_selected()
		var column = get_selected_column()
		if item.get_text(column).is_empty():
			if not Input.is_key_pressed(KEY_CTRL) and not Input.is_key_pressed(KEY_SHIFT):
				deselect_all()			
		var collection_id = item.get_metadata(column)
		if not button_index == MOUSE_BUTTON_RIGHT: return		
		if collection_id < 0: return					
		action_menu.item_clicked(collection_id, mouse_position)
	)		
	resized.connect(func():
		for i in columns:		
			set_column_custom_minimum_width(i, floor(size.x/columns)-2)
	)
	filter_settings.filter_changed.connect(regroup_tree)	
	regroup_tree.call_deferred()			
	
func sort_items(sorted_items, sort_mode):	
	if sort_mode == "name_desc":
		sorted_items.sort_custom(func(a,b): return a.name.nocasecmp_to(b.name) < 0 )
	elif sort_mode == "name_asc":
		sorted_items.sort_custom(func(a,b): return a.name.nocasecmp_to(b.name) > 0 )
	elif sort_mode == "modified_desc":		
		sorted_items.sort_custom(func(a,b): return a.modified_time < b.modified_time if a.has("modified_time") else false)		
	elif sort_mode == "modified_asc":
		sorted_items.sort_custom(func(a,b): return a.modified_time > b.modified_time)		
			
func regroup_tree():	
	clear()
	var group=filter_settings.current_group
	var sort_mode=filter_settings.current_sort_mode
	columns = filter_settings.column_count	
	for i in columns:
		set_column_expand(i, false)
		set_column_clip_content(i, false)
		set_column_custom_minimum_width(i, floor(size.x/columns)-2)
	var root:TreeItem = create_item()	
	var filtered_collections = filter_settings.get_filtered_collections([0])	
	if group == "None":	
		var ungrouped = root
		var sorted_items = []				
		for collection_id in filtered_collections:
			var collection_name = asset_library.collection_get_name(collection_id)
			var modified_time = asset_library.collection_get_modify_time(collection_id)
			sorted_items.push_back({"name":collection_name, "id":collection_id, "modified_time":modified_time})			
			collection_id += 1
		sort_items(sorted_items, sort_mode)				
		if columns == 1:
			for item in sorted_items:			
				add_tree_item(root, [item])
		else:
			var row = 0
			while row * columns < len(sorted_items):								
				add_tree_item(root, sorted_items.slice(row*columns, (row+1)*columns))
				row += 1				
	else:		
		var processed_collections: PackedInt32Array = []
		for tag_id in asset_library.group_get_tags(group) :			
			var tag_name = asset_library.tag_get_name(tag_id)
			if tag_name == "": continue
			var tag_header := root.create_child()
			tag_header.set_text(0, tag_name)
			var sorted_items = []									
			for collection_id in asset_library.tags_get_collections_any(filtered_collections, [tag_id],[]):
				sorted_items.push_back({"name": asset_library.collection_get_name(collection_id), "id":collection_id})
				processed_collections.push_back(collection_id)
			sort_items(sorted_items, sort_mode)				
			if columns == 1:
				for item in sorted_items:
					add_tree_item(tag_header, [item])
			else:
				var row = 0
				while row * columns < len(sorted_items):									
					add_tree_item(tag_header, sorted_items.slice(row*columns, (row+1)*columns))
					row += 1
					
		# Now add leftovers to "Ungrouped" tag
		var ungrouped =root.create_child()
		ungrouped.set_text(0, "Other")
		var sorted_items = []
		for collection_id in filtered_collections:
			if collection_id in processed_collections: continue
			sorted_items.push_back({"name": asset_library.collection_get_name(collection_id), "id":collection_id})
		if sort_mode == "asc":
			sorted_items.sort_custom(func(a,b): return a.name < b.name)
		elif sort_mode == "desc":
			sorted_items.sort_custom(func(a,b): return a.name > b.name)		
		if columns == 1:		
			for item in sorted_items:	
				add_tree_item(ungrouped, [item])
		else:
			var row = 0
			while row * columns < len(sorted_items):								
				add_tree_item(ungrouped, sorted_items.slice(row*columns, (row+1)*columns))
				row += 1	
							
func add_tree_item(parent_tree_item:TreeItem, items:Array): #item = {name: name, id: collection_id}	
	var tree_item := parent_tree_item.create_child()
	var icon_only = len(items) > 6
	for i in columns:			
		if i >= len(items):			
			tree_item.set_metadata(i, -1)		
			continue
		#	tree_item.set_selectable(i, false)		
		#else:
		#	tree_item.set_selectable(i, true)
		var item = items[i]						
		tree_item.set_text(i, item.name)
		tree_item.set_tooltip_text(i, str(item.name))
		tree_item.set_metadata(i, item.id)		
		if item.id in asset_library.collections_get_by_type(MAssetTable.ItemType.PACKEDSCENE):
			tree_item.set_custom_bg_color(i, mterrain_theme.get_color("packed_scene", "asset_placer"))		
		if item.id in asset_library.collections_get_by_type(MAssetTable.ItemType.HLOD):
			tree_item.set_custom_bg_color(i, mterrain_theme.get_color("hlod", "asset_placer"))
	# Now any item has the potential to generate icon
	# if asset Table get_asset_thumbnails_path return empty path this means
	# currently this type is not supported
		set_icon(tree_item, i, icon_only) # should be called last	

## Set icon with no dely if thumbnail is valid
func set_icon(tree_item:TreeItem, column:int, icon_only:bool)->void:
	var current_item_collection_id:int= tree_item.get_metadata(column)
	var tex:Texture2D= ThumbnailManager.get_valid_thumbnail(current_item_collection_id)
	var type = MAssetTable.get_singleton().collection_get_type(current_item_collection_id)
	if tex != null:
		tree_item.set_icon(column, tex)				
		if icon_only:
			tree_item.set_text(column, "")								
		return
	if type==MAssetTable.MESH:
		var _cmesh = MAssetMesh.get_collection_merged_mesh(current_item_collection_id,true)
		if _cmesh:		
			ThumbnailManager.thumbnail_queue.push_back({"resource": _cmesh, "caller": tree_item, "callback": update_thumbnail, "collection_id": current_item_collection_id})	
	elif type==MAssetTable.DECAL:
		var dtex:=ThumbnailManager.generate_decal_texture(current_item_collection_id)
		if dtex:
			tree_item.set_icon(column, dtex)			
			if icon_only:
				tree_item.set_text(column, "")				
	# For HLOD it should be generated at bake time we don't generate that here
	# so normaly it should be grabed by the first step

func update_thumbnail(data):
	if not data.texture is Texture2D:
		push_warning("thumbnail error: ", " item ", data.caller.get_text(0))
	var asset_library = MAssetTable.get_singleton()
	var thumbnail_path = asset_library.get_asset_thumbnails_path(data.collection_id)
	### Updating Cache
	ThumbnailManager.save_thumbnail(data.texture.get_image(), thumbnail_path)
	## This function excute with delay we should check if item collection id is not changed	
	if data.caller.get_metadata(0) == data.collection_id:			
		data.caller.set_icon(0, data.texture)		
