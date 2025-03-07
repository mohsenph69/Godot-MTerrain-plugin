#class_name Asset_Placer 
@tool
extends PanelContainer

signal selection_changed
signal assets_changed

const hlod_baker_script:=preload("res://addons/m_terrain/asset_manager/hlod_baker.gd")
const ITEM_COLORS = {
	"HLOD": Color(0,1,0.8,0.15),
	"PACKEDSCENE": Color(1,0.5,0,0.15),
	"DECAL": Color(0,0.5,0.8,0.15)
}

var popup_button_group: ButtonGroup
@onready var asset_type_filter_button:Button = find_child("asset_type_filter_button")
@onready var filter_button:Button = find_child("filter_button")
@onready var grouping_button:Button = find_child("grouping_button")
@onready var sort_by_button:Button = find_child("sort_by_button")
@onready var add_asset_button:Button = find_child("add_asset_button")


@onready var assets_tree: Tree = %assets_tree
var action_menu

@onready var grouping_popup:Control = find_child("grouping_popup")
@onready var search_collections_node:Control = find_child("search_collections")

@onready var place_button:Button = find_child("place_button")	
@onready var snap_enabled_button:BaseButton = find_child("snap_enabled_button")
@onready var rotation_enabled_button:BaseButton = find_child("rotation_enabled_button")
@onready var scale_enabled_button:BaseButton = find_child("scale_enabled_button")

@onready var add_baker_button:Button = find_child("add_baker_button")
@onready var add_decal_button:Button = find_child("add_decal_button")
@onready var add_packed_scene_button:Button = find_child("add_packed_scene_button")

@onready var x_btn:Button = find_child("x_btn")
@onready var y_btn:Button = find_child("y_btn")
@onready var z_btn:Button = find_child("z_btn")

@onready var settings_button:Button = find_child("settings_button")

var position_snap:=1.0
var rotation_snap:=PI/6
var scale_snap:=0.25
const rotation_speed:=0.05
const scale_speed:=0.2
				
var need_editor_input:=false
var ur: EditorUndoRedoManager
							
var object_being_placed
enum PLACEMENT_STATE {NONE,MOVING,ROTATING,SCALING} ; var placement_state:=PLACEMENT_STATE.NONE
#var position_confirmed = false
var accumulated_rotation_offset = 0
var accumulated_scale_offset = 1

var asset_library := MAssetTable.get_singleton()
var current_selection := [] #array of collection name
var current_sort_mode = "name_desc"
var current_search := ""
var current_filter_mode_all := false
var current_filter_tags := []
var current_filter_types := 0
var current_group := "None" #group name

var last_regroup = null

var last_added_neighbor = null
var last_added_masset = null
var current_placement_dir:Vector3

static var thumbnail_manager 

