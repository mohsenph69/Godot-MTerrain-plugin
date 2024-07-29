@tool
extends EditorNode3DGizmoPlugin

signal selection_changed

const value_mode_mouse_sensivity:float = 0.01
const bake_interval:float = 0.2

var handle00_tex = preload("res://addons/m_terrain/icons/handle00.png")
var handle01_tex = preload("res://addons/m_terrain/icons/handle01.png")
var icon_collapse = preload("res://addons/m_terrain/icons/collapse_normal.svg")
var icon_rotation = preload("res://addons/m_terrain/icons/rotation.svg")

var mterrain_plugin:EditorPlugin
var gui:Control

var selection:EditorSelection
var ur:EditorUndoRedoManager
var selected_mesh:Array

#### Only one point can be active
#### Active point does not exist in selected_points
var active_point:int = 0
var selected_points:PackedInt32Array
var selected_connections:PackedInt64Array

enum LOCK_MODE {
	NONE,
	X,
	Y,
	Z,
	XZ,
	XY,
	ZY,
}
var lock_mode := LOCK_MODE.NONE
var is_handle_setting:= true
var is_handle_init_pos_set:=false
var handle_init_id:=0
var handle_init_pos:Vector3


enum VALUE_MODE {
	NONE,
	SCALE,
	TILT
}

var value_mode := VALUE_MODE.NONE

var init_tilt:float
var init_scale:float
var mouse_init_pos:Vector2i
var is_mouse_init_set:=false

var active_path:MPath


func _init():
	var ed = EditorScript.new()
	var interface = ed.get_editor_interface()
	selection = interface.get_selection()
	var line_mat = StandardMaterial3D.new()
	line_mat.albedo_color = Color(0.3,0.3,1.0)
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.render_priority = 10
	line_mat.no_depth_test = true
	var control_line_mat = line_mat.duplicate()
	control_line_mat.albedo_color = Color(0.5,0.8,1.0)
	add_material("line_mat",line_mat)
	var selected_lines_mat = line_mat.duplicate()
	selected_lines_mat.albedo_color = Color(0.2,1.0,0.2)
	add_material("selected_lines_mat",selected_lines_mat)
	add_material("control_line_mat",control_line_mat)
	create_handle_material("points")
	var hmat = get_material("points")
	hmat.albedo_texture = handle00_tex
	hmat.render_priority = 10
	hmat.no_depth_test = true
	hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var controls = hmat.duplicate()
	add_material("controls",controls)
	controls.albedo_texture = handle01_tex
	var active_p_math = get_material("points").duplicate()
	active_p_math.albedo_color = Color(0.9,0.9,0.1)
	active_p_math.render_priority = 100
	active_p_math.no_depth_test = true
	add_material("active_point",active_p_math)
	var selected_points_math = active_p_math.duplicate()
	selected_points_math.albedo_color = Color(1.0,0.2,2)
	add_material("selected_points",selected_points_math)


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node:MPath= gizmo.get_node_3d()
	var curve:MCurve= node.curve
	if not curve:
		return
	var lines:PackedVector3Array
	var selected_lines:PackedVector3Array
	var active_points:PackedInt32Array = curve.get_active_points()
	if active_points.size() == 0:
		return
	var active_connections:PackedInt64Array = curve.get_active_conns()
	for conn in active_connections:
		if selected_connections.has(conn):
			selected_lines.append_array(curve.get_conn_baked_line(conn))
		else:
			lines.append_array(curve.get_conn_baked_line(conn))
	if lines.size() > 2:
		gizmo.add_lines(lines,get_material("line_mat"))
		if gui.is_debug_col():
			gizmo.add_collision_segments(lines)
	if selected_lines.size() > 2:
		gizmo.add_lines(selected_lines,get_material("selected_lines_mat"))
	if not gui or not gui.visible: ## In case is not selected no need for handls
		return
	lines.clear()
	## pointss
	## Main points control point position points_id = point_index
	## point in is secondary=true and points_id = point_index * 2 -> Always even
	## point out is secondary=true and points_id = point_index * 2 + 1 -> Always odd
	var main_points:PackedVector3Array
	var main_ids:PackedInt32Array
	var secondary_pointss:PackedVector3Array
	var secondary_ids:PackedInt32Array
	var active_pos:PackedVector3Array
	var active_id:PackedInt32Array
	var selected_pos:PackedVector3Array
	var selected_ids:PackedInt32Array
	for point in active_points:
		var pos:Vector3 = curve.get_point_position(point)
		var in_pos:Vector3 = curve.get_point_in(point)
		var out_pos:Vector3 = curve.get_point_out(point)
		if point == active_point:
			active_pos.push_back(pos)
			active_id.push_back(point)
		elif selected_points.has(point):
			selected_pos.push_back(pos)
			selected_ids.push_back(point)
		else:
			main_points.push_back(pos)
			main_ids.push_back(point)
		secondary_pointss.push_back(in_pos)
		secondary_ids.push_back(point * 2) 
		secondary_pointss.push_back(out_pos)
		secondary_ids.push_back(point * 2 + 1)
		## points line
		lines.push_back(pos)
		lines.push_back(in_pos)
		lines.push_back(pos)
		lines.push_back(out_pos)
	########## Lock mode line ##################
	if lock_mode == LOCK_MODE.X or lock_mode == LOCK_MODE.XY or lock_mode == LOCK_MODE.XZ:
		lines.push_back(handle_init_pos + Vector3(-100000,0,0))
		lines.push_back(handle_init_pos + Vector3(100000,0,0))
	if  lock_mode == LOCK_MODE.Y or lock_mode == LOCK_MODE.XY or lock_mode == LOCK_MODE.ZY:
		lines.push_back(handle_init_pos + Vector3(0,-100000,0))
		lines.push_back(handle_init_pos + Vector3(0,100000,0))
	if lock_mode == LOCK_MODE.Z or lock_mode == LOCK_MODE.XZ or lock_mode == LOCK_MODE.ZY:
		lines.push_back(handle_init_pos + Vector3(0,0,-100000))
		lines.push_back(handle_init_pos + Vector3(0,0,100000))
	################## Setting lines and handles
	if main_points.size() > 0:
		gizmo.add_handles(main_points,get_material("points",gizmo),main_ids)
	if active_pos.size() > 0:
		gizmo.add_handles(active_pos,get_material("active_point",gizmo),active_id)
	if selected_pos.size() > 0:
		gizmo.add_handles(selected_pos,get_material("selected_points",gizmo),selected_ids)
	if secondary_pointss.size() > 0:
		gizmo.add_handles(secondary_pointss,get_material("controls",gizmo),secondary_ids,false,true)
	if lines.size() > 2:
		gizmo.add_lines(lines,get_material("control_line_mat"))




