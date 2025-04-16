@tool
@icon("res://addons/m_terrain/icons/hbaker.svg")
class_name HLod_Baker extends Node3D

@export var save_compress:=true
@export_category("Default Lod cutoff")
@export var collision_lod_cutoff_default:int= 1
@export var decal_lod_cutoff_default:int= 3
@export var packed_scene_lod_cutoff_default:int=2
@export var lights_lod_cutoff_default:int= 3

signal asset_mesh_updated
signal baked

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
var cant_bake_reason = ""

var ignore_rename = false
var is_saving = false

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

func bake_to_hlod_resource(external_bake = false)->int:	# return hlod_id, -1 = fail
	if (owner and owner.scene_file_path.is_empty()) or (not owner and scene_file_path.is_empty()):
		MTool.print_edmsg("Please first save the baker scene")
		return -1
	var has_sub_hlod:=false
	var physics_dictionary = AssetIOMaterials.get_physics_ids()
	if not external_bake:
		MHlodScene.sleep()	
	hlod_resource = MHlod.new()
	hlod_resource.set_baker_path(scene_file_path)
	var join_at_lod = MAssetTable.mesh_join_start_lod(joined_mesh_id)	
	#################
	## BAKE MESHES ##
	#################
	var all_masset_mesh_nodes = get_all_masset_mesh_nodes(self, get_children())				
	var baker_inverse_transform = global_transform.inverse()		
	for item:MAssetMesh in all_masset_mesh_nodes:				
		if item.collection_id == -1: continue							
		item.set_meta("item_ids",PackedInt32Array()) # clear
		for mdata:MAssetMeshData in item.get_mesh_data():
			var mesh_array = mdata.get_mesh_lod().map(func(mmesh): return int(mmesh.resource_path.get_file()) if mmesh is MMesh else -1)
			var material_set_id = mdata.get_material_set_id()
			var shadow_array = mesh_array.map(func(a): return int(item.shadow_setting))
			var gi_array = mesh_array.map(func(a): return int(item.gi_mode))
			var render_layers = 0			
			var item_variation_layer = item.get_meta("variation_layers") if item.has_meta("variation_layers") else 0
			var current_mesh_transform:Transform3D = baker_inverse_transform * mdata.get_global_transform()
			var max = join_at_lod if join_at_lod >= 0 else MAX_LOD
			if item.mesh_lod_cutoff >= 0: max = min(max,item.mesh_lod_cutoff)
			if max==0:continue
			if mesh_array.size() > max:
				mesh_array.resize(max)
				material_set_id.resize(max)
				gi_array.resize(max)
				shadow_array.resize(max)
			var mesh_id = hlod_resource.add_mesh_item(current_mesh_transform, mesh_array, material_set_id, shadow_array, gi_array, render_layers, item_variation_layer)
			if mesh_id == -1:
				push_error("failed to add mesh item to HLod during baking")
			item.get_meta("item_ids").push_back(mesh_id)
			for i in range(max):
				if mesh_array[min(i, len(mesh_array)-1) ] != -1:
					hlod_resource.insert_item_in_lod_table(mesh_id, i)
			## Mesh With Collssion
			if not item.disable_collision:
				var physics_settings_id: int = -1
				var physics_setting_name = item.get_meta("physics_settings") if item.has_meta("physics_settings") else asset_library.collection_get_physics_setting(item.collection_id)							
				if not physics_setting_name.is_empty() and physics_dictionary.has(physics_setting_name):
					physics_settings_id = physics_dictionary[physics_setting_name]
				elif not physics_setting_name.is_empty():
					push_warning("Can not find physics setting with name %s in node %s" % [physics_setting_name,item.name])
				var col_cutoff:int = item.collision_lod_cutoff
				if col_cutoff < 0:
					col_cutoff = asset_library.collection_get_colcutoff(item.collection_id)						
				if col_cutoff == -1: 
					col_cutoff = collision_lod_cutoff_default
				for cindex in mdata.get_collision_count():
					var type:MAssetTable.CollisionType= mdata.get_collision_type(cindex)
					var t:Transform3D = baker_inverse_transform * mdata.get_collision_transform(cindex)
					var params:Vector3 = mdata.get_collision_params(cindex)
					var iid:int = -1								
					match type:
						MAssetTable.CollisionType.SHPERE: iid = hlod_resource.shape_add_sphere(t,params[0],item_variation_layer,physics_settings_id)
						MAssetTable.CollisionType.CYLINDER: iid = hlod_resource.shape_add_cylinder(t,params[0],params[1],item_variation_layer,physics_settings_id)
						MAssetTable.CollisionType.CAPSULE: iid = hlod_resource.shape_add_cylinder(t,params[0],params[1],item_variation_layer,physics_settings_id)
						MAssetTable.CollisionType.BOX: iid = hlod_resource.shape_add_box(t,params,item_variation_layer,physics_settings_id)					
					if iid==-1: printerr("Error inserting shape")
					else:										
						for j in col_cutoff:
							hlod_resource.insert_item_in_lod_table(iid,j)
							item.get_meta("item_ids").push_back(iid)
				####################################################
				#####     Bake Complex shape in Item Node    #######
				####################################################
				var complex_shape_id = mdata.get_complex_shape_id()
				if complex_shape_id != -1:
					var iid = hlod_resource.shape_add_complex(complex_shape_id,current_mesh_transform,item_variation_layer,physics_settings_id)
					item.get_meta("item_ids").push_back(iid)
					for ll in col_cutoff: 
						hlod_resource.insert_item_in_lod_table(iid,ll)
	################################
	##      BAKE Decals Node     ###
	################################
	for d:MDecalInstance in get_all_decals(self,get_children()):
		d.set_meta("item_ids",PackedInt32Array())
		if not d.decal: continue
		var decal_id=d.decal.resource_path.get_basename().get_file().to_int()		
		if MHlod.get_decal_path(decal_id)!=d.decal.resource_path:
			push_warning(d.name+" :Ivalide decal path \""+d.decal.resource_path+"\"")
			continue
		var t:Transform3D= baker_inverse_transform * d.global_transform
		var item_variation_layer = d.get_meta("variation_layers") if d.has_meta("variation_layers") else 0
		var cutoff_lod = d.get_meta("lod_cutoff") if d.has_meta("lod_cutoff") else decal_lod_cutoff_default
		if cutoff_lod==-1: cutoff_lod = decal_lod_cutoff_default
		if cutoff_lod > 0:
			var iid:int=hlod_resource.decal_add(decal_id,t,d.layers, item_variation_layer)
			d.get_meta("item_ids").push_back(iid)
			for i in cutoff_lod:
				hlod_resource.insert_item_in_lod_table(iid,i)
	################################
	## BAKE CollisionShape3D Node ##
	################################
	for n in get_all_collision_shape_nodes(self):
		n.set_meta("item_ids",PackedInt32Array())
		var cutoff_lod = n.get_meta("lod_cutoff") if n.has_meta("lod_cutoff") else collision_lod_cutoff_default
		if cutoff_lod==-1:cutoff_lod=collision_lod_cutoff_default
		if cutoff_lod>0:
			var shape:Shape3D= n.shape
			var t = baker_inverse_transform * n.global_transform
			var item_id:int = -1
			var item_variation_layer = n.get_meta("variation_layers") if n.has_meta("variation_layers") else 0
			var physics_setting_name:String= n.get_meta("physics_settings") if n.has_meta("physics_settings") else ""
			var physics_settings = -1
			if not physics_setting_name.is_empty() and physics_dictionary.has(physics_setting_name):
				physics_settings = physics_dictionary[physics_setting_name]
			elif not physics_setting_name.is_empty():
				push_warning("Can not find physics setting with name %s in node %s" % [physics_setting_name,n.name])
			if shape is BoxShape3D: item_id = hlod_resource.shape_add_box(t,shape.size,item_variation_layer, physics_settings)
			elif shape is SphereShape3D: item_id = hlod_resource.shape_add_sphere(t,shape.radius,item_variation_layer,physics_settings)
			elif shape is CapsuleShape3D: item_id = hlod_resource.shape_add_capsule(t,shape.radius,shape.height,item_variation_layer,physics_settings)
			elif shape is CylinderShape3D: item_id = hlod_resource.shape_add_cylinder(t,shape.radius,shape.height,item_variation_layer,physics_settings)
			else: continue
			n.get_meta("item_ids").push_back(item_id)		
			for i in cutoff_lod:
				hlod_resource.insert_item_in_lod_table(item_id,i)
	##################
	## BAKE Lights ##
	##################
	for l in get_all_lights_nodes(self):
		var cutoff_lod = l.get_meta("lod_cutoff") if l.has_meta("lod_cutoff") else lights_lod_cutoff_default
		if cutoff_lod==-1:cutoff_lod=lights_lod_cutoff_default
		if cutoff_lod>0:
			l.set_meta("item_ids",PackedInt32Array())
			var item_variation_layer = l.get_meta("variation_layers") if l.has_meta("variation_layers") else 0
			var iid := hlod_resource.light_add(l,baker_inverse_transform * l.global_transform,item_variation_layer)
			l.get_meta("item_ids").push_back(iid)
			for i in cutoff_lod:
				hlod_resource.insert_item_in_lod_table(iid,i)
	#######################
	## BAKE Packed Scene ##
	#######################
	for p:MHlodNode3D in get_all_packed_scenes(self,get_children()):
		p.set_meta("item_ids",PackedInt32Array())
		var cutoff_lod = p.get_meta("lod_cutoff") if p.has_meta("lod_cutoff") else packed_scene_lod_cutoff_default		
		if cutoff_lod==-1:cutoff_lod=packed_scene_lod_cutoff_default
		if cutoff_lod>0:
			var t:Transform3D = baker_inverse_transform * p.global_transform
			if p.scene_file_path.get_base_dir()!=MHlod.get_packed_scene_root_dir().get_base_dir():
				push_warning("Ignoring: p.scene_file_path is not in "+MHlod.get_packed_scene_root_dir())
				continue
			var id:= p.scene_file_path.get_file().get_basename().to_int()
			if p.scene_file_path!=MHlod.get_packed_scene_path(id):
				push_warning(p.scene_file_path+" is not a valid path!!!")
				continue
			var item_variation_layer = p.get_meta("variation_layers") if p.has_meta("variation_layers") else 0
			var iid = hlod_resource.packed_scene_add(t,id,p.get_arg(0),p.get_arg(1),p.get_arg(2),item_variation_layer)		
			p.get_meta("item_ids").push_back(iid)
			for i in cutoff_lod:
				hlod_resource.insert_item_in_lod_table(iid,i)		
	############################
	## Set Packed Scene binds ##
	############################
	for p:MHlodNode3D in get_all_packed_scenes(self,get_children()):
		var item_id=-1
		if p.has_meta("item_ids") and p.get_meta("item_ids").size()==1:item_id=p.get_meta("item_ids")[0]
		if item_id==-1:
			push_warning("Item %s is disbaled "%p.name)
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
	var joined_mesh_array = MAssetTable.mesh_join_ids(joined_mesh_id) 	
	if not joined_mesh_disabled and join_at_lod >= 0 and len(joined_mesh_array) != null: 				
		var material_array = []
		material_array.resize(len(joined_mesh_array))
		material_array.fill(0)		
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
	var __sub_hlod = get_all_sub_hlod(self, get_children())
	has_sub_hlod = __sub_hlod.size() > 0
	all_hlod.append_array(__sub_hlod)	
	for hlod_data in all_hlod:		
		# scene_layers = which of this hlod's layers are active
		var scene_layers := hlod_data.node.scene_layers if hlod_data.node and hlod_data.node is MHlodScene else 0					
		# item_variation_layer = which of the parent baker's layers this hlod belongs to 
		var item_variation_layer = hlod_data.node.get_meta("variation_layers") if hlod_data.node and hlod_data.node.has_meta("variation_layers") else 0			
		hlod_resource.add_sub_hlod(hlod_data.tr, hlod_data.sub_hlod, scene_layers) #, item_variation_layer)
	##################################
	## Thumnail AND AABB ############
	##################################
	var jmesh = hlod_resource.get_joined_mesh(false,true)
	var aabb = jmesh.get_aabb()
	for hlod_data in all_hlod:
		var gh_aabb:AABB = MTool.get_global_aabb(hlod_data.sub_hlod.get_aabb(),hlod_data.tr)
		aabb.merge(gh_aabb)
	hlod_resource.aabb = aabb
	# some subhlod may not included in join mesh
	# using jmesh down for thumnail
	##################################
	## FINALIZE AND SAVE BAKED HLOD ##
	##################################
	hlod_resource.join_at_lod = join_at_lod
	hlod_resource.resource_name = name
	if hlod_id != -1:
		validate_hlod_id()
	if hlod_id==-1:
		hlod_id = AssetIOBaker.find_hlod_id_by_baker_path(scene_file_path)		
		if hlod_id==-1:
			hlod_id = MAssetTable.get_last_free_hlod_id()	
	var bake_path := MHlod.get_hlod_path(hlod_id)
	var stop_path = bake_path.get_basename() + ".stop"
	if FileAccess.file_exists(stop_path):
		DirAccess.remove_absolute(stop_path)
	var users = MHlodScene.get_hlod_users(bake_path)
	var save_err
	if not DirAccess.dir_exists_absolute(bake_path.get_base_dir()):
			DirAccess.make_dir_absolute(bake_path.get_base_dir())
	if save_compress:
		save_err = ResourceSaver.save(hlod_resource,bake_path,ResourceSaver.FLAG_COMPRESS)
	else:
		save_err = ResourceSaver.save(hlod_resource,bake_path)
	if FileAccess.file_exists(bake_path):	
		hlod_resource.take_over_path(bake_path)
	for n in users:
		n.hlod = hlod_resource			
	if not save_err == OK:
		hlod_id = -1
		return -1
	if not external_bake:		
		EditorInterface.mark_scene_as_unsaved()
		EditorInterface.save_scene()
		MAssetTable.save()		
		MHlodScene.awake()
	if not scene_file_path.is_empty():
		var collection_id = MAssetTable.get_singleton().collection_create(name,hlod_id,MAssetTable.HLOD,-1)		
		ThumbnailManager.thumbnail_queue.push_back({"resource": jmesh, "callback": finish_generating_thumnail,"texture":null, "collection_id": collection_id,"has_sub_hlod":has_sub_hlod})	
	baked.emit()
	#AssetIOBaker.rebake_hlod_dependent_bakers(bake_path)
	#EditorInterface.get_resource_filesystem().scan()	
	return hlod_id

