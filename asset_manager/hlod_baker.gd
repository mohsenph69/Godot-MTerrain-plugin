@tool
class_name HLod_Baker extends Node3D

var lod_levels = AssetIO.LOD_COUNT
@export var max_lod = -1
@export var bake_path = "res://"
@export var meshes_to_join: Array[Node3D]
var asset_mesh_updater := MAssetMeshUpdater.new()
var timer: Timer

func _notification(what):	
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		for child in get_children():
			if child.has_meta("collection_id"):
				for grandchild in child.get_children():
					grandchild.owner = null
					

func _ready():	
	asset_mesh_updater.update_auto_lod()
	for child in get_children():
		if child.has_meta("hlod"):
			for node in child.find_children("*"):
				node.owner = child
		elif child.has_meta("collection_id"):
			var original_transform = child.transform
			var node = AssetIO.reload_collection(child, child.get_meta("collection_id"))
			if is_instance_valid(node):
				node.transform = original_transform
		

func make_joined_mesh(glb=true, res=false):
	var mesh_joiner := MMeshJoiner.new()
	var all_mesh_nodes = []
	for child in meshes_to_join:
		all_mesh_nodes.append_array(child.find_children("*", "MAssetMesh", true, false))
	mesh_joiner.insert_mesh_data(all_mesh_nodes.map(func(a:MAssetMesh): return a.meshes.meshes[0]), all_mesh_nodes.map(func(a): return a.global_transform),all_mesh_nodes.map(func(a): return -1))
	var new_mesh = mesh_joiner.join_meshes()
	if res:
		ResourceSaver.save(new_mesh, str("res://masset/meshes/", AssetIO.hash_mesh(new_mesh), ".res"))
	if glb:
		var mesh_node = MeshInstance3D.new()
		mesh_node.mesh = new_mesh	
		AssetIO.glb_export(mesh_node, "res://addons/m_terrain/asset_manager/example_asset_library/export/" + name + "_merged.glb")
				
func bake_to_hlod_resource():	
	var asset_library:MAssetTable = load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))		
	var hlod := MHlod.new()
	for child:MAssetMesh in find_children("*", "MAssetMesh", true, false):
		if not child.has_meta("mesh_id"): continue
		var mesh_array = Array(asset_library.mesh_item_get_info(child.get_meta("mesh_id")).mesh).map(func(a): return int(a))
		var mesh_id = hlod.add_mesh_item(child.global_transform, mesh_array, mesh_array.map(func(a): return 0), mesh_array.map(func(a): return -1), mesh_array.map(func(a): return 0), mesh_array.map(func(a): return 0), 1 )
		var i = 0
		var max_lod = child.get_meta("max_lod") if child.has_meta("max_lod") else AssetIO.LOD_COUNT
		while i < max_lod:
			hlod.insert_item_in_lod_table(mesh_id, i)
			i += 1
	#hlod.set_baker_path(bake_path)
	ResourceSaver.save(hlod, bake_path) #hlod.get_baker_path())
	return
	#hlod.get_baker_path()
	var hlod_resource = Resource.new()
	
	var static_bodies = []
	for child in get_children():
		if child.scene_file_path != "":
			for i in lod_levels:
				if i <= child.get_meta("max_lod"):
					hlod_resource.add_packed_scene_item(child)			
		elif child is MeshInstance3D:
			for i in lod_levels:
				hlod_resource.add_mesh_item(child.get_meta(str("mesh_lod_",i)), child.get_meta(str("material_lod_",i)))
		elif child is CollisionShape3D:
			for i in lod_levels:
				if child.get_meta(str("lod_",i)):
					hlod_resource.add_collision_item(child, find_matching_static_body(static_bodies, child.get_parent()))	
		elif child is StaticBody3D:			
			var exists = false
			for body: StaticBody3D in static_bodies:				
				if compare_static_bodies(body, child):
					exists = true
					break
			if not exists:
				static_bodies.push_back(child)
				hlod_resource.add_collision_item()			
	ResourceSaver.save(hlod_resource, bake_path)

func find_matching_static_body(arr, body):
	for sb in arr:
		if compare_static_bodies(sb,body):
			return sb
	push_error("trying to pack collision shape that is not a child of static body")

func compare_static_bodies(a:StaticBody3D,b):
	if a.physics_material_override != b.physics_material_override:				
		return false
	if a.collision_layer != b.collision_layer:
		return false
	if a.collision_mask != b.collision_mask:
		return false
	return true


		
func _enter_tree():
	asset_mesh_updater = MAssetMeshUpdater.new()	
	asset_mesh_updater.set_root_node(self)
	timer = Timer.new()
	add_child(timer)
	timer.timeout.connect(update_lod)
	timer.start(1)
	for child in get_children():
		if child is Node3D:
			child.owner = self

func update_lod():	
	asset_mesh_updater.update_auto_lod()		
	
func _exit_tree():
	timer.queue_free()
