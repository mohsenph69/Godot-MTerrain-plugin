@tool
class_name HLod_Baker extends Node3D
#edit in blender: EditorSettings("filesystem/import/blender/blender_path")
@export_storage var join_at_lod: int = -1
@export var joined_mesh_node: Node3D
		
@export_storage var bake_path = "res://massets/":
	get():
		if not bake_path.ends_with(".res"):
			bake_path = bake_path + name + ".res"
		return bake_path

@export var meshes_to_join: Array[Node3D]
	#set(value):
		#meshes_to_join = value
		#notify_property_list_changed()

@export var hlod_resource: MHlod

var asset_library := MAssetTable.get_singleton()
var lod_levels = AssetIO.LOD_COUNT
var asset_mesh_updater := MAssetMeshUpdater.new()
var timer: Timer

const MAX_LOD = 10

class MeshBakeData:
	var meshes:MMeshLod
	var node:MAssetMesh
	var tr:Transform3D
	var materials:Array # for later

class SubHlodBakeData:
	var sub_hlod: MHlod
	var tr: Transform3D	

class SubBakerBakeData:
	var sub_baker: HLod_Baker
	var tr: Transform3D	
	
func get_all_meshes(baker_node:Node3D,search_nodes:Array)->Array:
	var stack:Array
	stack.append_array(search_nodes)
	var result:Array
	var baker_invers_transform = baker_node.global_transform.inverse()
	while stack.size()!=0:
		var current_node = stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		if (current_node is HLod_Baker and current_node != baker_node) or current_node == joined_mesh_node:
			continue
		if current_node is MAssetMesh:
			if current_node.meshes != null:
				var mdata := MeshBakeData.new()
				mdata.meshes = current_node.meshes
				mdata.node = current_node
				mdata.tr = baker_invers_transform * current_node.global_transform
				result.push_back(mdata)				
		stack.append_array(current_node.get_children())	
	return result

func get_all_sub_hlod(baker_node:Node3D,search_nodes:Array)->Array:
	var stack:Array
	stack.append_array(search_nodes)
	var result:Array
	var baker_invers_transform = baker_node.global_transform.inverse()	
	while stack.size()!=0:
		var current_node = stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)		
		if (current_node is HLod_Baker and current_node != baker_node):
			continue
		if current_node is MHlodScene:
			if current_node.hlod != null:
				var hlod_data := SubHlodBakeData.new()
				hlod_data.sub_hlod = current_node.hlod
				hlod_data.tr = baker_invers_transform * current_node.global_transform
				result.push_back(hlod_data)				
		stack.append_array(current_node.get_children())	
	return result
	
func get_all_sub_bakers(baker_node:Node3D,search_nodes:Array)->Array:
	var stack:Array
	stack.append_array(search_nodes)
	var result:Array
	var baker_invers_transform = baker_node.global_transform.inverse()	
	while stack.size()!=0:
		var current_node = stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)			
		if current_node is HLod_Baker:
			#if current_node != null:
			var baker_data := SubBakerBakeData.new()
			baker_data.sub_baker = current_node
			baker_data.tr = baker_invers_transform * current_node.global_transform
			result.push_back(baker_data)			
			continue	
		stack.append_array(current_node.get_children())	
	return result

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
	var all_meshes_data = get_all_meshes(self, meshes_to_join)			
	var mesh_array = all_meshes_data.map(get_correct_mesh_lod_for_joining)	
	mesh_joiner.insert_mesh_data(mesh_array, all_meshes_data.map(func(a): return a.tr), all_meshes_data.map(func(a): return -1))		
	return mesh_joiner.join_meshes()					

func get_correct_mesh_lod_for_joining(a):
	var lod_to_use = min(join_at_lod, len(a.meshes.meshes)-1)	
	while lod_to_use >-1 and a.meshes.meshes[lod_to_use] == null:
		lod_to_use -= 1
	var mesh = a.meshes.meshes[lod_to_use]
	return null if lod_to_use == -1 or mesh.get_surface_count() == 0 else a.meshes.meshes[lod_to_use]		

func update_joined_mesh_limits():	
	for data in get_all_meshes(self, meshes_to_join):
		var node: MAssetMesh = data.node
		node.lod_limit = join_at_lod
	
func bake_to_hlod_resource():	
	MHlodScene.sleep()	
	var hlod := MHlod.new()
	hlod.set_baker_path(scene_file_path)	
	var all_meshes_data = get_all_meshes(self, get_children())
	
	#################
	## BAKE MESHES ##
	#################
	for item in all_meshes_data:		
		var mesh_array = item.meshes.meshes.map(func(mesh): return MAssetTable.get_singleton().mesh_get_id(mesh))
		var material_array = mesh_array.map(func(a): return -1)
		var shadow_array = mesh_array.map(func(a): return 0)
		var gi_array = mesh_array.map(func(a): return 0)
		var mesh_id = hlod.add_mesh_item(item.tr, mesh_array, material_array, shadow_array, gi_array, 1 )
		if mesh_id == -1:
			push_error("failed to add mesh item to HLod during baking")
		var i = 0			
		while i < join_at_lod:
			hlod.insert_item_in_lod_table(mesh_id, i)
			i += 1
	
	######################
	## BAKE JOINED_MESH ##
	######################
	if is_instance_valid(joined_mesh_node) and joined_mesh_node.meshes != null and len(joined_mesh_node.meshes.meshes) != 0:
		var mesh_array = joined_mesh_node.meshes.meshes.map(func(mesh): return MAssetTable.get_singleton().mesh_get_id(mesh))
		var material_array = mesh_array.map(func(a): return -1)
		var shadow_array = mesh_array.map(func(a): return 0)
		var gi_array = mesh_array.map(func(a): return 0)
		var mesh_id = hlod.add_mesh_item(joined_mesh_node.transform, mesh_array, material_array, shadow_array, gi_array, 1 )		
		if mesh_id != -1:
			for i in range(join_at_lod, MAX_LOD):		
				hlod.insert_item_in_lod_table(mesh_id, i)		
		else:
			push_error()
		
	####################
	## BAKE SUB_BAKER ##
	####################
	var bakers = get_all_sub_bakers(self, [self])
	var all_hlod = []
	for baker_data in bakers:
		baker_data.sub_baker.bake_to_hlod_resource()
		if not is_instance_valid(baker_data.sub_baker.hlod):
			push_error("Baker failed: ", baker_data.sub_baker.name)
			continue
		var sub_hlod_data = SubHlodBakeData.new()
		sub_hlod_data.sub_hlod = baker_data.sub_baker.hlod
		sub_hlod_data.tr = baker_data.tr
		all_hlod.push_back(sub_hlod_data)
				
	###################
	## BAKE SUB_HLOD ##
	###################
	all_hlod.append_array( get_all_sub_hlod(self, [self]) )	
	for hlod_data in all_hlod:
		hlod.add_sub_hlod(hlod_data.tr, hlod_data.sub_hlod)
	
	if FileAccess.file_exists(bake_path):	
		hlod.take_over_path(bake_path)
	else:
		ResourceSaver.save(hlod, bake_path)
	MHlodScene.awake()
	
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
	if not is_instance_valid(timer):
		timer = Timer.new()
		timer.timeout.connect(update_lod)
	add_child(timer)	
	timer.start(1)
	for child in get_children():
		if child is Node3D:
			child.owner = self

func update_lod():	
	asset_mesh_updater.update_auto_lod()		
	
func _exit_tree():	
	if is_instance_valid(timer):
		timer.queue_free()
