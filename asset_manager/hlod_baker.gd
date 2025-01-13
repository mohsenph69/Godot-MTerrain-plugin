@tool
class_name HLod_Baker extends Node3D

signal asset_mesh_updated

#@export_storage var join_at_lod: int = -1
@export_storage var joined_mesh_collection_id := -1
@export_storage var joined_mesh_disabled := false
@export_storage var hlod_resource: MHlod
@export_storage var bake_path = "res://massets/hlod/": get = get_bake_path
@export_storage var meshes_to_join_overrides := {}
@export_storage var force_lod_enabled := false
@export_storage var force_lod_value: int
@export_storage var variation_layers: PackedStringArray = ["","","","","","","","","","","","","","","",""]
@export_storage var variation_layers_preview_value = 0
@export_storage var joined_mesh_modified_time: int = -1

var asset_library := MAssetTable.get_singleton()
var lod_levels = AssetIO.LOD_COUNT
var asset_mesh_updater := MAssetMeshUpdater.new()
var timer: Timer

var can_bake =false

const MAX_LOD = 10
const UPDATE_INTERVAL = 0.5



class SubHlodBakeData:
	var sub_hlod: MHlod
	var tr: Transform3D	
	var node: MHlodScene
	
class SubBakerBakeData:
	var sub_baker: HLod_Baker
	var tr: Transform3D	

func force_lod(lod:int):
	force_lod_value = lod		
	if lod == -1:
		asset_mesh_updater.update_auto_lod()
		force_lod_enabled = false
	else:		
		asset_mesh_updater.update_force_lod(lod)
		force_lod_enabled = true
		
func bake_to_hlod_resource():	
	MHlodScene.sleep()	
	hlod_resource = MHlod.new()
	hlod_resource.set_baker_path(scene_file_path)		

	var join_at_lod = asset_mesh_updater.get_join_at_lod()
	
	#################
	## BAKE MESHES ##
	#################
	var all_masset_mesh_nodes = get_all_masset_mesh_nodes(self, get_children())		
	var baker_inverse_transform = global_transform.inverse()
	for item:MAssetMesh in all_masset_mesh_nodes:		
		for mdata in item.get_mesh_data():							
			var mesh_array = mdata.get_mesh_lod().map(func(mmesh): return int(mmesh.resource_path.get_file()) if mmesh is MMesh else -1)
			var material_set_id = mdata.get_material_set_id()
			var shadow_array = mesh_array.map(func(a): return 0)
			var gi_array = mesh_array.map(func(a): return 0)			
			var render_layers = 0			
			var mesh_id = hlod_resource.add_mesh_item(baker_inverse_transform * mdata.get_global_transform(), mesh_array, material_set_id	, shadow_array, gi_array, render_layers, item.hlod_layers)
			if mesh_id == -1:
				push_error("failed to add mesh item to HLod during baking")
			var i = 0			
			var max = join_at_lod if join_at_lod >= 0 else MAX_LOD
			if item.lod_cutoff >= 0: max = min(max,item.lod_cutoff)
			while i < max:
				if mesh_array[min(i, len(mesh_array)-1) ] != -1:
					hlod_resource.insert_item_in_lod_table(mesh_id, i)
				i += 1
							
	######################
	## BAKE JOINED_MESH ##
	######################
	var joined_mesh_array = asset_mesh_updater.get_joined_mesh_ids()	
	if not joined_mesh_disabled and join_at_lod >= 0 and len(joined_mesh_array) != null: 				
		var material_array = []
		material_array.resize(len(joined_mesh_array))
		material_array.fill(-1)		
		var shadow_array = material_array.map(func(a): return 0)
		var gi_array = material_array.map(func(a): return 0)				
		var mesh_id = hlod_resource.add_mesh_item(Transform3D(), joined_mesh_array, 0, shadow_array, gi_array, 1, 0)		
		if mesh_id != -1:
			for i in range(join_at_lod, MAX_LOD):
				hlod_resource.insert_item_in_lod_table(mesh_id, i)		
		else:
			push_error("Hlod baker error: cannot add joined mesh to hlod table because mesh_id is -1")
		
	#######################
	## PREBAKE SUB_BAKER ##
	#######################
	var bakers = get_all_sub_bakers(self, get_children())	
	var all_hlod: Array[SubHlodBakeData] = []
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
		var scene_layers := 0
		if hlod_data.node and hlod_data.node is MHlodScene:
			scene_layers = hlod_data.node.scene_layers
		hlod_resource.add_sub_hlod(hlod_data.tr, hlod_data.sub_hlod, scene_layers)
		#hlod.lod_limit = join_at_lod
	
	hlod_resource.join_at_lod = join_at_lod
	var users = MHlodScene.get_hlod_users(bake_path)
	if FileAccess.file_exists(bake_path):	
		hlod_resource.take_over_path(bake_path)
		ResourceSaver.save(hlod_resource)
	else:
		if not DirAccess.dir_exists_absolute(bake_path.get_base_dir()):
			DirAccess.make_dir_absolute(bake_path.get_base_dir())
		ResourceSaver.save(hlod_resource, bake_path)
	for n in users:
		n.hlod = hlod_resource
	MHlodScene.awake()			
	return

