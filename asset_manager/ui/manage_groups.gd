@tool
extends Control
@onready var tag_list = find_child("tag_list")
@onready var group_list:Tree = find_child("group_list")
@onready var add_group_button:Button = find_child("add_group_button")
@onready var remove_selected_groups_button:Button = find_child("remove_selected_groups_button")

var selected_groups := []
@onready var asset_library: MAssetTable = MAssetTable.get_singleton()# load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))

func _ready():		
	#if not EditorInterface.get_edited_scene_root() or EditorInterface.get_edited_scene_root() == self or EditorInterface.get_edited_scene_root().is_ancestor_of(self): return
	group_list.item_edited.connect(func():
		var item = group_list.get_edited()
		var new_name = item.get_text(0)
		var original_name = item.get_metadata(0)
		item.set_editable(0, false)
		if original_name == new_name: return
		if not asset_library.group_exist(new_name):
			%group_rename_error.visible = false
			asset_library.group_rename(original_name, new_name)
		else:
			item.set_text(0, original_name)
			%group_rename_error.visible = true		
	)
	group_list.nothing_selected.connect(func():
		deselect_all_groups()
	)
		
	group_list.multi_selected.connect(func(current_item:TreeItem, column, selected:bool):			
		if selected:
			select_group(current_item)
		else:
			# Deselect
			current_item.set_editable(0, false)
			if current_item.get_text(0) in selected_groups:
				selected_groups.erase(current_item.get_text(0))
			remove_selected_groups_button.disabled = group_list.get_next_selected(null) == null
	)
	remove_selected_groups_button.pressed.connect(func():
		var item = group_list.get_next_selected(null)
		while item:
			if asset_library.group_exist( item.get_text(0) ):
				asset_library.group_remove(item.get_text(0))
			item = group_list.get_next_selected(item)
		init_settings()
	)
	add_group_button.pressed.connect(add_group)		
	
	tag_list.tag_changed.connect(func(tag, toggle_on):					
		if len(selected_groups) == 0: return
		if tag is String:
			tag = asset_library.tag_get_id(tag)
		if toggle_on:	
			for group in selected_groups:		
				asset_library.group_add_tag(group, tag)
		else:
			for group in selected_groups:
				asset_library.group_remove_tag(group, tag)	
		tag_list.set_tags_from_data(asset_library.group_get_tags(selected_groups[-1]))
	)		
	tag_list.options_changed.connect(func():		
		deselect_all_groups()
	)
	visibility_changed.connect(init_settings)	
	
	tag_list.set_editable(true)
	tag_list
	var group_search = find_child("group_search")
	group_search.text_changed.connect(filter_groups)
	
func select_group(current_item):
	current_item.set_editable(0, true)	# allow for renaming if click again		
	selected_groups = group_list.get_root().get_children().filter(func(item): return item.is_selected(0)).map(func(item): return item.get_text(0))			
	remove_selected_groups_button.disabled = false			
	tag_list.set_tags_from_data(asset_library.group_get_tags(current_item.get_text(0)))							

func deselect_all_groups():
	group_list.deselect_all()
	selected_groups =[]
	tag_list.set_tags_from_data([])							
	
func filter_groups(text):
	for item: TreeItem in group_list.get_root().get_children():
		item.visible = item.get_text(0).containsn(text) or text == ""
		
func init_settings():		
	group_list.clear()
	group_list.create_item()
	for group in asset_library.group_get_list():
		init_group(group)	
	tag_list.set_options()
	
func init_group(group):	
	var item = group_list.get_root().create_child()
	item.set_text(0, group)
	item.set_metadata(0, group)
	#item.set_editable(0, true)				
	
func add_group():
	var i = 0
	var new_group_name = str("new group")	
	while asset_library.group_exist(new_group_name): 
		i += 1		
		new_group_name = str("new group ", i)	
	asset_library.group_create(new_group_name)
	init_group(new_group_name)