func _get_handle_name(gizmo, handle_id, secondary):
	if secondary:
		if handle_id%2 == 0:
			return "C "+str(handle_id/2)
		else:
			return "C "+str((handle_id-1)/2)
	return "P "+str(handle_id)

func _is_handle_highlighted(gizmo, handle_id, secondary):
	return false

func _get_handle_value(gizmo, handle_id, secondary):
	var curve:MCurve = gizmo.get_node_3d().curve
	if not curve:
		return null
	if not secondary:
		return curve.get_point_position(handle_id)
	else:
		if handle_id % 2 == 0: #even
			handle_id /=2
			return curve.get_point_in(handle_id)
		else:
			handle_id = (handle_id-1)/2
			return curve.get_point_out(handle_id)

func _set_handle(gizmo, points_id, secondary, camera, screen_pos):
	if Input.is_key_pressed(KEY_CTRL):
		### in multi select mode we do not inturput with this
		return
	var curve:MCurve= gizmo.get_node_3d().curve
	if not curve:
		return
	if not is_handle_init_pos_set:
		is_handle_setting = true
		is_handle_init_pos_set = true
		handle_init_id = points_id
		handle_init_pos = _get_handle_value(gizmo,points_id,secondary)
	var mode = gui.get_mode()
	var from = camera.project_ray_origin(screen_pos)
	var to = camera.project_ray_normal(screen_pos)
	# is main point
	if not secondary:
		var point_pos:Vector3 = curve.get_point_position(points_id)
		var drag:Vector3 = from + to * from.distance_to(point_pos)
		drag = get_constraint_pos(handle_init_pos,drag)
		if gui.is_terrain_snap() and lock_mode == LOCK_MODE.NONE:
			if mterrain_plugin.active_terrain and mterrain_plugin.active_terrain.is_grid_created():
				drag.y = mterrain_plugin.active_terrain.get_height(drag)
			else:
				drag.y = 0.0
		curve.move_point(points_id,drag)
		change_active_point(points_id)
	else: # is secondary
		if gui.is_xz_handle_lock() and lock_mode == LOCK_MODE.NONE:
			lock_mode = LOCK_MODE.XZ
		if points_id % 2 == 0: # is even
			points_id /= 2;
			var in_pos:Vector3 = curve.get_point_in(points_id)
			var drag:Vector3 = from + to * from.distance_to(in_pos)
			drag = get_constraint_pos(handle_init_pos,drag)
			curve.move_point_in(points_id,drag)
			if gui.is_mirror():
				var point_pos = curve.get_point_position(points_id)
				if gui.is_mirror_lenght():
					var out_pos = point_pos + point_pos - drag
					curve.move_point_out(points_id,out_pos)
				else:
					var out_lenght = point_pos.distance_to(curve.get_point_out(points_id))
					var dir = point_pos - drag
					dir = dir.normalized()
					var out_pos = point_pos + dir * out_lenght
					curve.move_point_out(points_id,out_pos)
			change_active_point(points_id)
		else: # is odd
			points_id = (points_id - 1)/2
			var out_pos:Vector3 = curve.get_point_out(points_id)
			var drag:Vector3 = from + to * from.distance_to(out_pos)
			drag = get_constraint_pos(handle_init_pos,drag)
			curve.move_point_out(points_id,drag)
			if gui.is_mirror():
				var point_pos = curve.get_point_position(points_id)
				if gui.is_mirror_lenght():
					var in_pos = point_pos + point_pos - drag
					curve.move_point_in(points_id,in_pos)
				else:
					var in_lenght = point_pos.distance_to(curve.get_point_in(points_id))
					var dir = (point_pos - drag).normalized()
					dir = dir.normalized()
					var in_pos = point_pos +  dir * in_lenght
					curve.move_point_in(points_id,in_pos)
		change_active_point(points_id)