func _ready():	
	#############
	## GLOBALS ##
	#############
	if AssetIO.asset_placer==null:
		AssetIO.asset_placer = self
	thumbnail_manager = ThumbnailManager.new()
	add_child(thumbnail_manager)
		
	asset_library.tag_set_name(1, "hidden")
	asset_library.finish_import.connect(func(_arg): 
		assets_changed.emit(_arg)
	)				
	assets_changed.connect(func(_who):
		regroup()
	)
	regroup()	
	
	##########################################################
	## Connect signals for search/sort/filter/group buttons ##
	##########################################################
	find_child("asset_type_tree").asset_type_filter_changed.connect(func(selected_types):
		current_filter_types = selected_types
		regroup()
		update_filter_notifications()
	)	
	find_child("filter_popup").filter_changed.connect(func(tags,mode):		
		current_filter_tags = tags
		current_filter_mode_all = mode
		regroup()		
		update_filter_notifications()
	)		
	grouping_popup.group_selected.connect(regroup)		
	find_child("sort_popup").sort_mode_changed.connect(func(mode):
		regroup(current_group, mode)
	)	
	search_collections_node.text_changed.connect(search_items)	
	
	popup_button_group = ButtonGroup.new()
	popup_button_group.allow_unpress = true
	for button:Button in [asset_type_filter_button, filter_button, grouping_button, sort_by_button, add_asset_button ]:
		button.button_group = popup_button_group
					
	##################
	## PLACE BUTTON ##
	##################
	place_button.toggled.connect(func(toggle_on):				
		if toggle_on:						
			object_being_placed = add_asset_to_scene_from_assets_tree_selection()
			var viewport_camera = EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
			var mcol:MCollision= MTool.ray_collision_y_zero_plane(viewport_camera.global_position,-viewport_camera.global_basis.z)
			if mcol.is_collided():
				object_being_placed.global_position = mcol.get_collision_position()
			else:
				place_button.button_pressed = false
				MTool.print_edmsg("No collission to y-zero plane, rotate the camera towrard the ground")
			#Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			accumulated_rotation_offset = 0
			accumulated_scale_offset = 1
			need_editor_input = true
			placement_state = PLACEMENT_STATE.MOVING
		else:
			if object_being_placed:
				object_being_placed.queue_free()
				object_being_placed = null
	)
			
	###################
	## "ADD" BUTTONS ##
	###################
	add_baker_button.pressed.connect(func():
		AssetIOBaker.create_baker_scene()
		add_asset_button.button_pressed = false
	)
	add_packed_scene_button.pressed.connect(func():
		AssetIO.create_packed_scene()
		add_asset_button.button_pressed = false
		regroup()
	)
	add_decal_button.pressed.connect(func():
		var decal = AssetIO.create_decal()
		assets_changed.emit( decal )
		add_asset_button.button_pressed = false
		regroup()
		
	)
		
	#################
	## ASSETS TREE ##
	#################	
	assets_tree.mouse_entered.connect(func():
		var changed_thumbnails = ThumbnailManager.revalidate_thumbnails()
		var tag_headers = [assets_tree.get_root()] if current_group == "None" else assets_tree.get_children()			
		for tag_header:TreeItem in tag_headers:
			for item:TreeItem in tag_header.get_children():
				for column in assets_tree.columns:
					if not item.get_metadata(column): continue
					if item.get_metadata(column) in changed_thumbnails:
						set_icon(item, column, assets_tree.columns > 6)				
	)	
	action_menu = load("res://addons/m_terrain/asset_manager/asset_placer_action_menu.gd").new()
	assets_tree.add_child(action_menu)
	assets_tree.item_mouse_selected.connect(func(mouse_position, button_index):
		if not button_index == MOUSE_BUTTON_RIGHT: return
		var item = assets_tree.get_selected()
		var column = assets_tree.get_selected_column()
		var collection_id = item.get_metadata(column)
		if not collection_id: return					
		action_menu.item_clicked(collection_id, mouse_position)
	)		
	assets_tree.item_activated.connect(add_asset_to_scene_from_assets_tree_selection)	
	%assets_tree_column_count.value_changed.connect(func(value): regroup())
	
	#################
	## OTHER STUFF ##
	#################
	update_reposition_button_text()
		
func done_placement(add_asset:=true):
	placement_state = PLACEMENT_STATE.NONE
	if add_asset and object_being_placed!=null:
		ur.create_action("Asset Placement",0,EditorInterface.get_edited_scene_root())
		ur.add_do_reference(object_being_placed)
		#ur.add_undo_reference(object_being_placed)
		ur.add_do_method(self,"do_asset_placement",object_being_placed,object_being_placed.get_parent())
		ur.add_undo_method(self,"undo_asset_placement",object_being_placed)
		ur.commit_action(false)
		object_being_placed = null #place_button.button_pressed=false can not remove then node anymore
	need_editor_input = false
	place_button.button_pressed=false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func undo_asset_placement(node:Node3D):
	node.get_parent().remove_child(node)
	node.owner = null
	node.visible = false

func do_asset_placement(node:Node3D,parent:Node):
	parent.add_child(node)
	node.owner = EditorInterface.get_edited_scene_root()
	node.visible = true

func advance_placement_state():
	match placement_state:
		PLACEMENT_STATE.MOVING:
			if rotation_enabled_button.button_pressed:
				placement_state = PLACEMENT_STATE.ROTATING
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			elif scale_enabled_button.button_pressed:
				placement_state = PLACEMENT_STATE.SCALING
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				done_placement()
		PLACEMENT_STATE.ROTATING:
			if scale_enabled_button.button_pressed:
				placement_state = PLACEMENT_STATE.SCALING
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				done_placement()
		PLACEMENT_STATE.SCALING:
			done_placement()
							
func _can_drop_data(at_position: Vector2, data: Variant):		
	if "files" in data and ".glb" in data.files[0]:
		return true

func _drop_data(at_position, data):		
	for file in data.files:
		AssetIO.glb_load(file)
		
##############################
## SEARCH/FILTER/GROUP/SORT ##
##############################
func search_items(text=""):					
	current_search = text		
	regroup()	