static func finish_generating_thumnail(data):
	var tex:Texture2D=data["texture"]
	if not tex:		
		return
	var img = tex.get_image()
	ThumbnailManager.add_watermark(img,MAssetTable.ItemType.HLOD,data["has_sub_hlod"],Color(0,0,0.5))
	var tpath = MAssetTable.get_asset_thumbnails_path(data["collection_id"])
	ThumbnailManager.save_thumbnail(img,tpath)
	AssetIO.asset_placer.regroup()

#region Getters
func get_all_nodes_in_baker(baker_node:Node3D,search_nodes:Array,filter_func:Callable)->Array:
	var stack:Array
	stack.append_array(search_nodes)
	var result:Array
	var baker_invers_transform = baker_node.global_transform.inverse()
	var _owner = baker_node.owner
	if _owner == null: _owner = baker_node
	while stack.size()!=0:
		var current_node = stack[-1]
		stack.remove_at(stack.size() -1)
		if (current_node is HLod_Baker and current_node != baker_node):
			continue
		if _owner != current_node.owner: continue
		
		if filter_func.call(current_node):
			result.push_back(current_node)		
		stack.append_array(current_node.get_children().filter(func(node): return node.owner == baker_node ))
	return result

func get_all_collision_shape_nodes(baker_node:Node3D)->Array:
	return get_all_nodes_in_baker(baker_node,baker_node.get_children(),func(n):return n is CollisionShape3D and not n.disabled)

