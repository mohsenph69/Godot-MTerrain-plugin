@tool
extends Window
@onready var tags_control = find_child("Tags")
@onready var group_list = find_child("group_list")
@onready var add_group_button:Button = find_child("add_group_button")

var selected_group
@onready var asset_library: MAssetTable = MAssetTable.get_singleton()# load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))

func _ready():	
	if EditorInterface.get_edited_scene_root() == self: return
	wrap_controls = true
	visibility_changed.connect(init_settings)
	
	add_group_button.pressed.connect(add_group)
	tags_control.tag_changed.connect(func(tag, toggle_on):	
		if not selected_group: return
		if tag is String:
			tag = asset_library.tag_get_id(tag)
		if toggle_on:			
			asset_library.group_add_tag(selected_group, tag)
		else:
			asset_library.group_remove_tag(selected_group, tag)	
	)
	tags_control.tag_option_renamed.connect(func(id, new_name):
		asset_library.tag_set_name(id, new_name)
		asset_library.save()		
	)
	tags_control.tag_option_removed.connect(func(id):
		asset_library.tag_set_name(id, "")
		asset_library.save()
	)
	var add_tag_button = find_child("add_tag_button")
	add_tag_button.pressed.connect(add_tag)	

func init_settings():	
	set_tag_options(asset_library.tag_get_names())
	for child in group_list.get_children():
		group_list.remove_child(child)
		child.queue_free()		
	for group in asset_library.group_get_list():
		init_group(group)
		
func add_tag():	
	var i = 0
	var tag_name = "new tag 0"		
	while tag_name in asset_library.tag_get_names():
		i += 1
		tag_name = str("new tag ", i)
	for j in 256:
		if j < 2: continue #0: single_item_collection, 1: hidden
		if asset_library.tag_get_name(j) == "":
			asset_library.tag_set_name(j, tag_name)
			break
	set_tag_options(asset_library.tag_get_names())
	#asset_library.tag_set_name()
	#asset_library.tag_add(tag_name)
		
func set_tag_options(tags):
	tags_control.set_options(tags)	

func init_group(group):	
	var group_list_item = preload("res://addons/m_terrain/asset_manager/ui/group_list_item.tscn").instantiate()		
	group_list.add_child(group_list_item)		
	group_list_item.set_group_name(group)		
	group_list_item.group_renamed.connect(asset_library.group_rename)				
	group_list_item.group_removed.connect(func(group_name):
		asset_library.group_remove(group_name)
		ResourceSaver.save(asset_library,asset_library.resource_path)			
	)
	group_list_item.group_selected.connect(select_group)
	
func select_group(group):		
	selected_group = group	
	tags_control.set_tags_from_data(asset_library.group_get_tags(group))	

func add_group():
	var i = 0
	var new_group_name = str("new group ", i)	
	while asset_library.group_exist(new_group_name): 
		i += 1		
		new_group_name = str("new group ", i)	
	asset_library.group_create(new_group_name)
	init_group(new_group_name)