func get_filtered_collections(text="", tags_to_excluded=[]):		
	var result = []
	result = asset_library.collections_get_by_type(current_filter_types)
	#var collections_to_exclude = asset_library.tags_get_collections_any(tags_to_excluded) 
	var collection_to_include = null
	if current_filter_tags and len(current_filter_tags)>0:
		if current_filter_mode_all:					
			result = asset_library.tags_get_collections_all(result, current_filter_tags, tags_to_excluded)
		else:		
			result = asset_library.tags_get_collections_any(result, current_filter_tags, tags_to_excluded)
	
	if not text.is_empty():	
		var max = len(result)
		for i in range(max):									
			var id = max - i -1			
			if not asset_library.collection_get_name(result[id]).containsn(text): 				
				result.remove_at(id)				
	return result
		
func regroup_tree(group, sort_mode, columns = %assets_tree_column_count.value):
	assets_tree.clear()
	assets_tree.columns = columns	
	for i in columns:
		assets_tree.set_column_expand(i, false)
		assets_tree.set_column_clip_content(i, false)
		assets_tree.set_column_custom_minimum_width(i, floor(size.x/columns)-2)
	var root:TreeItem = assets_tree.create_item()	
	var filtered_collections = get_filtered_collections(current_search, [0])	
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
	current_group = group
	
func add_tree_item(parent_tree_item:TreeItem, items:Array): #item = {name: name, id: collection_id}	
	var tree_item := parent_tree_item.create_child()
	var icon_only = len(items) > 6
	for i in len(items):		
		var item = items[i]						
		tree_item.set_text(i, item.name)
		tree_item.set_tooltip_text(i, str(item.name))
		tree_item.set_metadata(i, item.id)		
		if item.id in asset_library.collections_get_by_type(MAssetTable.ItemType.PACKEDSCENE):
			tree_item.set_custom_bg_color(i, ITEM_COLORS.PACKEDSCENE)			
		if item.id in asset_library.collections_get_by_type(MAssetTable.ItemType.HLOD):
			tree_item.set_custom_bg_color(i, ITEM_COLORS.HLOD)				
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

#func revalidate_icons():
	#var at:=MAssetTable.get_singleton()
	#for i in group_list.item_count:
		#var cid = group_list.get_item_metadata(i)
		#var thum_path:String=at.get_asset_thumbnails_path(cid)
		#if thum_path.is_empty(): return # not supported
		#var modify_time=at.collection_get_modify_time(cid)
		#if not FileAccess.file_exists(thum_path) or FileAccess.get_modified_time(thum_path) < modify_time:
			#set_icon(i)
	
func regroup(group = current_group, sort_mode= current_sort_mode):		
	regroup_tree(group, sort_mode)
		
func sort_items(sorted_items, sort_mode):	
	if sort_mode == "name_desc":
		sorted_items.sort_custom(func(a,b): return a.name.nocasecmp_to(b.name) < 0 )
	elif sort_mode == "name_asc":
		sorted_items.sort_custom(func(a,b): return a.name.nocasecmp_to(b.name) > 0 )
	elif sort_mode == "modified_desc":		
		sorted_items.sort_custom(func(a,b): return a.modified_time < b.modified_time)		
	elif sort_mode == "modified_asc":
		sorted_items.sort_custom(func(a,b): return a.modified_time > b.modified_time)		

func update_filter_notifications():
	var asset_type_notification = asset_type_filter_button.get_node("notification_texture")
	var filter_notification = filter_button.get_node("notification_texture")		
	asset_type_notification.visible = current_filter_types < MAssetTable.ItemType.DECAL + MAssetTable.ItemType.HLOD + MAssetTable.ItemType.MESH + MAssetTable.ItemType.PACKEDSCENE 
	filter_notification.visible = len(current_filter_tags) != 0

##################
## PLACE ASSETS ##
##################
func add_asset_to_scene_from_assets_tree_selection():
	var item = assets_tree.get_selected()
	var column = assets_tree.get_selected_column()
	var collection_id = item.get_metadata(column)
	var collection_name = item.get_tooltip_text(column)
	return add_asset_to_scene(collection_id, collection_name)
	