func get_constraint_pos(init_pos:Vector3,current_pos:Vector3):
	match lock_mode:
		LOCK_MODE.NONE:
			return current_pos
		LOCK_MODE.X:
			current_pos.z = init_pos.z
			current_pos.y = init_pos.y
		LOCK_MODE.Y:
			current_pos.x = init_pos.x
			current_pos.z = init_pos.z
		LOCK_MODE.Z:
			current_pos.x = init_pos.x
			current_pos.y = init_pos.y
		LOCK_MODE.XY:
			current_pos.z = init_pos.z
		LOCK_MODE.XZ:
			current_pos.y = init_pos.y
		LOCK_MODE.ZY:
			current_pos.x = init_pos.x
	return current_pos

func _commit_handle(gizmo, handle_id, secondary, restore, cancel):
	var curve:MCurve = gizmo.get_node_3d().curve
	is_handle_init_pos_set = false
	is_handle_setting = false
	lock_mode = LOCK_MODE.NONE
	is_mouse_init_set = false
	if not curve:
		return
	if not ur:
		printerr("curve gizmo undo redo is null")
		return
	if not secondary:
		curve.commit_point_update(handle_id)
		ur.create_action("move_mcurve")
		ur.add_do_method(curve,"move_point",handle_id,curve.get_point_position(handle_id))
		ur.add_do_method(curve,"commit_point_update",handle_id)
		ur.add_undo_method(curve,"move_point",handle_id,restore)
		ur.add_undo_method(curve,"commit_point_update",handle_id)
		ur.commit_action(false)
	else:
		if handle_id % 2 == 0: #even
			handle_id /=2
			curve.commit_point_update(handle_id)
			ur.create_action("move_mcurve_in")
			ur.add_do_method(curve,"move_point_in",handle_id,curve.get_point_in(handle_id))
			ur.add_undo_method(curve,"move_point_in",handle_id,restore)
			if gui.is_mirror():
				var point_pos:Vector3 = curve.get_point_position(handle_id)
				ur.add_do_method(curve,"move_point_out",handle_id,curve.get_point_out(handle_id))
				ur.add_undo_method(curve,"move_point_out",handle_id,point_pos + point_pos - restore)
			ur.add_do_method(curve,"commit_point_update",handle_id)
			ur.add_undo_method(curve,"commit_point_update",handle_id)
			ur.commit_action(false)
		else:
			handle_id = (handle_id-1)/2
			curve.commit_point_update(handle_id)
			ur.create_action("move_mcurve_out")
			ur.add_do_method(curve,"move_point_out",handle_id,curve.get_point_out(handle_id))
			ur.add_undo_method(curve,"move_point_out",handle_id,restore)
			if gui.is_mirror():
				var point_pos:Vector3 = curve.get_point_position(handle_id)
				ur.add_do_method(curve,"move_point_in",handle_id,curve.get_point_in(handle_id))
				ur.add_undo_method(curve,"move_point_in",handle_id,point_pos + point_pos - restore)
			ur.add_do_method(curve,"commit_point_update",handle_id)
			ur.add_undo_method(curve,"commit_point_update",handle_id)
			ur.commit_action(false)
	gizmo.get_node_3d().update_gizmos()

