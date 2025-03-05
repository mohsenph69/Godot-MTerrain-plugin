extends EditorNode3DGizmoPlugin

enum {
	FUNC_VALID=0, #string, call this function to check if is valid for gizmo
	HAS_COL=2, #bool -> should have function get_aabb() or get_triangle_mesh()
	HAS_HANDLE=3 #bool -> should have function get_aabb()
}
# if HAS_AABB and HAS_COL but don't have function get_triangle_mesh will be using aabb box as col
var classes_info:= {
	# any non exist func should be empty string
	# at least aabb function is neccassary for this to work
	###############      0     #####    1     ######    2      #########     3   ########
	# class_name : [func_is_valid,HAS_AABB,HAS_COL,HAS_HANDLE],
	"MDecalInstance":["has_decal",true,true,true],
	"MHlodScene":["is_init_scene",true,true,false],
	"MObstacle":["has_gizmo",true,true,false]
}

var handle_ids:PackedInt32Array = [0,1,2,3,4,5]
var handles_dir:Dictionary= {
	# Odd index are negetive
	0:Vector3(1,0,0),
	1:Vector3(-1,0,0),
	2:Vector3(0,1,0),
	3:Vector3(0,-1,0),
	4:Vector3(0,0,1),
	5:Vector3(0,0,-1),
}

var box_mesh:=BoxMesh.new()

var selection:EditorSelection
var sel_line_mat:StandardMaterial3D
var not_sel_line_mat:StandardMaterial3D
var selected_mesh:Array

func _init():
	var ed = EditorScript.new()
	var interface = ed.get_editor_interface()
	selection = interface.get_selection()
	sel_line_mat = StandardMaterial3D.new()
	sel_line_mat.albedo_color = Color(0.2,0.8,0.2)
	sel_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	not_sel_line_mat = sel_line_mat.duplicate()
	not_sel_line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	not_sel_line_mat.albedo_color = Color(0,0,0,0)
	selection.selection_changed.connect(on_selection_change)
	create_handle_material("hmat")

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node = gizmo.get_node_3d()
	var cname = node.get_class()
	var aabb:AABB = node.get_aabb()
	if classes_info[cname][HAS_COL]:
		if node.has_method("get_triangle_mesh"):
			var tmesh = node.get_triangle_mesh()
			gizmo.add_collision_triangles(tmesh)
		else:
			box_mesh.size = aabb.size
			gizmo.add_collision_triangles(box_mesh.generate_triangle_mesh())
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
	if classes_info[cname][HAS_HANDLE]:
		var size:Vector3 = aabb.size/2
		var h:PackedVector3Array
		h.resize(6)
		h.set(0,Vector3(size.x,0,0))
		h.set(1,Vector3(-size.x,0,0))
		h.set(2,Vector3(0,size.y,0))
		h.set(3,Vector3(0,-size.y,0))
		h.set(4,Vector3(0,0,size.z))
		h.set(5,Vector3(0,0,-size.z))
		gizmo.add_handles(h,get_material("hmat"),handle_ids)


func _get_handle_name(gizmo, handle_id, secondary):
	return

func _get_handle_value(gizmo: EditorNode3DGizmo, _id: int, _secondary: bool):
	return

func _set_handle(gizmo, handle_id, secondary, camera, screen_pos):
	var n:Node3D= gizmo.get_node_3d()
	var hdir_sign=1 if handle_id%2==0 else -1
	var hdir_local = handles_dir[handle_id]
	var hdir:Vector3= n.global_basis * hdir_local
	hdir = hdir.normalized()
	var hpos = n.global_position
	var cpos = camera.global_position
	var cdir = camera.project_ray_normal(screen_pos)
	var _b_:float = hdir.dot(cdir)
	var _d_:float = hdir.dot(hpos - cpos)
	var _e_:float = cdir.dot(hpos - cpos)
	var t = (_b_*_e_ - _d_)/(1.0 - _b_*_b_)
	t = max(t,0)
	var hnew_pos:Vector3= (t*hdir).length() * hdir_local
	var old_size = n.get_scale()
	var diff = hnew_pos - (old_size * hdir_local)
	diff /= 2
	var new_size_dir = diff * hdir_sign  + old_size
	n.set_scale(new_size_dir)
	var b = n.global_basis.orthonormalized()
	n.global_position += b * diff
	n.update_gizmos()

func _get_gizmo_name():
	return "AABB_Gizmo"


func _get_priority():
	return -1

func _has_gizmo(for_node_3d):
	var cname:String = for_node_3d.get_class()
	if classes_info.has(cname):
		if classes_info[cname][0].is_empty():
			return true
		else: return for_node_3d.call(classes_info[cname][FUNC_VALID])
	return false

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
		if classes_info.has(n.get_class()) and n.is_inside_tree():
			n.update_gizmos()
			if not selected_mesh.has(n):
				selected_mesh.push_back(n)
