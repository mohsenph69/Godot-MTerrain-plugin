@tool
class_name HLod_Baker extends Node3D

signal asset_mesh_updated

@export_storage var join_at_lod: int = -1
@export_storage var joined_mesh_node: Node3D
@export_storage var joined_mesh_disabled := false
@export_storage var hlod_resource: MHlod
@export_storage var bake_path = "res://massets/": get = get_bake_path
@export_storage var meshes_to_join_overrides := {}
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

func bake_to_hlod_resource():	
	MHlodScene.sleep()	
	hlod_resource = MHlod.new()
	hlod_resource.set_baker_path(scene_file_path)		
	#################
	## BAKE MESHES ##
	#################
	var all_meshes_data = get_all_meshes(self, get_children())		
	for item in all_meshes_data:		
		var mesh_array = item.meshes.meshes.map(func(mesh): return MAssetTable.get_singleton().mesh_get_id(mesh) if mesh is Mesh else -1)
		var material_array = mesh_array.map(func(a): return -1)
		var shadow_array = mesh_array.map(func(a): return 0)
		var gi_array = mesh_array.map(func(a): return 0)
		var mesh_id = hlod_resource.add_mesh_item(item.tr, mesh_array, material_array, shadow_array, gi_array, 1 )
		if mesh_id == -1:
			push_error("failed to add mesh item to HLod during baking")
		var i = -1
		var max = join_at_lod if join_at_lod >= 0 else MAX_LOD		
		while i < max:
			i += 1
			if mesh_array[min(i, len(mesh_array)-1) ] != -1:
				hlod_resource.insert_item_in_lod_table(mesh_id, i)
					
	######################
	## BAKE JOINED_MESH ##
	######################
	if join_at_lod >= 0 and is_instance_valid(joined_mesh_node) and joined_mesh_node.meshes != null and len(joined_mesh_node.meshes.meshes) != 0:
		var mesh_array = joined_mesh_node.meshes.meshes.map(func(mesh): return MAssetTable.get_singleton().mesh_get_id(mesh))
		var material_array = mesh_array.map(func(a): return -1)
		var shadow_array = mesh_array.map(func(a): return 0)
		var gi_array = mesh_array.map(func(a): return 0)		
		var mesh_id = hlod_resource.add_mesh_item(joined_mesh_node.transform, mesh_array, material_array, shadow_array, gi_array, 1 )		
		if mesh_id != -1:
			for i in range(join_at_lod, MAX_LOD):		
				hlod_resource.insert_item_in_lod_table(mesh_id, i)		
		else:
			push_error("Hlod baker error: cannot add joined mesh to hlod table because mesh_id is -1")
		
	####################
	## BAKE SUB_BAKER ##
	####################	
	var bakers = get_all_sub_bakers(self, get_children())	
	var all_hlod = []
	for baker_data in bakers:
		baker_data.sub_baker.bake_to_hlod_resource()
		if not is_instance_valid(baker_data.sub_baker.hlod_resource):
			push_error("Baker failed: ", baker_data.sub_baker.name, " ; ",baker_data.sub_baker.hlod_resource)
			continue
		var sub_hlod_data = SubHlodBakeData.new()
		sub_hlod_data.sub_hlod = baker_data.sub_baker.hlod_resource
		sub_hlod_data.tr = baker_data.tr
		all_hlod.push_back(sub_hlod_data)		
	###################
	## BAKE SUB_HLOD ##
	###################
	all_hlod.append_array( get_all_sub_hlod(self, get_children()) )	
	for hlod_data in all_hlod:
		hlod_resource.add_sub_hlod(hlod_data.tr, hlod_data.sub_hlod)
		#hlod.lod_limit = join_at_lod
		
	if FileAccess.file_exists(bake_path):	
		hlod_resource.take_over_path(bake_path)
	else:
		ResourceSaver.save(hlod_resource, bake_path)
	MHlodScene.awake()	
	hlod_resource
	return

