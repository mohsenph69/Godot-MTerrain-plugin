@tool
class_name HLod_Baker extends Node

@export var lod_levels = 5
@export var max_lod = -1
@export var bake_path = "res://"
@export var bake = false

func _notification(what):
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		for child in get_children():
			if child.has_meta("collection_id"):
				for grandchild in child.get_children():
					grandchild.owner = null
					

func _ready():
	for child in get_children():
		if child.has_meta("collection_id"):
			var original_transform = child.transform
			AssetIO.reload_collection(child, child.get_meta("collection_id")).transform = original_transform

func bake_to_hlod_resource():	
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