func get_all_lights_nodes(baker_node:Node3D)->Array:
	return get_all_nodes_in_baker(baker_node,baker_node.get_children(),func(n):return n is OmniLight3D or n is SpotLight3D)

func get_all_masset_mesh_nodes(baker_node:Node3D,search_nodes:Array)->Array:
	return get_all_nodes_in_baker(baker_node,search_nodes,func(n): return n is MAssetMesh)

func get_all_packed_scenes(baker_node:Node3D,search_nodes:Array)->Array:
	return get_all_nodes_in_baker(baker_node,search_nodes,func(n): return n is MHlodNode3D)

func get_all_decals(baker_node:Node3D,search_nodes:Array)->Array:
	return get_all_nodes_in_baker(baker_node,search_nodes,func(n): return n is MDecalInstance)

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
		if item_ids.size(): printerr("Node \"",node_unique_name,"\" Item id is invalide, item_ids size zero!")
		else: printerr("can not find item with the type hint in \"",node_unique_name,"\" Node")
		return -1
	if final_item_ids.size() > 1:
		push_warning("Node \"",node_unique_name,"\" has mutltiple valid item ID, only assign the first one and ignoring the rest!")
	return final_item_ids[0]

func get_all_sub_hlod(baker_node:Node3D,search_nodes:Array)->Array:
	var nodes = get_all_nodes_in_baker(baker_node,search_nodes,func(n):return (n is MHlodScene and n.hlod) or (n is HLod_Baker_Guest and n.hlod_resource))
	var result:Array
	var baker_invers_transform = baker_node.global_transform.inverse()	
	for n in nodes:
		var hlod_data := SubHlodBakeData.new()
		hlod_data.sub_hlod = n.hlod if n is MHlodScene else n.hlod_resource
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
		if current_node is HLod_Baker_Guest: continue
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
	var joined_mesh := ArrayMesh.new()
	if len(nodes_to_join)>0:
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
		joined_mesh = mesh_joiner.join_meshes()
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