func move_with_commit(curve:MCurve,handle_id:int, secondary:bool,pos:Vector3):
	if not secondary:
		curve.move_point(handle_id,pos)
	else:
		if handle_id % 2 == 0: #even
			handle_id /=2
		else:
			handle_id = (handle_id-1)/2

func _get_gizmo_name():
	return "MPath_Gizmo"

func _get_priority():
	return 2

func _has_gizmo(for_node_3d):
	return for_node_3d.is_class("MPath")

func _forward_3d_gui_input(camera, event, terrain_col:MCollision):
	if event is InputEventMouseButton:
		if event.pressed:
			if value_mode != VALUE_MODE.NONE:
				is_mouse_init_set = false
				var curve = find_curve()
				if not curve or not curve.has_point(active_point):
					value_mode = VALUE_MODE.NONE
					return
				if event.button_index == MOUSE_BUTTON_RIGHT: # Canceling
					curve.set_point_scale(active_point,init_scale)
					curve.set_point_tilt(active_point,init_tilt)
					gui.tilt_num.set_value(init_tilt)
					gui.scale_num.set_value(init_scale)
					value_mode = VALUE_MODE.NONE
					curve.commit_point_update(active_point)
					return EditorPlugin.AFTER_GUI_INPUT_STOP
				if value_mode == VALUE_MODE.TILT:
					ur.create_action("change tilt")
					ur.add_do_method(curve,"set_point_tilt",active_point,curve.get_point_tilt(active_point))
					ur.add_do_method(curve,"commit_point_update",active_point)
					ur.add_do_method(gui.tilt_num,"set_value",curve.get_point_tilt(active_point))
					ur.add_undo_method(gui.tilt_num,"set_value",init_tilt)
					ur.add_undo_method(curve,"set_point_tilt",active_point,init_tilt)
					ur.add_undo_method(curve,"commit_point_update",active_point)
					ur.commit_action(false)
				elif value_mode == VALUE_MODE.SCALE:
					ur.create_action("change scale")
					ur.add_do_method(curve,"set_point_scale",active_point,curve.get_point_scale(active_point))
					ur.add_do_method(gui.scale_num,"set_value",curve.get_point_scale(active_point))
					ur.add_undo_method(gui.scale_num,"set_value",init_scale)
					ur.add_undo_method(curve,"set_point_scale",active_point,init_scale)
					ur.add_undo_method(curve,"commit_point_update",active_point)
					ur.commit_action(false)
				value_mode = VALUE_MODE.NONE
				return EditorPlugin.AFTER_GUI_INPUT_STOP
	if event is InputEventKey:
		if event.pressed:
			if event.keycode == KEY_P:
				print("validating ",selected_connections.size())
				var curve:MCurve = find_curve()
				#for c in selected_connections:
				#	curve.validate_conn(c)
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			if event.keycode == KEY_L:
				var path:MPath = find_mpath()
				if path:
					var curve:MCurve = path.curve
					if curve and curve.has_point(active_point):
						var pp = curve.get_point_conn_points_recursive(active_point)
						selected_points = pp
						pp.push_back(active_point)
						selected_connections = curve.get_conn_ids_exist(pp)
						path.update_gizmos()
						return EditorPlugin.AFTER_GUI_INPUT_STOP
			if event.keycode == KEY_T:
				if Input.is_key_pressed(KEY_SHIFT):
					swap_points()
					return EditorPlugin.AFTER_GUI_INPUT_STOP
				elif toggle_connection():
					return EditorPlugin.AFTER_GUI_INPUT_STOP
			elif  event.keycode == KEY_BACKSPACE:
				if remove_point():
					return EditorPlugin.AFTER_GUI_INPUT_STOP
			elif  event.keycode == KEY_X:
				if disconnect_points():
					return EditorPlugin.AFTER_GUI_INPUT_STOP
			elif  event.keycode == KEY_C:
				if connect_points():
					return EditorPlugin.AFTER_GUI_INPUT_STOP
			if event.keycode == KEY_R:
				var curve = find_curve()
				if curve and curve.has_point(active_point):
					init_tilt = curve.get_point_tilt(active_point)
					value_mode = VALUE_MODE.TILT
					return EditorPlugin.AFTER_GUI_INPUT_STOP
			if event.keycode == KEY_K:
				var curve = find_curve()
				if curve and curve.has_point(active_point):
					init_scale = curve.get_point_scale(active_point)
					value_mode = VALUE_MODE.SCALE
					return EditorPlugin.AFTER_GUI_INPUT_STOP
			if is_handle_setting:
				var path:MPath = find_mpath()
				if Input.is_key_pressed(KEY_SHIFT):
					if event.keycode == KEY_X:
						lock_mode = LOCK_MODE.ZY
						if path: path.update_gizmos()
					if event.keycode == KEY_Y:
						lock_mode = LOCK_MODE.XZ
						if path: path.update_gizmos()
					if event.keycode == KEY_Z:
						lock_mode = LOCK_MODE.XY
						if path: path.update_gizmos()
				else:
					if event.keycode == KEY_X:
						lock_mode = LOCK_MODE.X
						if path: path.update_gizmos()
					if event.keycode == KEY_Y:
						lock_mode = LOCK_MODE.Y
						if path: path.update_gizmos()
					if event.keycode == KEY_Z:
						lock_mode = LOCK_MODE.Z
						if path: path.update_gizmos()
				return EditorPlugin.AFTER_GUI_INPUT_STOP
	if event is InputEventMouseButton:
		if event.button_mask == MOUSE_BUTTON_LEFT and event.pressed:
			var mpath = find_mpath()
			if not mpath:
				return
			var curve:MCurve = mpath.curve
			if not curve:
				return
			#### Handling Selections
			var from = camera.project_ray_origin(event.position)
			var to = camera.project_ray_normal(event.position)
			### Get collission point id
			var pcol = curve.ray_active_point_collision(from,to,0.9999)
			if pcol != 0:
				if Input.is_key_pressed(KEY_CTRL):
					var last:int= selected_points.find(pcol)
					if last != -1:
						selected_points.remove_at(last)
					else:
						selected_points.push_back(pcol)
				else:
					if pcol == active_point and selected_points.size() == 0:
						change_active_point(0)
						return
					else:
						selected_points.clear()
						change_active_point(pcol)
						var last:int= selected_points.find(pcol)
						if last != -1:
							selected_points.remove_at(last)
			if active_point != 0 and  Input.is_key_pressed(KEY_CTRL) and pcol==0: # Maybe a miss selction
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			## selected connections
			selected_connections.clear()
			var all_pp = selected_points.duplicate()
			all_pp.push_back(active_point)
			selected_connections = curve.get_conn_ids_exist(all_pp)
			if pcol: #### if we have selection then we should stop here and not go into creation stuff
				mpath.update_gizmos()
				emit_signal("selection_changed")
				return
			if gui.get_mode() == gui.MODE.CREATE:
				### Here should be adjusted later with MTerrain
				var new_index:int
				var new_pos:Vector3
				var is_new_pos_set = false
				if gui.is_terrain_snap():
					if mterrain_plugin.active_terrain.is_grid_created():
						if terrain_col.is_collided():
							new_pos = terrain_col.get_collision_position()
							is_new_pos_set = true
					else:
						var col = MTool.ray_collision_y_zero_plane(camera.global_position,camera.project_ray_normal(event.position))
						if col.is_collided():
							new_pos = col.get_collision_position()
							is_new_pos_set = true
				if curve.has_point(active_point):
					var creation_distance = curve.get_point_position(active_point).distance_to(from)
					if not is_new_pos_set:
						new_pos = from + to * creation_distance
					new_index = curve.add_point(new_pos,new_pos,new_pos,active_point)
				else:
					if not is_new_pos_set:
						new_pos = from + to * 4.0
					new_index = curve.add_point(new_pos,new_pos,new_pos,0)
				if new_index == 0: ### In case for error
					return EditorPlugin.AFTER_GUI_INPUT_STOP
				## Undo Redo
				ur.create_action("create_point")
				ur.add_do_method(curve,"add_point",new_pos,new_pos,new_pos,active_point)
				ur.add_undo_method(curve,"remove_point",new_index)
				ur.commit_action(false)
				change_active_point(new_index)
				mpath.update_gizmos()
				return EditorPlugin.AFTER_GUI_INPUT_STOP
	if event is InputEventMouseMotion:
		if value_mode == VALUE_MODE.NONE: return
		var curve = find_curve()
		if not curve: return
		if not curve.has_point(active_point): return
		if not is_mouse_init_set:
			mouse_init_pos = event.position
			init_scale = curve.get_point_scale(active_point)
			init_tilt = curve.get_point_tilt(active_point)
			is_mouse_init_set = true
		var mouse_diff:float = mouse_init_pos.y - event.position.y
		mouse_diff *= value_mode_mouse_sensivity
		if value_mode == VALUE_MODE.TILT:
			var new_tilt:= init_tilt + mouse_diff
			curve.set_point_tilt(active_point,new_tilt)
			gui.tilt_num.set_value(new_tilt)
		elif  value_mode == VALUE_MODE.SCALE:
			var new_scale:= init_scale + mouse_diff
			curve.set_point_scale(active_point,new_scale)
			gui.scale_num.set_value(new_scale)
		curve.commit_point_update(active_point)
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	if event is InputEventMouseButton:
		if event.button_mask == MOUSE_BUTTON_LEFT and gui.is_select_lock():
			return EditorPlugin.AFTER_GUI_INPUT_STOP


