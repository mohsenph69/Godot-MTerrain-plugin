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
	if data.callback.is_valid():
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
		if thumbnail_path.is_empty() or not FileAccess.file_exists(thumbnail_path):
			return null
		var file = FileAccess.open(thumbnail_path, FileAccess.READ)		
		var image:= Image.new()
		image.load_png_from_buffer(file.get_var())
		file.close()		
		tex = ImageTexture.create_from_image(image)	
		if tex==null: return null
		creation_time = FileAccess.get_modified_time(thumbnail_path)
	creation_time += 1.5
	if MAssetTable.get_singleton().collection_get_modify_time(collection_id) > creation_time:
		return null
	return tex

static func save_thumbnail(preview:Image, thumbnail_path:String):			
	var data = preview.save_png_to_buffer() if preview else Image.create_empty(64,64,false, Image.FORMAT_R8).save_png_to_buffer()
	var file = FileAccess.open(thumbnail_path, FileAccess.WRITE)
	if not DirAccess.dir_exists_absolute( thumbnail_path.get_base_dir() ):
		DirAccess.make_dir_recursive_absolute( thumbnail_path.get_base_dir() )
	file.store_var(data)
	file.close()

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

static func add_watermark(img:Image,type:MAssetTable.ItemType,is_add_color=false,add_color=Color()):
	var wt:Image
	match type:
		MAssetTable.DECAL:
			wt=load("res://addons/m_terrain/icons/mdecal.svg").get_image()
		MAssetTable.HLOD:
			wt=load("res://addons/m_terrain/icons/hlod.svg").get_image()
		_:
			return
	var wt_size = wt.get_size()
	for i in range(wt_size.x):
		for j in range(wt_size.y):
			var wpx:Color= wt.get_pixel(i,j)
			if is_add_color:
				wpx += add_color			
			img.set_pixel(i,j,wpx)

static func generate_decal_texture(collection_id:int)->Texture:
	var decal_item_id = MAssetTable.get_singleton().collection_get_item_id(collection_id)
	if decal_item_id==-1: return null
	var decal_path = MHlod.get_decal_path(decal_item_id)
	if ResourceLoader.exists(decal_path):
		var mdecal:MDecal = ResourceLoader.load(decal_path)
		if not mdecal.texture_albedo:
			return null
		var albedo_image:Image = mdecal.texture_albedo.get_image().duplicate()
		albedo_image.decompress()
		albedo_image.resize(64,64)
		var path = MAssetTable.get_asset_thumbnails_path(collection_id)
		add_watermark(albedo_image,MAssetTable.DECAL)
		save_thumbnail(albedo_image,path)
		return ImageTexture.create_from_image(albedo_image)
	return null

static func revalidate_thumbnails()->PackedInt32Array:
	var at:=MAssetTable.get_singleton()
	var changed_thumbnails := PackedInt32Array()
	for cid in at.collection_get_list():		
		var thum_path:String = at.get_asset_thumbnails_path(cid)
		if thum_path.is_empty(): continue # not supported
		var modify_time = at.collection_get_modify_time(cid)
		if not FileAccess.file_exists(thum_path) or FileAccess.get_modified_time(thum_path) < modify_time:
			changed_thumbnails.push_back(cid)
	return changed_thumbnails
