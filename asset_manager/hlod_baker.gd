@tool
class_name HLod_Baker extends Node3D

signal asset_mesh_updated

@export_storage var joined_mesh_id := -1
@export_storage var joined_mesh_disabled := false
@export_storage var hlod_resource: MHlod
@export_storage var hlod_id: int = -1
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
	var aabb: AABB	
	hlod_resource = MHlod.new()
	hlod_resource.set_baker_path(scene_file_path)
	var join_at_lod = MAssetTable.mesh_join_start_lod(joined_mesh_id)	
	#################
	## BAKE MESHES ##
	#################
	var all_masset_mesh_nodes = get_all_masset_mesh_nodes(self, get_children())				
	var baker_inverse_transform = global_transform.inverse()		
	var first_item = true
	for item:MAssetMesh in all_masset_mesh_nodes:				
		if first_item:
			first_item = false
			aabb = item.get_joined_aabb()
		else:
			aabb.merge( item.get_joined_aabb() )			
		if item.collection_id == -1: continue							
		item.set_meta("item_ids",PackedInt32Array()) # clear
		for mdata:MAssetMeshData in item.get_mesh_data():						
			var mesh_array = mdata.get_mesh_lod().map(func(mmesh): return int(mmesh.resource_path.get_file()) if mmesh is MMesh else -1)
			var material_set_id = mdata.get_material_set_id()
			var shadow_array = mesh_array.map(func(a): return 0)
			var gi_array = mesh_array.map(func(a): return 0)			
			var render_layers = 0			
			var mesh_id = hlod_resource.add_mesh_item(baker_inverse_transform * mdata.get_global_transform(), mesh_array, material_set_id	, shadow_array, gi_array, render_layers, item.hlod_layers)
			if mesh_id == -1:
				push_error("failed to add mesh item to HLod during baking")
			item.get_meta("item_ids").push_back(mesh_id)
			var i = 0			
			var max = join_at_lod if join_at_lod >= 0 else MAX_LOD
			if item.lod_cutoff >= 0: max = min(max,item.lod_cutoff)			
			while i < max:
				if mesh_array[min(i, len(mesh_array)-1) ] != -1:
					hlod_resource.insert_item_in_lod_table(mesh_id, i)
				i += 1
			## Mesh With Collssion
			for cindex in mdata.get_collision_count():
				var type:MAssetTable.CollisionType= mdata.get_collision_type(cindex)
				var t:Transform3D = baker_inverse_transform * mdata.get_collision_transform(cindex)
				var params:Vector3 = mdata.get_collision_params(cindex)
				var iid:int = -1
				match type:
					MAssetTable.CollisionType.SHPERE: iid = hlod_resource.shape_add_sphere(t,params[0],0,-1)
					MAssetTable.CollisionType.CYLINDER: iid = hlod_resource.shape_add_cylinder(t,params[0],params[1],0,-1)
					MAssetTable.CollisionType.CAPSULE: iid = hlod_resource.shape_add_cylinder(t,params[0],params[1],0,-1)
					MAssetTable.CollisionType.BOX: iid = hlod_resource.shape_add_box(t,params,0,-1)
				if iid==-1: printerr("Error inserting shape")
				else:
					hlod_resource.insert_item_in_lod_table(iid,0)
					item.get_meta("item_ids").push_back(iid)
	################################
	## BAKE CollisionShape3D Node ##
	################################
	for n in get_all_collision_shape_nodes(self):
		n.set_meta("item_ids",PackedInt32Array())
		var shape:Shape3D= n.shape
		var t = baker_inverse_transform * n.global_transform
		var item_id:int = -1
		if shape is BoxShape3D: item_id = hlod_resource.shape_add_box(t,shape.size,0,-1)
		elif shape is SphereShape3D: item_id = hlod_resource.shape_add_sphere(t,shape.radius,0,-1)
		elif shape is CapsuleShape3D: item_id = hlod_resource.shape_add_capsule(t,shape.radius,shape.height,0,-1)
		elif shape is CylinderShape3D: item_id = hlod_resource.shape_add_cylinder(t,shape.radius,shape.height,0,-1)
		else: continue
		n.get_meta("item_ids").push_back(item_id)
		var max = n.get_meta("cutoff_lod") if n.has_meta("cutoff_lod") else 1
		for i in range(0,max):
			hlod_resource.insert_item_in_lod_table(item_id,i)
	##################
	## BAKE Lights ##
	##################
	for l in get_all_lights_nodes(self):
		l.set_meta("item_ids",PackedInt32Array())
		var iid := hlod_resource.light_add(l,baker_inverse_transform * l.global_transform,0)
		l.get_meta("item_ids").push_back(iid)
		var max = l.get_meta("cutoff_lod") if l.has_meta("cutoff_lod") else 1
		for i in range(0, max):
			hlod_resource.insert_item_in_lod_table(iid,i)
	#######################
	## BAKE Packed Scene ##
	#######################
	for p:MHlodNode3D in get_all_packed_scenes(self,get_children()):
		p.set_meta("item_ids",PackedInt32Array())
		var t:Transform3D = baker_inverse_transform * p.global_transform
		if p.scene_file_path.get_base_dir()!=MHlod.get_packed_scene_root_dir().get_base_dir():
			push_warning("Ignoring: p.scene_file_path is not in "+MHlod.get_packed_scene_root_dir())
			continue
		var id:= p.scene_file_path.get_file().get_basename().to_int()
		if p.scene_file_path!=MHlod.get_packed_scene_path(id):
			push_warning(p.scene_file_path+" is not a valid path!!!")
			continue
		var iid = hlod_resource.packed_scene_add(t,id,p.get_arg(0),p.get_arg(1),p.get_arg(2),0)
		p.get_meta("item_ids").push_back(iid)
		for i in range(0,2):
			hlod_resource.insert_item_in_lod_table(iid,i)
	############################
	## Set Packed Scene binds ##
	############################
	for p:MHlodNode3D in get_all_packed_scenes(self,get_children()):
		var item_id=-1
		if p.has_meta("item_ids") and p.get_meta("item_ids").size()==1:item_id=p.get_meta("item_ids")[0]
		if item_id==-1:
			printerr("Invalid item id in ",p.name)
			continue
		var bind0:int=-1
		var bind1:int=-1
		var type_hint0:MHlod.Type = MHlod.Type.NONE
		var type_hint1:MHlod.Type = MHlod.Type.NONE
		if p.has_meta("bind_item_hint_0"): type_hint0 = p.get_meta("bind_item_hint_0")
		if p.has_meta("bind_item_hint_1"): type_hint1 = p.get_meta("bind_item_hint_1")
		if p.has_meta("bind_item_0"): bind0 = get_node_item_id(p.get_meta("bind_item_0"),type_hint0)
		if p.has_meta("bind_item_1"): bind1 = get_node_item_id(p.get_meta("bind_item_1"),type_hint1)
		hlod_resource.packed_scene_set_bind_items(item_id,bind0,bind1)
	######################
	## BAKE JOINED_MESH ##
	######################
	var joined_mesh_array = MAssetTable.mesh_join_meshes(joined_mesh_id) 
	MHlod
	if not joined_mesh_disabled and join_at_lod >= 0 and len(joined_mesh_array) != null: 				
		var material_array = []
		material_array.resize(len(joined_mesh_array))
		material_array.fill(-1)		
		var shadow_array = material_array.map(func(a): return 0)
		var gi_array = material_array.map(func(a): return 0)		
		# MAKE SURE ALL ARRAYS ARE THE SAME LENGTH!				
		var mesh_id = hlod_resource.add_mesh_item(Transform3D(), joined_mesh_array, material_array, shadow_array, gi_array, 1, 0)		
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
	hlod_id = MAssetTable.get_last_free_hlod_id(hlod_id,scene_file_path)
	var bake_path := MHlod.get_hlod_path(hlod_id)
	var users = MHlodScene.get_hlod_users(bake_path)
	var save_err
	if FileAccess.file_exists(bake_path):	
		hlod_resource.take_over_path(bake_path)
		save_err = ResourceSaver.save(hlod_resource)
	else:
		if not DirAccess.dir_exists_absolute(bake_path.get_base_dir()):
			DirAccess.make_dir_absolute(bake_path.get_base_dir())
		save_err = ResourceSaver.save(hlod_resource, bake_path)
	for n in users:
		n.hlod = hlod_resource
	if save_err == OK:
		MAssetTable.get_singleton().collection_create(name,hlod_id,MAssetTable.HLOD,-1)
		MAssetTable.save()
	make_hlod_thumbnail(aabb)
	MHlodScene.awake()
	#EditorInterface.get_resource_filesystem().scan()