func find_mpath()->MPath:
	if active_path:
		return active_path
	var snodes = selection.get_selected_nodes()
	for n in snodes:
		if n is MPath:
			active_path = n
			return n
	return null

func find_curve()->MCurve:
	var node = find_mpath()
	if not node: return null
	var curve:MCurve = node.curve
	return curve

func on_collapse():
	var node = find_mpath()
	if not node:
		return
	var curve:MCurve = node.curve
	if not curve:
		return
	if not curve.has_point(active_point):
		return
	var p_pos = curve.get_point_position(active_point)
	var in_pos = curve.get_point_in(active_point)
	var out_pos = curve.get_point_out(active_point)
	curve.commit_point_update(active_point)
	ur.create_action("collapse point")
	ur.add_do_method(curve,"move_point_in",active_point,p_pos)
	ur.add_do_method(curve,"move_point_out",active_point,p_pos)
	ur.add_undo_method(curve,"move_point_in",active_point,in_pos)
	ur.add_undo_method(curve,"move_point_out",active_point,out_pos)
	ur.commit_action(true)


func set_gui(input:Control):
	gui = input
	gui.connect("visibility_changed",Callable(self,"gui_visibility_changed"))
	gui.toggle_connection_btn.connect("pressed",Callable(self,"toggle_connection"))
	gui.collapse_btn.connect("pressed",Callable(self,"on_collapse"))
	gui.connect_btn.connect("pressed",Callable(self,"connect_points"))
	gui.disconnect_btn.connect("pressed",Callable(self,"disconnect_points"))
	gui.remove_btn.connect("pressed",Callable(self,"remove_point"))
	gui.swap_points_btn.connect("pressed",Callable(self,"swap_points"))
	gui.depth_test_checkbox.connect("toggled",Callable(self,"toggle_depth_test"))
	gui.tilt_num.connect("prop_changed",Callable(self,"on_point_val_changed"))
	gui.scale_num.connect("prop_changed",Callable(self,"on_point_val_changed"))
	gui.tilt_num.connect("commit_value",Callable(self,"on_point_val_commit"))
	gui.scale_num.connect("commit_value",Callable(self,"on_point_val_commit"))
	gui.tilt_num.set_editable(false)
	gui.scale_num.set_editable(false)
	gui.tilt_num.set_soft_min(-1)
	gui.tilt_num.set_soft_max(1)
	gui.scale_num.set_soft_min(-4)
	gui.scale_num.set_soft_max(4)
	gui.sort_increasing_btn.connect("pressed",Callable(self,"sort").bind(true))
	gui.sort_decreasing_btn.connect("pressed",Callable(self,"sort").bind(false))

