@tool
extends EditorPlugin

var import_window_res = preload("res://addons/m_terrain/gui/import_window.tscn")
var tools:MTools= null
var paint_panel:MPaintPanel=null

var raw_img_importer = null
var raw_tex_importer = null
var active_terrain:MTerrain = null

func _enter_tree():
	add_tool_menu_item("MTerrain importer", Callable(self,"show_import_window"))
	tools = preload("res://addons/m_terrain/gui/mtools.tscn").instantiate()
	tools.toggle_paint_mode.connect(Callable(self,"toggle_paint_mode"))
	tools.visible = false
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU,tools)
	paint_panel = preload("res://addons/m_terrain/gui/paint_panel.tscn").instantiate()
	get_editor_interface().get_selection().selection_changed.connect(Callable(self,"selection_changed"))

func _exit_tree():
	remove_tool_menu_item("MTerrain importer")
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU,tools)
	remove_control_from_docks(paint_panel)

func show_import_window():
	var window = import_window_res.instantiate()
	add_child(window)

func _forward_3d_gui_input(viewport_camera, event):
	var ray_step = 1
	if active_terrain:
		active_terrain.set_editor_camera(viewport_camera)
	if tools.active_paint_mode and event is InputEventMouseMotion:
		var ray:Vector3=viewport_camera.project_ray_normal(event.relative)
		var pos:Vector3=viewport_camera.global_position
		for i in range(0,500):
			pass
		

func _handles(object):
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