func has_joined_mesh()->bool:
	return MAssetTable.mesh_join_is_valid(joined_mesh_id)

func toggle_joined_mesh_disabled(toggle_on):
	joined_mesh_disabled = toggle_on
	if toggle_on:		
		asset_mesh_updater.join_mesh_id = -1		
	else:
		asset_mesh_updater.join_mesh_id = joined_mesh_id
	if force_lod_enabled:
		force_lod(force_lod_value)
	else:
		force_lod(-1)

func remove_joined_mesh():
	asset_mesh_updater.join_mesh_id = -1
	for id in MAssetTable.mesh_join_ids_no_replace(joined_mesh_id):					
		if id == -1: continue			
		var path = MHlod.get_mesh_path(id)
		var stop_path = path.get_basename() + ".stop"
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		if FileAccess.file_exists(stop_path):
			DirAccess.remove_absolute(stop_path)
	var stop_path = MHlod.get_mesh_root_dir().path_join(str(joined_mesh_id, ".stop"))
	var f = FileAccess.open(stop_path,FileAccess.WRITE)
	f.close()
	var glb_path = AssetIOBaker.get_glb_path_by_baker_node(self)
	if FileAccess.file_exists(glb_path):
		DirAccess.remove_absolute(glb_path)						
	EditorInterface.get_resource_filesystem().scan()
