@tool
extends EditorPlugin

var import_window_res = preload("res://addons/m_terrain/gui/import_window.tscn")


var raw_img_importer = null
var raw_tex_importer = null
var active_terrain:MTerrain = null

func _enter_tree():
	add_tool_menu_item("MTerrain importer", Callable(self,"show_import_window"))
	
func _exit_tree():
	remove_tool_menu_item("MTerrain importer")


func show_import_window():
	var window = import_window_res.instantiate()
	add_child(window)

func _forward_3d_gui_input(viewport_camera, event):
	if active_terrain:
		active_terrain.set_editor_camera(viewport_camera)

func _handles(object):
	if object == active_terrain:
		return true
	if object.has_method("create_grid"):
		active_terrain = object
		return true
	return false
