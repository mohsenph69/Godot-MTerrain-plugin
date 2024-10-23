@tool
class_name HLod_Baker extends Node3D

@export_storage var join_at_lod: int = -1
@export var joined_mesh: MMeshLod:
	get():
		if not is_instance_valid(joined_mesh):
			joined_mesh = MMeshLod.new()
			joined_mesh.meshes.resize(AssetIO.LOD_COUNT)
		return joined_mesh
		
@export_storage var bake_path = "res://massets/":
	get():
		if not bake_path.ends_with(".res"):
			bake_path = bake_path + name + ".res"
		return bake_path

@export_storage var joined_mesh_export_path = "res://massets/":
	get():		
		if not joined_mesh_export_path.ends_with(".glb"):
			joined_mesh_export_path = joined_mesh_export_path + name + ".glb"
		return joined_mesh_export_path

@export_storage var export_path = "res://massets/":
	get():		
		if not export_path.ends_with(".glb"):
			export_path = export_path + name + ".glb"
		return export_path

@export var meshes_to_join: Array[Node3D]
@export var hlod_resource: MHlod

var lod_levels = AssetIO.LOD_COUNT
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
		

func make_joined_mesh():
	var mesh_joiner := MMeshJoiner.new()
	var all_mesh_nodes = []
	for child in meshes_to_join:
		all_mesh_nodes.append_array(child.find_children("*", "MAssetMesh", true, false))
	mesh_joiner.insert_mesh_data(all_mesh_nodes.map(func(a:MAssetMesh): return a.meshes.meshes[0]), all_mesh_nodes.map(func(a): return a.global_transform),all_mesh_nodes.map(func(a): return -1))
	return mesh_joiner.join_meshes()					
				
func update_joined_mesh(mesh = make_joined_mesh()):
	joined_mesh.meshes[join_at_lod] = mesh 
	
func bake_to_hlod_resource():	
	var asset_library:MAssetTable = MAssetTable.get_singleton()# load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))		
	var hlod := MHlod.new()
	hlod.set_baker_path(scene_file_path)
	for child:MAssetMesh in find_children("*", "MAssetMesh", true, false):
		if not child.has_meta("mesh_id"): continue
		var mesh_item_info = asset_library.mesh_item_get_info(child.get_meta("mesh_id"))
		var mesh_hash_array = Array(mesh_item_info.mesh).map(func(a): return int(a))		
		var mesh_hash_index = Array(mesh_item_info.mesh_index).map(func(a): return int(a))		
		var arr := Array()
		arr.resize(len(mesh_item_info.mesh))
		arr.fill(0)
		var mesh_id = hlod.add_mesh_item(child.global_transform, mesh_item_info.mesh, mesh_item_info.material, arr, arr, 1 )
		var i = 0
		var max_lod = child.get_meta("max_lod") if child.has_meta("max_lod") else AssetIO.LOD_COUNT
		while i < max_lod:
			hlod.insert_item_in_lod_table(mesh_id, i)
			i += 1
	for child:HLod_Baker in find_children("*", "HLod_Baker", true, false):
		if is_instance_valid(child.hlod_resource):
			hlod.add_sub_hlod(child.transform, child.hlod_resource)
		elif FileAccess.file_exists(bake_path):
			var child_hlod_resource = load(bake_path)
			if child_hlod_resource is MHlod:
				hlod.add_sub_hlod(child.transform, child.hlod_resource)
	for child:MHlodScene in find_children("*", "MHlodScene", true, false):
		if child.hlod is MHlod:
			hlod.add_sub_hlod(child.transform, child.hlod_resource)	
	
	if FileAccess.file_exists(bake_path):	
		hlod.take_over_path(bake_path)
	else:
		ResourceSaver.save(hlod, bake_path)

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
	if is_instance_valid(timer):
		timer.queue_free()