#endregion

func set_variation_layers_visibility(value):
	variation_layers_preview_value = value
	asset_mesh_updater.variation_layers = value

#region MAssetMesh Updater			
func _enter_tree():		
	if not is_node_ready(): 	
		await ready
	activate_mesh_updater()
	validate_can_bake()
	asset_mesh_updater.variation_layers = variation_layers_preview_value

func validate_can_bake():			
	var path = MAssetTable.get_hlod_res_dir().path_join(name+".res")	
	can_bake = true
	if FileAccess.file_exists(path): 			
		var hlod:MHlod = load(path)	
		if FileAccess.file_exists(hlod.get_baker_path()) and hlod.get_baker_path() != scene_file_path:
			can_bake = false
			cant_bake_reason = "HLod with the name " + name + " is already used by another baker scene. please rename the baker scene"
	if len(find_children("*", "HLod_Baker_Guest", true, true)) > 0:
		can_bake = false		
		cant_bake_reason = "Please resolve baker guest nodes before baking"
	if not scene_file_path:
		can_bake = false		
		cant_bake_reason = "Please save the baker season before trying to bake"
	
func _exit_tree():	
	asset_mesh_updater.show_boundary = false
	asset_mesh_updater.update_force_lod(-1)
	if is_instance_valid(timer) and timer.is_inside_tree():
		timer.stop()
	
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

	
func validate_hlod_id():
	print("validating hlod_id ", hlod_id)	
	if hlod_id == -1: 
		hlod_id = AssetIOBaker.find_hlod_id_by_baker_path(scene_file_path)		
		if hlod_id == -1: 
			hlod_id = MAssetTable.get_last_free_hlod_id()
		return
	else:
		var path = MHlod.get_hlod_path(hlod_id)
		if not FileAccess.file_exists(path): 
			return			
		var mhlod:MHlod = load(path)
		if not mhlod.baker_path == scene_file_path:			
			hlod_id = AssetIOBaker.find_hlod_id_by_baker_path(scene_file_path)					
			if hlod_id ==-1:				
				hlod_id = MAssetTable.get_last_free_hlod_id()										
			return	
		
