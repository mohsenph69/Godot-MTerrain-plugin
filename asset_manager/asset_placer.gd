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



@onready var groups = find_child("groups")
@onready var ungrouped = find_child("other")
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
var active_group_list #the last one selected
var active_group_list_item #id of the last one selected
enum PLACEMENT_STATE {NONE,MOVING,ROTATING,SCALING} ; var placement_state:=PLACEMENT_STATE.NONE
#var position_confirmed = false
var accumulated_rotation_offset = 0
var accumulated_scale_offset = 1

var asset_library := MAssetTable.get_singleton()
var current_selection := [] #array of collection name
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
	popup_button_group = ButtonGroup.new()
	popup_button_group.allow_unpress = true
	for button:Button in [asset_type_filter_button, filter_button, grouping_button, sort_by_button, add_asset_button ]:
		button.button_group = popup_button_group
	
	thumbnail_manager = ThumbnailManager.new()
	add_child(thumbnail_manager)
	#if not EditorInterface.get_edited_scene_root() or EditorInterface.get_edited_scene_root() == self or EditorInterface.get_edited_scene_root().is_ancestor_of(self): return
	update_reposition_button_text()
	asset_library.tag_set_name(1, "hidden")
	asset_library.finish_import.connect(func(_arg): 
		assets_changed.emit(_arg)
	)			
	ungrouped.asset_placer = self
	ungrouped.set_group("other")	
	assets_changed.connect(func(_who):
		regroup()
	)
	regroup()	
	find_child("sort_popup").sort_mode_changed.connect(func(mode):
		regroup(current_group, mode)
	)
	
	#Connect signals for buttons	
	search_collections_node.text_changed.connect(search_items)	
	find_child("filter_popup").filter_changed.connect(func(tags,mode):		
		current_filter_tags = tags
		current_filter_mode_all = mode
		regroup()		
	)
	ungrouped.group_list.multi_selected.connect(func(id, selected):
		process_selection(ungrouped.group_list, id, selected)
	)
	ungrouped.group_list.multi_selected.connect(set_active_group_list_and_id.bind(ungrouped.group_list))
	ungrouped.group_list.item_activated.connect(collection_item_activated.bind(ungrouped.group_list))
	grouping_popup.group_selected.connect(regroup)		
	place_button.toggled.connect(func(toggle_on):		
		#%place_options_hbox.visible = toggle_on
		if toggle_on:			
			object_being_placed = collection_item_activated(active_group_list_item, active_group_list,false)
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
			
	add_baker_button.pressed.connect(create_baker_scene)
	add_packed_scene_button.pressed.connect(create_packed_scene)
	add_decal_button.pressed.connect(create_decal)
	find_child("asset_type_tree").asset_type_filter_changed.connect(func(selected_types):
		current_filter_types = selected_types
		regroup()
	)
	
func create_baker_scene():	
	var dir = MAssetTable.get_editor_baker_scenes_dir()
	var existing_files = DirAccess.get_files_at(dir)		
	var file = "baker.tscn" 
	var i = 0		
	while file in existing_files:			
		i+= 1
		file = "baker" +str(i) +".tscn"
	var node = preload("res://addons/m_terrain/asset_manager/hlod_baker.gd").new()				
	node.name = file.trim_suffix(".tscn")
	var packed = PackedScene.new()
	packed.pack(node)
	ResourceSaver.save(packed, dir.path_join(file))		
	EditorInterface.open_scene_from_path(dir.path_join(file))
	#MTool.print_edmsg("")
	add_asset_button.button_pressed = false
	
func create_packed_scene():
	var id = MAssetTable.get_last_free_packed_scene_id()	
	var node := MHlodNode3D.new()		
	node.name = "MHlodNode3D_" + str(id)
	var collection_id = asset_library.collection_create(node.name, id, MAssetTable.PACKEDSCENE, -1)
	asset_library.save()
	node.set_meta("collection_id", collection_id)	
	var packed = PackedScene.new()
	packed.pack(node)
	var path = MHlod.get_packed_scene_path(id)
	ResourceSaver.save(packed, path)			
	EditorInterface.open_scene_from_path(path)			
	add_asset_button.button_pressed = false
	regroup()
	
func create_decal():
	var id = MAssetTable.get_last_free_decal_id()		
	var decal := MDecal.new()
	decal.resource_name = "New Decal"
	var path = MHlod.get_decal_path(id)		
	#if FileAccess.file_exists(path):	
	ResourceSaver.save(decal, path)	
	decal.take_over_path(path)	
	var collection_id = asset_library.collection_create(decal.resource_name, id, MAssetTable.DECAL, -1)
	asset_library.save()
	assets_changed.emit(decal)		
	var node := MDecalInstance.new()	
	node.decal = decal
	ResourceSaver.save(decal, path)				
	var scene_root = EditorInterface.get_edited_scene_root()
	if scene_root==null:
		return
	scene_root.add_child(node)
	node.name = "New Decal"
	node.owner = scene_root
	node.set_meta("collection_id", collection_id)
	add_asset_button.button_pressed = false
	regroup()
	
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

func set_active_group_list_and_id(id, selected, group_list):
	if not selected: return
	#print(id, group_list)
	active_group_list_item = id
	place_button.disabled = false
	active_group_list = group_list
	
func search_items(text=""):					
	current_search = text		
	regroup()	
						
func _can_drop_data(at_position: Vector2, data: Variant):		
	if "files" in data and ".glb" in data.files[0]:
		return true

func _drop_data(at_position, data):		
	for file in data.files:
		AssetIO.glb_load(file)
		
####################
# GROUPS AND ITEMS #
####################
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
	
func debounce_regroup():
	if not is_inside_tree():  return false
	if last_regroup is int and Time.get_ticks_msec() - last_regroup < 1000:
		last_regroup = get_tree().create_timer(0.2)
		last_regroup.timeout.connect(func():
			last_regroup = 0
			regroup()
		)
		return false
	elif last_regroup is SceneTreeTimer:
		return false	
	last_regroup = Time.get_ticks_msec()
	return true
	
func regroup(group = current_group, sort_mode="asc"):	
	if current_group != group:		
		for child in groups.get_children():
			groups.remove_child(child)
			child.queue_free()
		current_group = group
	if not debounce_regroup(): 
		return
	var filtered_collections = get_filtered_collections(current_search, [0])	
	if group == "None":		
		ungrouped.group_list.clear()	
		var sorted_items = []				
		for collection_id in filtered_collections:
			var collection_name = asset_library.collection_get_name(collection_id)
			sorted_items.push_back({"name":collection_name, "id":collection_id})			
			collection_id += 1
		if sort_mode == "asc":
			sorted_items.sort_custom(func(a,b): return a.name < b.name)
		elif sort_mode == "desc":
			sorted_items.sort_custom(func(a,b): return a.name > b.name)
		for item in sorted_items:
			ungrouped.add_item(item.name, item.id)												
		ungrouped.group_button.visible = false			
	elif group in asset_library.group_get_list():
		ungrouped.group_button.visible = true
		var group_control_scene = preload("res://addons/m_terrain/asset_manager/ui/group_control.tscn")		
		var processed_collections: PackedInt32Array = []
		for tag_id in asset_library.group_get_tags(group) :			
			var tag_name = asset_library.tag_get_name(tag_id)
			if tag_name == "": continue
			var group_control
			var sorted_items = []
			# Make the tag button if it doesn't exist yet
			if not groups.has_node(tag_name):				
				group_control = group_control_scene.instantiate()								
				group_control.asset_placer = self
				groups.add_child(group_control)							
				if not group_control.group_list:
					continue
				group_control.group_list.multi_selected.connect(func(id, selected):
					process_selection(group_control.group_list, id, selected)
				)
				group_control.set_group(asset_library.tag_get_name(tag_id))					
				group_control.group_list.item_activated.connect(collection_item_activated.bind(group_control.group_list))
				group_control.group_list.multi_selected.connect(set_active_group_list_and_id.bind(group_control))
				group_control.name = tag_name				
			else:
				group_control = groups.get_node(tag_name)			
				group_control.group_list.clear()
						
			for collection_id in asset_library.tags_get_collections_any(filtered_collections, [tag_id],[]):
				sorted_items.push_back({"name": asset_library.collection_get_name(collection_id), "id":collection_id})
				processed_collections.push_back(collection_id)
			if sort_mode == "asc":
				sorted_items.sort_custom(func(a,b): return a.name < b.name)
			elif sort_mode == "desc":
				sorted_items.sort_custom(func(a,b): return a.name > b.name)
			for item in sorted_items:
				group_control.add_item(item.name, item.id)		
		# Now add leftovers to "Ungrouped" tag
		ungrouped.group_list.clear()		
		print(len(processed_collections))
		print(len(filtered_collections))
		var sorted_items = []
		for collection_id in filtered_collections:
			if collection_id in processed_collections: continue
			sorted_items.push_back({"name": asset_library.collection_get_name(collection_id), "id":collection_id})
		if sort_mode == "asc":
			sorted_items.sort_custom(func(a,b): return a.name < b.name)
		elif sort_mode == "desc":
			sorted_items.sort_custom(func(a,b): return a.name > b.name)
		for item in sorted_items:			
			ungrouped.add_item(item.name, item.id)		
	current_group = group

func collection_item_activated(id, group_list:ItemList,create_ur:=true):					
	var collection_id = group_list.get_item_metadata(id)
	if collection_id == -1: return
	var node = add_asset_to_scene(collection_id, group_list.get_item_tooltip(id),create_ur)		
	return node 

func add_asset_to_scene(collection_id, asset_name,create_ur:=true):	
	var node
	if collection_id in asset_library.collections_get_by_type(MAssetTable.ItemType.MESH):
		node = MAssetMesh.new()
		node.collection_id = collection_id		
		var blend_file = AssetIO.get_asset_blend_file(node.collection_id) 
		if blend_file:
			node.set_meta("blend_file", blend_file)
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
		while parent is MAssetMesh and parent != scene_root:
			parent = parent.get_parent()			
	parent.add_child(node)
	node.owner = EditorInterface.get_edited_scene_root()
	node.name = asset_name
	node.global_transform = get_added_node_transform(main_selected_node,current_placement_dir)
	if create_ur:
		ur.create_action("Add Asset",0,EditorInterface.get_edited_scene_root())
		ur.add_do_reference(node)
		#ur.add_undo_reference(node)
		ur.add_do_method(self,"do_asset_add",node,parent,last_added_neighbor)
		ur.add_undo_method(self,"undo_asset_add",node,last_added_masset,last_added_neighbor)
		ur.commit_action(false)
	last_added_neighbor = main_selected_node
	last_added_masset = node
	single_select_node(node)
	#do_add_asset(id,asset_name,parent,EditorInterface.get_edited_scene_root(),main_selected_node,node.transform)
	return node

func do_asset_add(node:Node3D,parent:Node,_last_added_neighbor):
	parent.add_child(node)
	node.owner = EditorInterface.get_edited_scene_root()
	node.visible = true
	last_added_masset = node
	last_added_neighbor = _last_added_neighbor
	single_select_node(node)

func undo_asset_add(node:MAssetMesh,_last_added_masset,_last_added_neighbor):
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
	if not neighbor is MAssetMesh:
		return Transform3D(Basis(),neighbor.global_transform.origin)
	var aabb:AABB= neighbor.get_joined_aabb()
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

func replace_assets() -> void:
	if active_group_list_item==null or active_group_list==null or not active_group_list is ItemList or active_group_list_item < 0:
		return
	var sel_collection_id = active_group_list.get_item_metadata(active_group_list_item)
	var masset_arr:Array
	var masset_ids:PackedInt64Array
	for n in EditorInterface.get_selection().get_selected_nodes():
		if n is MAssetMesh and n.collection_id != sel_collection_id:
			masset_arr.push_back(n)
			masset_ids.push_back(n.collection_id)
	if masset_arr.size() == 0:
		return
	var new_ids:PackedInt64Array
	new_ids.resize(masset_ids.size())
	new_ids.fill(sel_collection_id)
	ur.create_action("replace asset",0,EditorInterface.get_edited_scene_root())
	ur.add_do_method(self,"_replace_asset",new_ids,masset_arr)
	ur.add_undo_method(self,"_replace_asset",masset_ids,masset_arr)
	ur.commit_action()


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

func process_selection(who:ItemList, id, selected):
	current_selection = []
	var all_groups = groups.get_children().map(func(a): return a.group_list)
	all_groups.push_back(ungrouped.group_list)
	for group in all_groups:
		if not Input.is_key_pressed(KEY_SHIFT) and not Input.is_key_pressed(KEY_CTRL) and group != who:
			group.deselect_all()	
		else:
			for item in	group.get_selected_items():
				current_selection.push_back( group.get_item_text(item) )
	selection_changed.emit()
		
func on_main_screen_changed():
	settings_button.button_pressed = false
	
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

func open_settings_window(tab, data):
	if tab == "tag":
		settings_button.button_pressed = true
		settings_button.settings.select_tab("manage_tags")
		settings_button.settings.manage_tags_control.select_collection(data)		