#region Getters	
func get_all_masset_mesh_nodes(baker_node:Node3D,search_nodes:Array)->Array:
	var stack:Array
	stack.append_array(search_nodes)
	var result:Array
	var baker_invers_transform = baker_node.global_transform.inverse()
	while stack.size()!=0:
		var current_node = stack[-1]
		stack.remove_at(stack.size() -1)
		if (current_node is HLod_Baker and current_node != baker_node):
			continue
		if current_node is MAssetMesh:	
			result.push_back(current_node)
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
				hlod_data.node = current_node
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
	
func get_joined_mesh():
	var join_at_lod = asset_mesh_updater.get_join_at_lod()
	if join_at_lod == -1: return null
	var mesh_lod = asset_mesh_updater.get_mesh_lod() 
	return mesh_lod.meshes[join_at_lod]
	
func get_joined_mesh_id_array():		
	if not asset_library.has_collection(asset_mesh_updater.joined_mesh_collection_id): return null
	var mesh_items = asset_library.collection_get_mesh_items_info(asset_mesh_updater.joined_mesh_collection_id)
	if len(mesh_items) != 1: return null
	return mesh_items[0].mesh	
#endregion

#region JOINED MESH				
func make_joined_mesh(nodes_to_join: Array, join_at_lod:int):	
	#var root_node = Node3D.new()
	#root_node.name = "root_node"
	var mesh_instance = MeshInstance3D.new()
	#root_node.add_child(mesh_instance)			
	mesh_instance.name = name.to_lower() + "_joined_mesh_lod_" + str(join_at_lod)	
	###################
	## JOIN THE MESH ##
	###################
	var mesh_joiner := MMeshJoiner.new()				
	var baker_inverse_transform = global_transform.inverse()	
	var mesh_array := []	
	var material_set_id_array:  PackedInt32Array = []
	var transforms := []
	for node:MAssetMesh in get_all_masset_mesh_nodes(self, nodes_to_join):					
		for mesh_item:MAssetMeshData in node.get_mesh_data():			
			mesh_array.push_back(get_correct_mesh_lod_for_joining(mesh_item))
			material_set_id_array.push_back( mesh_item.get_material_set_id() )			
			transforms.push_back(baker_inverse_transform * mesh_item.get_global_transform())		
	for data:SubHlodBakeData in get_all_sub_hlod(self, get_children()):		
		var mhlod_node: MHlodScene = data.node
		if not is_instance_valid(data.node):
			push_error("trying to join mesh with mhlod_scenes, but node is invalid: ")
			continue
		var mesh_transforms = mhlod_node.get_last_lod_mesh_ids_transforms()
		for mesh_transform in mesh_transforms:			
			var mmesh:MMesh = load(MHlod.get_mesh_path(mesh_transform[0]))
			if mmesh:
				mesh_array.push_back( mmesh )
				transforms.push_back(baker_inverse_transform * mesh_transform[1])
				material_set_id_array.push_back( mesh_transform[2] )
		
	mesh_joiner.insert_mmesh_data(mesh_array, transforms, material_set_id_array)		
	mesh_instance.mesh = mesh_joiner.join_meshes()						
	ResourceSaver.save(mesh_instance.mesh, "res://joined_mesh_test.res")
	#print(mesh_instance.mesh.get_surface_count())
	mesh_instance.mesh.resource_name = mesh_instance.name			
	var glb_path = get_joined_mesh_glb_path()					
	#AssetIO.glb_export(root_node, glb_path)		
	AssetIO.glb_export(mesh_instance, glb_path)		
	mesh_instance.queue_free()
	#root_node.queue_free()
	
	for surface_id in mesh_instance.mesh.get_surface_count():
		pass
	#################################
	## IMPORT GLB WE JUST EXPORTED ##
	#################################	
	update_joined_mesh_from_glb()
	
func get_joined_mesh_glb_path()->String:	
	if FileAccess.file_exists(scene_file_path):
		return scene_file_path.get_basename() + "_joined_mesh.glb"
	elif owner is HLod_Baker and FileAccess.file_exists(owner.scene_file_path):		
		return owner.scene_file_path.get_basename() + "_" + name + "_joined_mesh.glb"
	return ""

func has_joined_mesh_glb()->bool:
	var path = get_joined_mesh_glb_path()	
	return path != "" and FileAccess.file_exists(path)

func get_correct_mesh_lod_for_joining(a:MAssetMeshData):
	var mmesh_array = a.get_mesh_lod()
	var lod_to_use = min(asset_mesh_updater.get_join_at_lod(), len(mmesh_array)-1)	
	#print("lod to use for join: ",lod_to_use, " join at lod: ", join_at_lod, " mesh items: ", len(mesh_lod.meshes)-1)
	while lod_to_use >-1 and mmesh_array[lod_to_use] == null:
		lod_to_use -= 1
	if lod_to_use == -1: return null
	var mesh = mmesh_array[lod_to_use]
	return null if mesh.get_surface_count() == 0 else mmesh_array[lod_to_use]		
	
