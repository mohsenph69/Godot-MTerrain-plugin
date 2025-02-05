class_name ThumbnailManager extends Node

static var thumbnail_queue := [] # {resource, caller, callback, ...}
static var generating_thumbnail := false
static var thumbnail_cache = {}

func _process(delta):
	if len(thumbnail_queue)==0: return
	if generating_thumbnail:
		return
	var data = thumbnail_queue.pop_back()			
	if is_instance_valid(data.resource):
		var _rp = EditorInterface.get_resource_previewer()			
		generating_thumbnail = true	
		_rp.queue_edited_resource_preview(data.resource,self,"handle_generate_thumbnail",data)
	
func handle_generate_thumbnail(path, preview, thumbnail_preview,data):				
	data["texture"] = preview	
	data.callback.call(data)	
	generating_thumbnail = false
	
static func get_valid_thumbnail(collection_id:int)->Texture2D:
	if collection_id == -1: return null
	var asset_library = MAssetTable.get_singleton()
	if not asset_library.has_collection(collection_id): return null
	var tex=null
	var creation_time = -1
	if tex==null or creation_time < 0:
		var thumbnail_path = MAssetTable.get_asset_thumbnails_path(collection_id)
		if not FileAccess.file_exists(thumbnail_path): return null
		var file = FileAccess.open(thumbnail_path, FileAccess.READ)		
		var image:= Image.new()
		image.load_png_from_buffer(file.get_var())
		file.close()		
		tex = ImageTexture.create_from_image(image)	
		if tex==null: return null
		creation_time = FileAccess.get_modified_time(thumbnail_path)
	creation_time += 1.5
	if get_collection_import_time(collection_id) > creation_time:
		return null
	return tex

static func save_thumbnail(preview:Image, thumbnail_path:String):			
	var data = preview.save_png_to_buffer() if preview else Image.create_empty(64,64,false, Image.FORMAT_R8).save_png_to_buffer()
	var file = FileAccess.open(thumbnail_path, FileAccess.WRITE)
	if not DirAccess.dir_exists_absolute( thumbnail_path.get_base_dir() ):
		DirAccess.make_dir_recursive_absolute( thumbnail_path.get_base_dir() )
	file.store_var(data)
	file.close()

static func get_collection_import_time(collection_id:int)->float:
	var glb_id:int = MAssetTable.get_singleton().collection_get_glb_id(collection_id)
	var import_info:Dictionary = MAssetTable.get_singleton().import_info
	for k in import_info:
		if k.begins_with("__"): continue
		if import_info[k]["__id"] == glb_id: return import_info[k]["__import_time"]
	return -1

static func make_tscn_thumbnail(scene_path, collection_id, aabb = null):		
	# THIS IS NOT WORKING
	return
	var viewport := SubViewport.new()
	viewport.size = Vector2(256, 256)  # Adjust resolution
	viewport.own_world_3d = true
	#viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	EditorInterface.get_edited_scene_root().add_child(viewport)

	# Load the scene
	var instance 
	if not scene_path is Node:
		instance = load(scene_path).instantiate()
		viewport.add_child(instance)
		
	# Add a camera
	var camera = Camera3D.new()
	if aabb:
		var size = aabb.size.length()
		var distance = size * 1.2  # Adjust factor as needed
		camera.position = aabb.get_center() + Vector3(0, size, distance)
	else:
		camera.position = Vector3(0, 4, 20)
		camera.look_at(Vector3.ZERO)
	viewport.add_child(camera)

	# Wait a frame, then capture the image
	var tree = EditorInterface.get_edited_scene_root().get_tree()
	await tree.process_frame				
	save_thumbnail(viewport.get_texture().get_image(), MAssetTable.get_singleton().get_asset_thumbnails_path( collection_id ))		
	# DEBUG: save png
	viewport.get_texture().get_image().save_png("res://thumbnail.png")
	# Cleanup
	viewport.queue_free()
