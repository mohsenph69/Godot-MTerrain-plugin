#class_name Asset_Placer
@tool
extends PanelContainer

signal selection_changed

const hlod_baker_script:=preload("res://addons/m_terrain/asset_manager/hlod_baker.gd")

@onready var groups = find_child("groups")
@onready var ungrouped = find_child("other")
@onready var grouping_popup:Popup = find_child("grouping_popup")
@onready var search_collections_node:Control = find_child("search_collections")
@onready var group_by_button:Button = find_child("group_by_button")	
@onready var place_button:Button = find_child("place_button")	
@onready var snap_enabled_button:BaseButton = find_child("snap_enabled_button")
@onready var rotation_enabled_button:BaseButton = find_child("rotation_enabled_button")
@onready var scale_enabled_button:BaseButton = find_child("scale_enabled_button")

@onready var make_baker_btn:Button = $VBoxContainer/HBoxContainer/make_baker_btn

@onready var x_btn:Button = $VBoxContainer/HBoxContainer/x_btn
@onready var y_btn:Button = $VBoxContainer/HBoxContainer/y_btn
@onready var z_btn:Button = $VBoxContainer/HBoxContainer/z_btn

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
var current_group := "None" #group name

var last_regroup = null

var last_added_neighbor = null
var last_added_masset = null
var current_placement_dir:Vector3

func _ready():		
	#if not EditorInterface.get_edited_scene_root() or EditorInterface.get_edited_scene_root() == self or EditorInterface.get_edited_scene_root().is_ancestor_of(self): return
	update_reposition_button_text()
	asset_library.tag_set_name(1, "hidden")
	asset_library.finish_import.connect(func(_arg): 
		regroup()
	)			
	ungrouped.set_group("other")	
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
	
	make_baker_btn.button_down.connect(func():
		var selection = EditorInterface.get_selection().get_selected_nodes()
		if selection.size() != 1:MTool.print_edmsg("Select only one Node3d to be baker")
		else:
			var sel_node = selection[0]
			if sel_node.get_class()!="Node3D": MTool.print_edmsg("Selected node must be Node3D type")
			elif sel_node.get_script()!=null: MTool.print_edmsg("Selected node already has a Gdscript please select a node with no script!!!")
			else:
				sel_node.set_script(hlod_baker_script)
				sel_node._ready()
				sel_node._enter_tree()
		)

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
	var collections_to_exclude = asset_library.tags_get_collections_any(tags_to_excluded) 
	var searched_collections = asset_library.collection_names_begin_with(text) if not text in [null, ""]  else asset_library.collection_get_list()		
	if current_filter_tags and len(current_filter_tags)>0:
		if current_filter_mode_all:		
			result = Array(asset_library.tags_get_collections_all(current_filter_tags))
		else:		
			result = Array(asset_library.tags_get_collections_any(current_filter_tags))	
	else:
		result = Array(searched_collections)		
	for id in result.duplicate():				
		if not id in searched_collections:			
			result.erase(id)		
		if id in collections_to_exclude:
			result.erase(id)			
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
		for tag_id in asset_library.group_get_tags(group):
			if current_filter_tags and len(current_filter_tags) >0:
				if not tag_id in current_filter_tags: 
					continue							
			var tag_name = asset_library.tag_get_name(tag_id)
			if tag_name == "": continue
			var group_control
			var sorted_items = []
			if not groups.has_node(tag_name):				
				group_control = group_control_scene.instantiate()								
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
			for collection_id in asset_library.tag_get_collections_in_collections(filtered_collections, tag_id):
				sorted_items.push_back({"name": asset_library.collection_get_name(collection_id), "id":collection_id})
			if sort_mode == "asc":
				sorted_items.sort_custom(func(a,b): return a.name < b.name)
			elif sort_mode == "desc":
				sorted_items.sort_custom(func(a,b): return a.name > b.name)
			for item in sorted_items:
				group_control.add_item(item.name, item.id)		
		ungrouped.group_list.clear()
		var sorted_items = []
		for id in filtered_collections:
			if not id in asset_library.tags_get_collections_any(asset_library.group_get_tags(group)):
				sorted_items.push_back({"name": asset_library.collection_get_name(id), "id":id})				
		if sort_mode == "asc":
			sorted_items.sort_custom(func(a,b): return a.name < b.name)
		elif sort_mode == "desc":
			sorted_items.sort_custom(func(a,b): return a.name > b.name)
		for item in sorted_items:			
			ungrouped.add_item(item.name, item.id)		
	current_group = group

func collection_item_activated(id, group_list:ItemList,create_ur:=true):					
	var node = add_asset_to_scene(group_list.get_item_metadata(id), group_list.get_item_text(id),create_ur)		
	return node 

func add_asset_to_scene(id, asset_name,create_ur:=true):
	var node = MAssetMesh.new()
	node.collection_id = id		
	var blend_file = AssetIO.get_asset_blend_file(node.collection_id) 
	if blend_file:
		node.set_meta("blend_file", blend_file)
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