func change_active_point(new_active_point:int):
	active_point = new_active_point
	var curve = find_curve()
	if not curve or not curve.has_point(active_point):
		gui.tilt_num.set_editable(false)
		gui.scale_num.set_editable(false)
		return
	gui.tilt_num.set_editable(true)
	gui.scale_num.set_editable(true)
	gui.tilt_num.set_value_no_signal(curve.get_point_tilt(active_point)*2*PI)
	gui.scale_num.set_value_no_signal(curve.get_point_scale(active_point))



func toggle_connection()->bool:
	var path = find_mpath()
	if not path: return false
	var curve:MCurve = path.curve
	if not curve: return false
	if not curve.has_point(active_point): return false
	ur.create_action("toggle connection")
	ur.add_do_method(self,"_toggle_connection",curve,active_point,selected_connections)
	ur.add_undo_method(self,"_toggle_connection",curve,active_point,selected_connections)
	ur.commit_action(true)
	return true

func connect_points()->bool:
	var path = find_mpath()
	if not path: return false
	var curve:MCurve = path.curve
	if not curve: return false
	if not curve.has_point(active_point): return false
	if selected_points.size() == 0: return false
	if selected_points.size() > 1:
		push_error("More than two points is selected")
		return false
	var other_point:int = selected_points[0]
	var res:bool = curve.connect_points(active_point,other_point,MCurve.CONN_NONE)
	if res:
		ur.create_action("disconnect points")
		ur.add_do_method(curve,"connect_points",active_point,other_point,MCurve.CONN_NONE)
		ur.add_undo_method(curve,"disconnect_points",active_point,other_point)
		ur.commit_action(false)
		path.update_gizmos()
		return true
	return false