func make_hlod_thumbnail(aabb:AABB):
	aabb.grow(5)
	var cam = Camera3D.new()
	#cam.look_at_from_position()
	#aabb.get_center()
	asset_mesh_updater.update_force_lod(0)
		

#region Getters
func get_all_nodes_in_baker(baker_node:Node3D,search_nodes:Array,filter_func:Callable)->Array:
	var stack:Array
	stack.append_array(search_nodes)
	var result:Array
	var baker_invers_transform = baker_node.global_transform.inverse()
	while stack.size()!=0:
		var current_node = stack[-1]
		stack.remove_at(stack.size() -1)
		if (current_node is HLod_Baker and current_node != baker_node):
			continue
		if filter_func.call(current_node):
			result.push_back(current_node)
		stack.append_array(current_node.get_children())		
	return result

func get_all_collision_shape_nodes(baker_node:Node3D)->Array:
	return get_all_nodes_in_baker(baker_node,baker_node.get_children(),func(n):return n is CollisionShape3D and not n.disabled)

func get_all_lights_nodes(baker_node:Node3D)->Array:
	return get_all_nodes_in_baker(baker_node,baker_node.get_children(),func(n):return n is OmniLight3D or n is SpotLight3D)

func get_all_masset_mesh_nodes(baker_node:Node3D,search_nodes:Array)->Array:
	return get_all_nodes_in_baker(baker_node,search_nodes,func(n): return n is MAssetMesh)