func update_joined_mesh_from_glb():
	var glb_path = get_joined_mesh_glb_path()
	#print(asset_mesh_updater.get_join_at_lod())
	if not FileAccess.file_exists(glb_path):		
		push_error("trying to update joined mesh from glb, but glb does not exist at ", glb_path)	
		return
	AssetIO.glb_load(glb_path,{}, true)		
	if not asset_library.import_info.has(glb_path):
		push_error("joined mesh glb loaded, but import info does not have glb path ", glb_path)
		return
	var import_info = {}
	for key in asset_library.import_info[glb_path].keys():
		if key.begins_with("__"): continue
		import_info[key] = asset_library.import_info[glb_path][key]				
	if len(import_info.keys()) != 1:
		push_error("trying to update join mesh from glb but after import it doesn't have correct collection count")		
	joined_mesh_collection_id = asset_library.import_info[glb_path].values()[0].id
	print(joined_mesh_collection_id)
	asset_mesh_updater.joined_mesh_collection_id = joined_mesh_collection_id			
	asset_library.collection_add_tag(joined_mesh_collection_id, 0) #add "hidden" tag	

func toggle_joined_mesh_disabled(toggle_on):
	joined_mesh_disabled = toggle_on
	if toggle_on:		
		asset_mesh_updater.joined_mesh_collection_id = -1		
	else:
		asset_mesh_updater.joined_mesh_collection_id = joined_mesh_collection_id
	if force_lod_enabled:
		force_lod(force_lod_value)
	else:
		force_lod(-1)

func remove_joined_mesh():
	var path = get_joined_mesh_glb_path()
	var id = joined_mesh_collection_id
	joined_mesh_collection_id = -1
	asset_mesh_updater.joined_mesh_collection_id = -1	
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)		
	AssetIO.remove_collection(id)
#endregion

func set_variation_layers_visibility(value):
	for child in get_all_masset_mesh_nodes(self, get_children()):
		child.visible = child.hlod_layers & value > 0 or child.hlod_layers == 0 or value == 0
	variation_layers_preview_value = value
	
#region MAssetMesh Updater			
func _enter_tree():		
	if not is_node_ready(): 	
		await ready
	activate_mesh_updater()
	validate_can_bake()

func validate_can_bake():
	var path = "res://massets/hlod/"+name+".res"	
	if not FileAccess.file_exists(path): 
		can_bake = true
	else:
		var hlod:MHlod = load(path)	
		if FileAccess.file_exists(hlod.get_baker_path()) and hlod.get_baker_path() != scene_file_path:
			can_bake = false		
		can_bake = true


	
func _exit_tree():	
	if is_instance_valid(timer) and timer.is_inside_tree():
		timer.stop()

func _notification(what):	
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		for child in get_children():
			if child.has_meta("collection_id"):
				for grandchild in child.get_children():					
					grandchild.owner = null		
	
func _ready():				
	renamed.connect(validate_can_bake)
	activate_mesh_updater()
	#asset_mesh_updater.update_auto_lod()	
	if joined_mesh_collection_id!=-1 and not MAssetTable.get_singleton().has_collection(joined_mesh_collection_id):
		joined_mesh_collection_id = -1
		push_warning(name," Join Mesh Has been removed!")
	asset_mesh_updater.joined_mesh_collection_id = joined_mesh_collection_id
	if Engine.is_editor_hint() and not EditorInterface.get_resource_filesystem().filesystem_changed.is_connected(validate_can_bake):
		EditorInterface.get_resource_filesystem().filesystem_changed.connect(validate_can_bake)
	
func activate_mesh_updater():
	if not is_inside_tree():
		return
	if not asset_mesh_updater is MAssetMeshUpdater:	
		asset_mesh_updater = MAssetMeshUpdater.new()	
	asset_mesh_updater.set_root_node(self)
	if not is_instance_valid(timer):
		timer = Timer.new()
		timer.timeout.connect(update_asset_mesh)
	if not timer.get_parent():		
		add_child(timer)	
	elif not timer.is_inside_tree():		
		timer.reparent(self)
	if timer.is_inside_tree():		
		timer.start(UPDATE_INTERVAL)

func deactivate_mesh_updater():
	if is_instance_valid(timer):
		timer.stop()
	
func update_asset_mesh():	
	if force_lod_enabled:
		asset_mesh_updater.update_force_lod(force_lod_value)
		return # this should not be necessary, but sometime timer refuses to stop, and I don't know why
	asset_mesh_updater.update_auto_lod()
	asset_mesh_updated.emit()
#endregion

func update_variation_layer_name(i, new_name):
	variation_layers[i] = new_name
	notify_property_list_changed()