func disconnect_points():
	var path = find_mpath()
	if not path: return false
	var curve:MCurve = path.curve
	if not curve: return false
	if not curve.has_point(active_point): return false
	if selected_points.size() == 0: return false
	if selected_points.size() > 1:
		push_error("More than two points is selected")
		return false
	var other_point:int = selected_points[0]
	var conn_type = curve.get_conn_type(curve.get_conn_id(active_point,other_point))
	var res:bool = curve.disconnect_points(active_point,other_point)
	if res:
		ur.create_action("connect points")
		ur.add_do_method(curve,"disconnect_points",active_point,other_point)
		ur.add_undo_method(curve,"connect_points",active_point,other_point,conn_type)
		ur.commit_action(false)
		path.update_gizmos()
		return true
	return false

func _toggle_connection(curve:MCurve,toggle_point,toggle_conn):
	for conn in selected_connections:
		curve.toggle_conn_type(active_point,conn)
	if curve.has_point(active_point):
		curve.commit_point_update(active_point)
	return true

func remove_point()->bool:
	var path = find_mpath()
	if not path: return false
	var curve:MCurve = path.curve
	if not curve: return false
	if not curve.has_point(active_point): return false
	var p_pos = curve.get_point_position(active_point)
	var p_in = curve.get_point_in(active_point)
	var p_out = curve.get_point_out(active_point)
	var conn_points = curve.get_point_conn_points(active_point)
	var conn_types = curve.get_point_conn_types(active_point)
	ur.create_action("Remove Point")
	ur.add_do_method(curve,"remove_point",active_point)
	#curve.add_point_conn_point(p_pos,p_in,p_out,conn_types,conn_points)
	ur.add_undo_method(curve,"add_point_conn_point",p_pos,p_in,p_out,conn_types,conn_points)
	ur.commit_action(true)
	return true