func add_asset_to_scene(collection_id, asset_name,create_ur:=true):	
	var node
	if collection_id in asset_library.collections_get_by_type(MAssetTable.ItemType.MESH):
		node = MAssetMesh.new()
		node.collection_id = collection_id		
	elif collection_id in asset_library.collections_get_by_type(MAssetTable.ItemType.HLOD):
		node = MHlodScene.new()		
		node.hlod = load(MHlod.get_hlod_path( asset_library.collection_get_item_id(collection_id) ))
		node.set_meta("collection_id", collection_id)
	elif collection_id in asset_library.collections_get_by_type(MAssetTable.ItemType.DECAL):
		node = MDecalInstance.new()
		var path = MHlod.get_decal_path( asset_library.collection_get_item_id(collection_id) )		
		node.decal = load(path)		
		node.name = asset_library.collection_get_name(collection_id)
	elif collection_id in asset_library.collections_get_by_type(MAssetTable.ItemType.PACKEDSCENE):
		node = load(MHlod.get_packed_scene_path( asset_library.collection_get_item_id(collection_id) )).instantiate()
		node.set_meta("collection_id", collection_id)
	var selected_nodes = EditorInterface.get_selection().get_selected_nodes()	
	var scene_root = EditorInterface.get_edited_scene_root()	
	var main_selected_node = null
	var parent:Node = null
	if len(selected_nodes) != 1:
		parent = scene_root
	else:
		parent = selected_nodes[0]
		main_selected_node = selected_nodes[0]
		while (parent is MAssetMesh or parent is MHlodScene or parent is MDecalInstance) and parent != scene_root:
			parent = parent.get_parent()			
	parent.add_child(node)
	node.owner = EditorInterface.get_edited_scene_root()
	node.name = asset_name
	node.global_transform = get_added_node_transform(main_selected_node,current_placement_dir)
	if create_ur:
		ur.create_action("Add Asset",0,EditorInterface.get_edited_scene_root())
		ur.add_do_reference(node)		
		ur.add_do_method(self,"do_asset_add",node,parent,last_added_neighbor)
		ur.add_undo_method(self,"undo_asset_add",node,last_added_masset,last_added_neighbor)
		ur.commit_action(false)
	last_added_neighbor = main_selected_node
	last_added_masset = node
	single_select_node(node)	
	return node

func do_asset_add(node:Node3D,parent:Node,_last_added_neighbor):
	parent.add_child(node)
	node.owner = EditorInterface.get_edited_scene_root()
	node.visible = true
	last_added_masset = node
	last_added_neighbor = _last_added_neighbor
	single_select_node(node)

func undo_asset_add(node:Node,_last_added_masset,_last_added_neighbor):
	node.get_parent().remove_child(node)
	node.visible = false
	last_added_masset = _last_added_masset
	last_added_neighbor = _last_added_neighbor
	if is_instance_valid(last_added_masset):
		single_select_node(last_added_masset)

func single_select_node(node:Node):
	EditorInterface.get_selection().call_deferred("clear")
	EditorInterface.get_selection().call_deferred("add_node",node)

# dir component can be 1,-1,0
func get_added_node_transform(neighbor:Node,dir:Vector3) -> Transform3D:
	if neighbor == null or not neighbor is Node3D:
		return Transform3D()
	if not neighbor is MAssetMesh and not neighbor is MHlodScene and not neighbor is MDecalInstance:
		return Transform3D(Basis(),neighbor.global_transform.origin)
	var aabb:AABB
	if neighbor is MAssetMesh: aabb=neighbor.get_joined_aabb()
	else: aabb=neighbor.get_aabb()
	var origin = neighbor.global_transform * (dir * aabb.size)
	return Transform3D(neighbor.global_basis,origin)

func reposition_origin():
	if last_added_masset==null or last_added_neighbor==null: return
	var old_dir = current_placement_dir
	var old_transform:Transform3D = last_added_masset.global_transform
	current_placement_dir = Vector3(0,0,0)
	last_added_masset.global_transform = get_added_node_transform(last_added_neighbor,current_placement_dir)
	update_reposition_button_text()
	undo_redo_reposition(last_added_masset,old_transform,old_dir)

func reposition_input_toggle(input:float)->float:
	input += 1
	if input > 1:
		return -1
	return input

func reposition_x():
	if last_added_masset==null or last_added_neighbor==null: return
	var old_dir = current_placement_dir
	current_placement_dir.x = reposition_input_toggle(current_placement_dir.x)
	var old_transform:Transform3D = last_added_masset.global_transform
	last_added_masset.global_transform = get_added_node_transform(last_added_neighbor,current_placement_dir)
	update_reposition_button_text()
	undo_redo_reposition(last_added_masset,old_transform,old_dir)

func reposition_y():
	if last_added_masset==null or last_added_neighbor==null: return
	var old_dir = current_placement_dir
	current_placement_dir.y = reposition_input_toggle(current_placement_dir.y)
	var old_transform:Transform3D = last_added_masset.global_transform
	last_added_masset.global_transform = get_added_node_transform(last_added_neighbor,current_placement_dir)
	update_reposition_button_text()
	undo_redo_reposition(last_added_masset,old_transform,old_dir)

func reposition_z():
	if last_added_masset==null or last_added_neighbor==null: return
	var old_dir = current_placement_dir
	current_placement_dir.z = reposition_input_toggle(current_placement_dir.z)
	var old_transform:Transform3D = last_added_masset.global_transform
	last_added_masset.global_transform = get_added_node_transform(last_added_neighbor,current_placement_dir)
	update_reposition_button_text()
	undo_redo_reposition(last_added_masset,old_transform,old_dir)