func get_all_packed_scenes(baker_node:Node3D,search_nodes:Array)->Array:
	return get_all_nodes_in_baker(baker_node,search_nodes,func(n): return n is MHlodNode3D)

func get_node_item_id(node_unique_name:String,type_hint:MHlod.Type)->int:
	if node_unique_name.is_empty(): return -1
	if not has_node("%"+node_unique_name):
		printerr("There is not node with unique name \"",node_unique_name,"\" to be bind to PackedScene Node!")
		return -1
	var n = get_node("%"+node_unique_name)
	if not n.has_meta("item_ids"):
		printerr("Node \"",node_unique_name,"\" Item id is invalide!")
		return -1
	var item_ids:PackedInt32Array=n.get_meta("item_ids")
	var final_item_ids:PackedInt32Array
	# Filtring
	if type_hint == MHlod.Type.NONE: final_item_ids = item_ids
	else:
		for iid in item_ids:
			if hlod_resource.get_item_type(iid) == type_hint:
				final_item_ids.push_back(iid)
	if final_item_ids.size() == 0:
		if item_ids.size(): printerr("Node \"",node_unique_name,"\" Item id is invalide!")
		else: printerr("can not find item with the type hint in \"",node_unique_name,"\" Node")
		return -1
	if final_item_ids.size() > 1:
		push_warning("Node \"",node_unique_name,"\" has mutltiple valid item ID, only assign the first one and ignoring the rest!")
	return final_item_ids[0]

func get_all_sub_hlod(baker_node:Node3D,search_nodes:Array)->Array:
	var nodes = get_all_nodes_in_baker(baker_node,search_nodes,func(n):return n is MHlodScene and n.hlod != null)
	var result:Array
	var baker_invers_transform = baker_node.global_transform.inverse()	
	for n in nodes:
		var hlod_data := SubHlodBakeData.new()
		hlod_data.sub_hlod = n.hlod
		hlod_data.node = n
		hlod_data.tr = baker_invers_transform * n.global_transform
		result.push_back(hlod_data)				
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


#region JOINED MESH				
func get_joined_mesh():
	var join_at_lod = asset_mesh_updater.get_join_at_lod()
	if join_at_lod == -1: return null
	var mesh_lod = asset_mesh_updater.get_mesh_lod() 
	return mesh_lod.meshes[join_at_lod]
	var material_table = AssetIOMaterials.new()
	