func swap_points():
	var curve:MCurve = find_curve()
	if not curve: return
	if not curve.has_point(active_point): return
	if selected_points.size() != 1:
		printerr("For swaping point you should select only two points")
		return
	curve.swap_points_with_validation(active_point,selected_points[0])
	ur.create_action("swap_points")
	ur.add_do_method(curve,"swap_points_with_validation",active_point,selected_points[0])
	ur.add_undo_method(curve,"swap_points_with_validation",active_point,selected_points[0])
	ur.commit_action(false)

func gui_visibility_changed():
	if not gui.visible:
		change_active_point(0)
		selected_connections.clear()
		selected_points.clear()
		if active_path:
			active_path.update_gizmos()
		active_path = null

func on_tilt_changed(value:float):
	var path = find_mpath()
	if not path: return false
	var curve:MCurve = path.curve
	if not curve: return false
	if not curve.has_point(active_point): return false
	curve.set_point_tilt(active_point,value)
	path.update_gizmos()

func on_point_val_changed(prop_name,val):
	var path = find_mpath()
	if not path: return false
	var curve:MCurve = path.curve
	if not curve: return false
	if not curve.has_point(active_point): return false
	if prop_name == "tilt":
		curve.set_point_tilt(active_point,val*2*PI)
	elif prop_name == "scale":
		curve.set_point_scale(active_point,val)
	path.update_gizmos()

func on_point_val_commit(prop_name,old_val,new_val):
	var curve = find_curve()
	if not curve or not curve.has_point(active_point): return
	if prop_name == "tilt":
		ur.create_action("change tilt")
		ur.add_undo_method(curve,"set_point_tilt",active_point,old_val)
		ur.add_do_method(curve,"set_point_tilt",active_point,new_val)
		ur.add_undo_method(gui.tilt_num,"set_value",old_val)
		ur.add_do_method(gui.tilt_num,"set_value",new_val)
		ur.add_do_method(curve,"commit_point_update",active_point)
		ur.add_undo_method(curve,"commit_point_update",active_point)
		ur.commit_action(false)
	elif prop_name == "scale":
		ur.create_action("change scale")
		ur.add_undo_method(curve,"set_point_scale",active_point,old_val)
		ur.add_do_method(curve,"set_point_scale",active_point,new_val)
		ur.add_undo_method(gui.scale_num,"set_value",old_val)
		ur.add_do_method(gui.scale_num,"set_value",new_val)
		ur.add_do_method(curve,"commit_point_update",active_point)
		ur.add_undo_method(curve,"commit_point_update",active_point)
		ur.commit_action(false)
	curve.commit_point_update(active_point)

func toggle_depth_test(input:bool):
	get_material("line_mat").no_depth_test = not input
	get_material("selected_lines_mat").no_depth_test = not input

func get_selected_connections()->PackedInt64Array:
	return selected_connections

func get_selected_points64()->PackedInt64Array:
	var out:PackedInt64Array
	if active_point != 0: out.push_back(active_point)
	for p in selected_points:
		out.push_back(p)
	return out

func get_selected_points32()->PackedInt32Array:
	var out:PackedInt32Array
	if active_point != 0: out.push_back(active_point)
	out.append_array(selected_points)
	return out

func sort(increasing:bool):
	var path = find_mpath()
	if not path or not path.curve: return
	var curve = path.curve
	active_point = curve.sort_from(active_point,increasing)
	var cuid = ur.get_object_history_id(curve)
	var suid = ur.get_object_history_id(self)
	var cu = ur.get_history_undo_redo(cuid)
	var su = ur.get_history_undo_redo(suid)
	cu.clear_history()
	su.clear_history()
	path.update_gizmos()