func update_reposition_button_text():
	x_btn.text = "x("+str(current_placement_dir.x)+")"
	y_btn.text = "y("+str(current_placement_dir.y)+")"
	z_btn.text = "z("+str(current_placement_dir.z)+")"

func _replace_asset(new_ids:PackedInt64Array,masset_node:Array) -> void:
	if new_ids.size() != masset_node.size():
		printerr("mismatch new_asset old asset count")
		return
	for i in range(new_ids.size()):
		masset_node[i].collection_id = new_ids[i]

# should be called after moving
func undo_redo_reposition(node:Node3D,old_transform:Transform3D,old_dir:Vector3):
	ur.create_action("Transform")
	ur.add_do_method(node,"set","global_transform",node.global_transform)
	ur.add_do_method(self,"set","current_placement_dir",current_placement_dir)
	ur.add_do_method(self,"update_reposition_button_text")
	ur.add_undo_method(node,"set","global_transform",old_transform)
	ur.add_undo_method(self,"set","current_placement_dir",old_dir)
	ur.add_undo_method(self,"update_reposition_button_text")
	ur.commit_action(false)
			
func _forward_3d_gui_input(viewport_camera, event):
	if placement_state==PLACEMENT_STATE.NONE:
		done_placement()
		return
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE:
			place_button.button_pressed = false			
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			done_placement(false)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				advance_placement_state()
				return EditorPlugin.AFTER_GUI_INPUT_STOP
	if event is InputEventMouseMotion:			
		if placement_state==PLACEMENT_STATE.ROTATING:
			accumulated_rotation_offset += sign(event.relative.x) * rotation_speed
			if int(snap_enabled_button.button_pressed) ^ int(event.ctrl_pressed):
				var new_rotation = snapped(accumulated_rotation_offset, rotation_snap)
				object_being_placed.rotation.y=new_rotation
			else:
				object_being_placed.rotation.y = accumulated_rotation_offset
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		elif placement_state==PLACEMENT_STATE.SCALING:
			accumulated_scale_offset += sign(event.relative.y) * scale_speed
			var fs = accumulated_scale_offset
			if int(snap_enabled_button.button_pressed) ^ int(event.ctrl_pressed):
				fs = snapped(fs,scale_snap)
			if fs < 0.01:
				fs = 0.01
			object_being_placed.scale = Vector3(fs,fs,fs)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		elif placement_state==PLACEMENT_STATE.MOVING:
			#var viewport_camera: Camera3D = EditorInterface.get_editor_viewport_3d(0).get_camera_3d()						
			var mcol = MTool.ray_collision_y_zero_plane(viewport_camera.global_position,viewport_camera.project_ray_normal(event.position))
			if mcol.is_collided():
				if int(snap_enabled_button.button_pressed) ^ int(event.ctrl_pressed):
					object_being_placed.global_position = snapped(mcol.get_collision_position(),Vector3(position_snap,position_snap,position_snap))
				else:
					object_being_placed.global_position = mcol.get_collision_position()
			return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_PASS

#region Debug	
#########
# DEBUG #
#########		
func init_debug_tags():
	var groups = {"colors": [0,1,2], "sizes":[3,4,5], "building_parts": [6,7,8,9]}   #data.categories
	var tags = ["red", "green", "blue", "small", "medium", "large", "wall", "floor", "roof", "door"]#data.tags		
	asset_library.tag_set_name(0, "single_item_collection")
	asset_library.tag_set_name(1, "hidden")
	for tag in tags:
		if asset_library.tag_get_id(tag) == -1:
			for j in 256:
				if j < 2: continue #0: single_item_collection, 1: hidden
				if asset_library.tag_get_name(j) == "":
					asset_library.tag_set_name(j, tag)
					break
			#asset_library.tag_add(tag)					
	for group in groups:
		if not asset_library.group_exist(group):			
			asset_library.group_create(group)
		for i in groups[group]:				
			var tag_name = tags[i]
			var tag_id = asset_library.tag_get_id(tag_name)
			asset_library.group_add_tag(group, tag_id)			
	asset_library.save()	
#endregion

#####################
## SETTINGS WINDOW ##
#####################
func open_settings_window(tab, data):
	if tab == "tag":
		settings_button.button_pressed = true
		settings_button.settings.select_tab("manage_tags")
		settings_button.settings.manage_tags_control.select_collection(data)		


func on_main_screen_changed():
	settings_button.button_pressed = false