func make_joined_mesh(nodes_to_join: Array, join_at_lod:int):			
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
			mesh_array.push_back(mesh_item.get_last_valid_mesh())
			material_set_id_array.push_back(mesh_item.get_material_set_id()[mesh_item.get_last_valid_lod()])
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
	var joined_mesh:ArrayMesh= mesh_joiner.join_meshes()
	# Setting surface names as ID of material
	for s in range(joined_mesh.get_surface_count()):
		var mat = joined_mesh.surface_get_material(s)
		var id = AssetIOMaterials.get_material_id(mat)
		joined_mesh.surface_set_name(s,str(id))
	var mmesh = MMesh.new()
	mmesh.create_from_mesh(joined_mesh)
	if joined_mesh_id == -1:
		joined_mesh_id=MAssetTable.get_last_free_mesh_join_id()
	AssetIOBaker.save_joined_mesh(joined_mesh_id, [mmesh], [join_at_lod])
	asset_mesh_updater.join_mesh_id = joined_mesh_id # should call after saving
	MAssetMeshUpdater.refresh_all_masset_updater()
	
func get_joined_mesh_glb_path()->String:	
	if FileAccess.file_exists(scene_file_path):
		return scene_file_path.get_basename() + "_joined_mesh.glb"
	elif owner is HLod_Baker and FileAccess.file_exists(owner.scene_file_path):		
		return owner.scene_file_path.get_basename() + "_" + name + "_joined_mesh.glb"
	return ""

func has_joined_mesh_glb()->bool:
	var path = get_joined_mesh_glb_path()	
	return path != "" and FileAccess.file_exists(path)

func toggle_joined_mesh_disabled(toggle_on):
	joined_mesh_disabled = toggle_on
	if toggle_on:		
		asset_mesh_updater.join_mesh_id = -1		
	else:
		asset_mesh_updater.join_mesh_id = joined_mesh_id #TODO: check if fixed
	if force_lod_enabled:
		force_lod(force_lod_value)
	else:
		force_lod(-1)

func remove_joined_mesh():
	if MAssetTable.mesh_join_get_stop_lod(joined_mesh_id) == 0: return	
	asset_mesh_updater.join_mesh_id = -1
	for id in MAssetTable.mesh_join_ids_no_replace(joined_mesh_id):					
		if id == -1: continue			
		var path = MHlod.get_mesh_path(id)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)						
	ResourceSaver.save(Resource.new(), MHlod.get_mesh_root_dir().path_join(str(joined_mesh_id, ".stop")))
	var glb_path = get_joined_mesh_glb_path()
	if FileAccess.file_exists(glb_path):
		DirAccess.remove_absolute(glb_path)						
	EditorInterface.get_resource_filesystem().scan()
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
	if EditorInterface.get_edited_scene_root() == self:
		if not scene_file_path.get_file() == name+".tscn":
			if FileAccess.file_exists(scene_file_path.get_base_dir().path_join(name+".tscn")):
				name = scene_file_path.get_file().trim_suffix(".tscn")
			else:
				var new_path = scene_file_path.get_base_dir().path_join(name+".tscn")
				DirAccess.rename_absolute(scene_file_path, new_path)
				scene_file_path = new_path
				
	var path = MAssetTable.get_hlod_res_dir().path_join(name+".res")	
	if not FileAccess.file_exists(path): 
		can_bake = true
	else:
		var hlod:MHlod = load(path)	
		if FileAccess.file_exists(hlod.get_baker_path()) and hlod.get_baker_path() != scene_file_path:
			can_bake = false
		else:		
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
	set_join_mesh_id(joined_mesh_id)
	if Engine.is_editor_hint() and not EditorInterface.get_resource_filesystem().filesystem_changed.is_connected(validate_can_bake):
		EditorInterface.get_resource_filesystem().filesystem_changed.connect(validate_can_bake)

func set_join_mesh_id(input:int):
	joined_mesh_id = input
	asset_mesh_updater.join_mesh_id = input

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
