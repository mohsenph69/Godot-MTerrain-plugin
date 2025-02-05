extends EditorNode3DGizmoPlugin


var accepeted_class:PackedStringArray=["MDecalInstance"]
var aabb_call_back:PackedStringArray =["get_aabb"]
var mesh_call_back:PackedStringArray =[""]

var box_mesh:=BoxMesh.new()

var selection:EditorSelection
var sel_line_mat:StandardMaterial3D
var selected_mesh:Array

func _init():
	var ed = EditorScript.new()
	var interface = ed.get_editor_interface()
	selection = interface.get_selection()
	sel_line_mat = StandardMaterial3D.new()
	sel_line_mat.albedo_color = Color(0.2,0.8,0.2)
	sel_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selection.selection_changed.connect(on_selection_change)

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node = gizmo.get_node_3d()
	var node_class_index = accepeted_class.find(node.get_class())
	var aabb:AABB= node.call(aabb_call_back[node_class_index])
	box_mesh.size = aabb.size
	gizmo.add_collision_triangles(box_mesh.generate_triangle_mesh())
	if selection.get_selected_nodes().has(node):
		aabb.position -= Vector3(0.02,0.02,0.02)
		aabb.size += Vector3(0.04,0.04,0.04)
		var s = aabb.position
		var e = aabb.size + s
		var l:PackedVector3Array
		l.resize(24)
		l[0] = s
		l[1] = Vector3(e.x,s.y,s.z)
		l[2] = s
		l[3] = Vector3(s.x,e.y,s.z)
		l[4] = s
		l[5] = Vector3(s.x,s.y,e.z)
		l[6] = e
		l[7] = Vector3(e.x,s.y,e.z)
		l[8] = e
		l[9] = Vector3(s.x,e.y,e.z)
		l[10] = e
		l[11] = Vector3(e.x,e.y,s.z)
		l[12] = Vector3(e.x,e.y,s.z)
		l[13] = Vector3(e.x,s.y,s.z)
		l[14] = Vector3(e.x,s.y,s.z)
		l[15] = Vector3(e.x,s.y,e.z)
		l[16] = Vector3(s.x,s.y,e.z)
		l[17] = Vector3(s.x,e.y,e.z)
		l[18] = Vector3(s.x,e.y,e.z)
		l[19] = Vector3(s.x,e.y,s.z)
		l[20] = Vector3(s.x,e.y,s.z)
		l[21] = Vector3(e.x,e.y,s.z)
		l[22] = Vector3(e.x,s.y,e.z)
		l[23] = Vector3(s.x,s.y,e.z)
		gizmo.add_lines(l,sel_line_mat,false)


func _get_handle_name(gizmo, handle_id, secondary):
	return

func _get_handle_value(gizmo: EditorNode3DGizmo, _id: int, _secondary: bool):
	return

func _set_handle(gizmo, handle_id, secondary, camera, screen_pos):
	return

func _get_gizmo_name():
	return "AABB_Gizmo"


func _get_priority():
	return -1

func _has_gizmo(for_node_3d):
	return accepeted_class.find(for_node_3d.get_class()) != -1;

func on_selection_change():
	var snodes = selection.get_selected_nodes()
	var i = selected_mesh.size() - 1
	while i >= 0:
		var find = snodes.find(selected_mesh[i])
		if find == -1:
			if is_instance_valid(selected_mesh[i]):
				selected_mesh[i].update_gizmos()
			selected_mesh.remove_at(i)
		i-=1
	for n in snodes:
		if accepeted_class.find(n.get_class())!=-1 and n.is_inside_tree():
			n.update_gizmos()
			if not selected_mesh.has(n):
				selected_mesh.push_back(n)