#region Getters	
func get_all_meshes(baker_node:Node3D,search_nodes:Array)->Array:
	var stack:Array
	stack.append_array(search_nodes)
	var result:Array
	var baker_invers_transform = baker_node.global_transform.inverse()
	while stack.size()!=0:
		var current_node = stack[-1]
		stack.remove_at(stack.size() -1)
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
		var current_node = stack[-1]
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

func get_bake_path():
	if not bake_path.ends_with(".res"):
		bake_path = bake_path + name + ".res"
	return bake_path
#endregion

#region JOINED MESH				


func make_joined_mesh(nodes_to_join):	
	var root_node = Node3D.new()
	root_node.name = "root_node"
	var mesh_instance = MeshInstance3D.new()
	root_node.add_child(mesh_instance)			
	mesh_instance.name = name.to_lower() + "_joined_mesh_lod_" + str(join_at_lod)
	###################
	## JOIN THE MESH ##
	###################
	var mesh_joiner := MMeshJoiner.new()
	var all_meshes_data = get_all_meshes(self, nodes_to_join)				
	var mesh_array = all_meshes_data.map(get_correct_mesh_lod_for_joining)	
	mesh_joiner.insert_mesh_data(mesh_array, all_meshes_data.map(func(a): return a.tr), all_meshes_data.map(func(a): return -1))		
	mesh_instance.mesh = mesh_joiner.join_meshes()					
		
	mesh_instance.mesh.resource_name = mesh_instance.name								
	var glb_path = get_joined_mesh_path()
	AssetIO.glb_export(root_node, glb_path)
	root_node.queue_free()
	update_joined_mesh_limits()
	var import_info = asset_library.import_info		
	if not import_info.has(glb_path):
		import_info[glb_path] = {"__metadata":{}}		
	if not import_info[glb_path].has("__metadata"):
		import_info[glb_path]["__metadata"] = {}			
	import_info[glb_path]["__metadata"]["baker_path"] = scene_file_path			
	var glb_node_name = AssetIO.node_parse_name( mesh_instance ).name
	
	if not asset_library.finish_import.is_connected(finish_import.bind(glb_node_name)):
		asset_library.finish_import.connect(finish_import.bind(glb_node_name))	
	AssetIO.glb_load(glb_path, import_info[glb_path]["__metadata"], true)				
	

func import_joined_mesh_glb():
	var joined_mesh_glb_path = get_joined_mesh_path()
	if FileAccess.file_exists(joined_mesh_glb_path):
		var metadata = asset_library.import_info[joined_mesh_glb_path]["__metadata"]
		AssetIO.glb_load(get_joined_mesh_path(), metadata, true)
		asset_library.finish_import.connect(finish_import)

func get_joined_mesh_path():
	return scene_file_path.get_basename() + "_joined_mesh.glb"

func get_correct_mesh_lod_for_joining(a):
	var lod_to_use = min(join_at_lod, len(a.meshes.meshes)-1)	
	while lod_to_use >-1 and a.meshes.meshes[lod_to_use] == null:
		lod_to_use -= 1
	var mesh = a.meshes.meshes[lod_to_use]
	return null if lod_to_use == -1 or mesh.get_surface_count() == 0 else a.meshes.meshes[lod_to_use]		

func update_joined_mesh_limits(limit = join_at_lod):		
	for data in get_all_meshes(self, get_children()):
		var node: MAssetMesh = data.node		
		node.lod_limit = limit

func get_joined_mesh_node():
	if is_instance_valid(joined_mesh_node): return joined_mesh_node
	joined_mesh_node = find_child("*_joined_mesh*")	
	if is_instance_valid(joined_mesh_node): return joined_mesh_node
	return null
	
