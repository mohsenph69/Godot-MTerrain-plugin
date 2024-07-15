extends EditorInspectorPlugin

var gizmo:EditorNode3DGizmoPlugin

var gui_res = preload("res://addons/m_terrain/inspector/gui/mpath_inspector_gui.tscn")
var gui

func _can_handle(object):
	return object is MPath

func _parse_begin(object):
	if not(object is MPath) or not object or not object.curve:
		return
	if not gui:
		gui = gui_res.instantiate()
	add_custom_control(gui)
	gui.gizmo = gizmo
	gui.set_path(object)
