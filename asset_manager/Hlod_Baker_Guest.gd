@tool
@icon("res://addons/m_terrain/icons/hbaker_guest.svg")
class_name HLod_Baker_Guest extends HLod_Baker

func save_baker_changes(): #this function is called when editing baker inside another scene		
	var scene_root = EditorInterface.get_edited_scene_root()
	if not scene_file_path or scene_root == self: return
	for child in find_children("*"):
		if child.owner == scene_root:
			child.owner = self
	var packed_scene = PackedScene.new()
	var baker = HLod_Baker.new()
	for prop in get_property_list():
		baker.set(prop.name, get(prop.name))
	for child in get_children():
		child.reparent(baker)	
	packed_scene.pack(baker)	
	var path = scene_file_path
	print("overwrite error?...:", ResourceSaver.save(packed_scene, path	))
	packed_scene.take_over_path(scene_file_path)		
	bake_to_hlod_resource()		
	if scene_file_path in EditorInterface.get_open_scenes():
		EditorInterface.reload_scene_from_path(scene_file_path)
	baker.queue_free()
	is_saving = false
	
func replace_baker_with_mhlod_scene():		
	save_baker_changes() #.call_deferred()	
	var mhlod_scene := MHlodScene.new() 
	var node_name = name
	mhlod_scene.scene_layers = variation_layers_preview_value	
	if has_meta("lod_cutoff"):
		mhlod_scene.set_meta("lod_cutoff", get_meta("lod_cutoff"))			
	#ignore_rename = true
	#name = "TMP"		
	#ignore_rename = false
	var parent = get_parent()
	parent.add_child(mhlod_scene)
	parent.move_child(mhlod_scene, get_index())	
	#get_parent().remove_child(self)			
	#add_sibling(mhlod_scene)
	mhlod_scene.owner = owner
	mhlod_scene.hlod = hlod_resource
	#mhlod_scene.name = node_name
	tree_exiting.connect(func(): mhlod_scene.set_deferred("name", node_name))
	queue_free()

static func replace_mhlod_scene_with_baker_guest(baker_path:String, mhlod_scene:MHlodScene):	
	var baker = load(baker_path).instantiate()
	baker.set_script(load("res://addons/m_terrain/asset_manager/Hlod_Baker_Guest.gd"))
	var node_name = mhlod_scene.name
	baker.variation_layers_preview_value = mhlod_scene.scene_layers
	mhlod_scene.name = "TMP"
	if mhlod_scene.has_meta("lod_cutoff"):
		baker.set_meta("lod_cutoff", mhlod_scene.get_meta("lod_cutoff"))
	baker.name = node_name	
	mhlod_scene.add_sibling(baker)
	baker.owner = mhlod_scene.owner	
	var scene_root = EditorInterface.get_edited_scene_root()
	for child in baker.find_children("*"):
		if child.owner == baker:
			child.owner = scene_root
	mhlod_scene.queue_free()
