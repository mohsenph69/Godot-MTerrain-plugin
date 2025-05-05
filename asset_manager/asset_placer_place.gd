@tool
extends HBoxContainer

@onready var place_button:Button = find_child("place_button")	

@onready var snap_enabled_button:BaseButton = find_child("snap_enabled_button")
@onready var rotation_enabled_button:BaseButton = find_child("rotation_enabled_button")
@onready var scale_enabled_button:BaseButton = find_child("scale_enabled_button")

@onready var o_btn:Button = find_child("o_btn")
@onready var x_btn:Button = find_child("x_btn")
@onready var y_btn:Button = find_child("y_btn")
@onready var z_btn:Button = find_child("z_btn")

@onready var replace_btn:Button = find_child("replace_btn")

var asset_library := MAssetTable.get_singleton()
var assets_tree

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

var last_added_neighbor = null
var last_added_masset = null
var current_placement_dir:Vector3


func _ready():		
	ur = EditorInterface.get_editor_undo_redo()
	update_reposition_button_text()	
	place_button.toggled.connect(toggle_place_with_confirmation)
	replace_btn.pressed.connect(replace_btn_pressed)
	o_btn.pressed.connect(reposition_origin)
	x_btn.pressed.connect(reposition_x)
	y_btn.pressed.connect(reposition_y)
	z_btn.pressed.connect(reposition_z)
	

func validate_place_button(_mouse_pos, _button):		
	var item = assets_tree.get_selected()
	if not item:
		place_button.disabled = true
		return
	var column = assets_tree.get_selected_column()		
	var collection_id = item.get_metadata(column)
	place_button.disabled = collection_id < 0

func toggle_place_with_confirmation(toggle_on):
	if not EditorInterface.get_edited_scene_root(): return
	if toggle_on:
		if not EditorInterface.get_edited_scene_root() is HLod_Baker and get_current_collection_type()!=MAssetTable.ItemType.HLOD:		
			var confirm := ConfirmationDialog.new()
			confirm.confirmed.connect(toggle_place.bind(true))
			confirm.dialog_text = "The current scene is not a baker and not a MHlodNode3D. Are you sure you want to add asset?"
			confirm.dialog_close_on_escape = true
			add_child(confirm)
			confirm.popup_centered()
			confirm.canceled.connect(func():
				place_button.button_pressed = false
			)
		else:
			toggle_place(toggle_on)
	
func toggle_place(toggle_on):				
	if toggle_on:									
		object_being_placed = add_asset_to_scene_from_assets_tree_selection()
		if not object_being_placed: 
			return
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

##################
## PLACE ASSETS ##
##################
func get_current_collection_id()->int:
	var item = assets_tree.get_selected()
	if not item: return -1
	var column = assets_tree.get_selected_column()
	return item.get_metadata(column)

func get_current_collection_type()->MAssetTable.ItemType:
	var cid:int = get_current_collection_id()
	if cid==-1 : return MAssetTable.ItemType.NONE
	return MAssetTable.get_singleton().collection_get_type(cid)

func add_asset_to_scene_from_assets_tree_selection_with_confirmation():
	if not EditorInterface.get_edited_scene_root(): return	
	if not EditorInterface.get_edited_scene_root() is HLod_Baker and get_current_collection_type()!=MAssetTable.ItemType.HLOD:
		var confirm := ConfirmationDialog.new()
		confirm.confirmed.connect(add_asset_to_scene_from_assets_tree_selection)
		confirm.dialog_text = "The current scene is not a baker and not a MHlodNode3D. Are you sure you want to add asset?"
		confirm.dialog_close_on_escape = true
		add_child(confirm)
		confirm.popup_centered()			
	else:
		add_asset_to_scene_from_assets_tree_selection()

func add_asset_to_scene_from_assets_tree_selection()->Node:
	var collection_id = get_current_collection_id()
	if collection_id < 0 : return null
	var collection_name = MAssetTable.get_singleton().collection_get_name(collection_id)
	return add_asset_to_scene(collection_id, collection_name)
	
func add_asset_to_scene(collection_id, asset_name,create_ur:=true)->Node:
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

func _replace_asset(collection_ids:PackedInt32Array,masset_node:Array,type:MAssetTable.ItemType) -> void:
	var at:MAssetTable = MAssetTable.get_singleton()
	if collection_ids.size() != masset_node.size():
		printerr("mismatch new_asset old asset count")
		return
	match type:
		MAssetTable.ItemType.MESH:
			for i in range(collection_ids.size()):
				masset_node[i].collection_id = collection_ids[i]
		MAssetTable.ItemType.DECAL:
			for i in range(collection_ids.size()):
				var cid = collection_ids[i]
				var mdecal:MDecal
				if cid!=-1:
					var item_id = at.collection_get_item_id(cid)
					mdecal=load(MHlod.get_decal_path(item_id))
				masset_node[i].decal = mdecal
		MAssetTable.ItemType.HLOD:
			for i in range(collection_ids.size()):
				var cid = collection_ids[i]
				var hlod:MHlod
				if cid!=-1:
					var item_id = at.collection_get_item_id(cid)
					hlod=load(MHlod.get_hlod_path(item_id))
				masset_node[i].hlod = hlod

func replace_btn_pressed()->void:
	var cid = get_current_collection_id()
	if cid == -1 : return
	var at:MAssetTable = MAssetTable.get_singleton()
	var old_collection_ids:PackedInt32Array
	var type = MAssetTable.get_singleton().collection_get_type(cid)
	var sels = EditorInterface.get_selection().get_selected_nodes()
	match type:
		MAssetTable.ItemType.MESH:
			sels=sels.filter(func(a):return a is MAssetMesh)
			for n:MAssetMesh in sels:
				old_collection_ids.push_back(n.collection_id)
		MAssetTable.ItemType.DECAL:
			sels=sels.filter(func(a):return a is MDecalInstance)
			for n:MDecalInstance in sels:
				if n.decal==null:
					old_collection_ids.push_back(-1) # invalid ID
				else:
					var item_id=int(n.decal.resource_path)
					var n_cid = at.collection_find_with_item_type_item_id(MAssetTable.DECAL,item_id)
					old_collection_ids.push_back(n_cid)
		MAssetTable.ItemType.HLOD:
			sels=sels.filter(func(a):return a is MHlodScene)
			for n:MHlodScene in sels:
				if n.hlod==null:
					old_collection_ids.push_back(-1)
				else:
					var item_id=int(n.hlod.resource_path)
					var n_cid = at.collection_find_with_item_type_item_id(MAssetTable.HLOD,item_id)
					old_collection_ids.push_back(n_cid)
	#################
	if old_collection_ids.size() != sels.size():
		printerr("Mismatch size old_collection_ids with sels nodes!")
		return
	var new_collection_ids:PackedInt32Array
	new_collection_ids.resize(old_collection_ids.size())
	new_collection_ids.fill(cid)
	ur.create_action("replace_assets")
	ur.add_do_method(self,"_replace_asset",new_collection_ids,sels,type)
	ur.add_undo_method(self,"_replace_asset",old_collection_ids,sels,type)
	ur.commit_action(true)

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
							
