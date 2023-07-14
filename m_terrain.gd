@tool
extends EditorPlugin

var import_window_res = preload("res://addons/m_terrain/gui/import_window.tscn")
var tools:MTools= null
var paint_panel:MPaintPanel=null
var brush_decal:MBrushDecal=null

var raw_img_importer = null
var raw_tex_importer = null
var active_terrain:MTerrain = null
var last_camera_position:Vector3

func _enter_tree():
	if Engine.is_editor_hint():
		add_tool_menu_item("MTerrain importer", Callable(self,"show_import_window"))
		tools = preload("res://addons/m_terrain/gui/mtools.tscn").instantiate()
		tools.toggle_paint_mode.connect(Callable(self,"toggle_paint_mode"))
		tools.visible = false
		add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU,tools)
		paint_panel = preload("res://addons/m_terrain/gui/paint_panel.tscn").instantiate()
		get_editor_interface().get_selection().selection_changed.connect(Callable(self,"selection_changed"))
		brush_decal = preload("res://addons/m_terrain/gui/brush_decal.tscn").instantiate()
		brush_decal.visible = false
		get_editor_interface().get_editor_main_screen().add_child(brush_decal)

func _exit_tree():
	if Engine.is_editor_hint():
		remove_tool_menu_item("MTerrain importer")
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU,tools)
		remove_control_from_docks(paint_panel)
		brush_decal.queue_free()

func show_import_window():
	var window = import_window_res.instantiate()
	add_child(window)

func _forward_3d_gui_input(viewport_camera, event):
	if tools.active_paint_mode and active_terrain:
		active_terrain.set_editor_camera(viewport_camera)
		active_terrain.set_brush_manager(paint_panel.brush_manager)
		var r = brush_decal.get_brush_size()/2
		active_terrain.update_chunks_loop = false
		active_terrain.update_physics_loop = false
		if last_camera_position.distance_to(viewport_camera.global_position) > 10 and active_terrain.is_finishing_update_chunks():
			active_terrain.update()
		last_camera_position = viewport_camera.global_position
		if event is InputEventMouse and active_terrain.is_finishing_update_chunks():
			var ray:Vector3=viewport_camera.project_ray_normal(event.position)
			var pos:Vector3=viewport_camera.global_position
			var steps = r/100
			var col = active_terrain.get_ray_collision_point(pos,ray,steps,3000)
			if col.is_collided():
				brush_decal.visible = true
				brush_decal.set_position(col.get_collision_position())
				if event.button_mask == MOUSE_BUTTON_LEFT:
					active_terrain.draw_height(col.get_collision_position(),r,paint_panel.brush_id)
					return AFTER_GUI_INPUT_STOP
			else:
				brush_decal.visible = false
		if event is InputEventKey:
			if event.keycode == KEY_EQUAL:
				var size = brush_decal.get_brush_size() + 1
				brush_decal.set_brush_size(size)
				return AFTER_GUI_INPUT_STOP
			if event.keycode == KEY_MINUS:
				var size = brush_decal.get_brush_size() - 1
				brush_decal.set_brush_size(size)
				return AFTER_GUI_INPUT_STOP

func _handles(object):
	if not Engine.is_editor_hint():
		return false
	if object.has_method("create_grid"):
		active_terrain = object
		tools.visible = true
		return true
	tools.visible = false
	return false


func selection_changed():
	var selection := get_editor_interface().get_selection()
	if tools.active_paint_mode:
		selection.clear()
		selection.add_node(active_terrain)

func toggle_paint_mode(input):
	if input:
		add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL,paint_panel)
	else:
		remove_control_from_docks(paint_panel)