func finish_import(glb_path, glb_collection_name=""):
	#CHECK IF IS JOINED MESH
	if not "joined_mesh" in glb_collection_name:
		return					
	var collection_id = -1		
	if is_instance_valid(joined_mesh_node) and joined_mesh_node.has_meta("collection_id"):
		collection_id = joined_mesh_node.get_meta("collection_id")
		if not asset_library.has_collection(collection_id):
			push_error("imported joined mesh, but collection id does not exists")		
		AssetIO.reload_collection(joined_mesh_node, collection_id)
	else:
		joined_mesh_node = find_child("*_joined_mesh*")		
		if is_instance_valid(joined_mesh_node):
			collection_id = joined_mesh_node.get_meta("collection_id")
			if not asset_library.has_collection(collection_id):
				push_error("imported joined mesh, but collection id does not exists")		
			AssetIO.reload_collection(joined_mesh_node, collection_id)			
		else:
			var node = Node3D.new()
			add_child(node)
			node.owner = self		
			node.name = glb_collection_name	
			joined_mesh_node = node
			if asset_library.import_info[glb_path].has( glb_collection_name ):
				collection_id = asset_library.import_info[glb_path][glb_collection_name]["id"]
				asset_library.collection_add_tag(collection_id, 0)
				AssetIO.reload_collection(node, collection_id)												
	asset_library.finish_import.disconnect(finish_import)
	
	if collection_id == -1:
		push_error("error joining meshes: on finish import, collection_id does not exist for joined mesh")	
	for id in asset_library.collection_get_mesh_items_info(collection_id)[0].mesh:
		if id != -1:			
			EditorInterface.get_resource_previewer().queue_resource_preview(MHlod.get_mesh_path(id),self, "save_thumbnail", collection_id)
			break	
			
func save_thumbnail(path, preview, thumbnail_preview, this_collection_id):				
	if not DirAccess.dir_exists_absolute("res://massets/thumbnails/"):
		DirAccess.make_dir_recursive_absolute("res://massets/thumbnails/")
	var thumbnail_path = str("res://massets/thumbnails/", this_collection_id,".png")
	if FileAccess.file_exists(thumbnail_path):
		preview.take_over_path(thumbnail_path)
	else:
		ResourceSaver.save(preview, thumbnail_path )												
	var fs := EditorInterface.get_resource_filesystem()	
	if not fs.resources_reimported.is_connected(resources_reimported):
		fs.resources_reimported.connect(resources_reimported)	
	fs.scan()		

func resources_reimported(paths):	
	notify_property_list_changed()

func get_joined_mesh_thumbnail():
	joined_mesh_node = get_joined_mesh_node()	
	if not is_instance_valid(joined_mesh_node): return null
	if not joined_mesh_node.has_meta("collection_id"): return null
	var collection_id = get_joined_mesh_node().get_meta("collection_id")
	var path = str("res://massets/thumbnails/", collection_id, ".png")
	if FileAccess.file_exists(path):
		return load(path)
	else:
		return null

func toggle_joined_mesh_disabled(toggle_on):
	joined_mesh_disabled = toggle_on
	if toggle_on:
		update_joined_mesh_limits(-1)
	else:
		update_joined_mesh_limits()
#endregion

#region MAssetMesh Updater			
func _enter_tree():			
	activate_mesh_updater()

func _exit_tree():	
	if is_instance_valid(timer):
		timer.queue_free()

func _notification(what):	
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		for child in get_children():
			if child.has_meta("collection_id"):
				for grandchild in child.get_children():					
					grandchild.owner = null		
	
func _ready():			
	#activate_mesh_updater()
	asset_mesh_updater.update_auto_lod()	
	for child in get_children():		
		if child.has_meta("collection_id"):
			var original_transform = child.transform
			var node = AssetIO.reload_collection(child, child.get_meta("collection_id"))
			if is_instance_valid(node):
				node.transform = original_transform				
		#if child.has_meta("hlod"):
			#for node in child.find_children("*"):
				#node.owner = child

	
func activate_mesh_updater():
	if not is_inside_tree():
		return
	if not asset_mesh_updater is MAssetMeshUpdater:	
		asset_mesh_updater = MAssetMeshUpdater.new()	
	asset_mesh_updater.set_root_node(self)
	if not is_instance_valid(timer):
		timer = Timer.new()
		timer.timeout.connect(update_asset_mesh)
	add_child(timer)	
	timer.start(1)
	#for child in find_children("*",  "Node3D", true, false):
		#if child is Node3D:
			#child.owner = EditorInterface.get_edited_scene_root()
			
func update_asset_mesh():
	asset_mesh_updater.update_auto_lod()
	asset_mesh_updated.emit()
#endregion
