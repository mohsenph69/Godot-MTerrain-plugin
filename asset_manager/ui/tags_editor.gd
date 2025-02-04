#################
## TAGS EDITOR ##
#################
# 1. call set_editable(bool) to begin
# 2. connect to "tag_changed(tag_id, toggle_on)" signal
# 3. connect to options_changed() signal for when tags are renamed/added/removed
# 4. use set_tags_from_data(Array[tag_id]) to tell this control which tags should be selected
@tool
extends Control

signal tag_changed
signal options_changed
@onready var tag_list:Tree = find_child("tag_list")
@onready var group_by_button:Button = find_child("group_by_button")

var editable = false
var asset_library:MAssetTable = MAssetTable.get_singleton()
var current_tags = []

func _ready():	
	#if not EditorInterface.get_edited_scene_root() or EditorInterface.get_edited_scene_root() == self or EditorInterface.get_edited_scene_root().is_ancestor_of(self): return
	var search = find_child("search")
	search.text_changed.connect(search_tags)
	set_options()
	group_by_button.pressed.connect(set_options)
	group_by_button.pressed.connect(set_tags_from_data)
	%clear_tags_button.pressed.connect(func():
		for tag in current_tags:
			tag_changed.emit(tag, false)
		set_tags_from_data([])
	)
	
func search_tags(new_text):		
	if group_by_button.button_pressed:		
		for group_item in tag_list.get_root().get_children():
			var hide_group = true
			for item in group_item.get_children():
				var tag_text = item.get_text(1).to_lower() if editable else item.get_text(0).to_lower()			
				item.visible = tag_text.containsn(new_text) or new_text == ""				
				if item.visible:
					hide_group = false
			group_item.visible = not hide_group
	else:
		for item in tag_list.get_root().get_children():
			var tag_text = item.get_text(1).to_lower() if editable else item.get_text(0).to_lower()			
			item.visible = tag_text.containsn(new_text) or new_text == ""				
	
func get_selected_tags():
	var result = {}	
	if group_by_button.button_pressed:		
		for group in tag_list.get_root().get_children():
			for item in group.get_children().filter(func(item): return item.is_selected(0) or item.is_selected(1)):			
				result[item.get_text(1)] = item.get_metadata(0)
	else:
		for item in tag_list.get_root().get_children().filter(func(item): return item.is_selected(0) or item.is_selected(1)):			
			result[item.get_text(1)] = item.get_metadata(0)
	return result

func set_editable(toggle_on):
	editable = toggle_on
	if editable:
		tag_list.columns = 2
		tag_list.set_column_expand(0, false)
		tag_list.set_column_custom_minimum_width(0, 32)			
		tag_list.select_mode = Tree.SELECT_MULTI
		%add_tag_button.pressed.connect(add_tag)
		%remove_selected_tags_button.pressed.connect(remove_tags)				
		tag_list.multi_selected.connect(multi_selected)
		tag_list.item_edited.connect(item_edited)		
		if tag_list.item_selected.is_connected(single_item_selected):
			tag_list.item_selected.disconnect(single_item_selected)
	else:
		tag_list.columns = 1
		tag_list.select_mode = Tree.SELECT_ROW
		if not tag_list.item_selected.is_connected(single_item_selected):
			tag_list.item_selected.connect(single_item_selected)
		if %add_tag_button.pressed.is_connected(add_tag):
			%add_tag_button.pressed.disconnect(add_tag)
		if %remove_selected_tags_button.pressed.is_connected(remove_tags):
			%remove_selected_tags_button.pressed.diconnect(remove_tags)				
		if tag_list.multi_selected.is_connected(multi_selected):
			tag_list.multi_selected.disconnect(multi_selected)		
			
func item_edited():
	var item = tag_list.get_edited()
	if tag_list.get_edited_column() == 1:
		var tag_id = item.get_metadata(0)
		var new_name = item.get_text(1)
		var original_name = asset_library.tag_get_name(tag_id)
		if new_name == original_name: return
		if asset_library.tag_get_id(new_name) != -1:
			item.set_text(1, original_name)
			%tag_name_error.visible = true
		else:
			asset_library.tag_set_name(tag_id, new_name)			
	elif tag_list.get_edited_column() == 0:
		tag_changed.emit(item.get_metadata(0), item.is_checked(0))
		set_tags_from_data()
		
func add_tag():
	var tag_name = "New Tag"
	var i = 0
	while asset_library.tag_get_id(tag_name) != -1: 
		i+= 1
		tag_name = str("New Tag ", i)		 
	
	var tag_id = 0
	for j in 256:
		tag_id+=1
		if tag_id < 2: continue #0: single_item_collection, 1: hidden
		if asset_library.tag_get_name(tag_id) == "":
			asset_library.tag_set_name(tag_id, tag_name)
			add_tag_item(tag_id, tag_name)	
			break
	asset_library.save()
	set_options()	
	options_changed.emit()
	
func remove_tags():			
	var selected_tags = get_selected_tags().values()
	for tag_id in selected_tags:					
		asset_library.tag_set_name(tag_id, "")		
	asset_library.save()					
	set_options()
	options_changed.emit()

func multi_selected(item: TreeItem, column, selected:bool):
	%tag_name_error.visible = false
	if selected:		
		item.set_editable(1, true)		
	%remove_selected_tags_button.disabled = tag_list.get_next_selected(null) == null
		
		
func single_item_selected():	
	var item = tag_list.get_selected()	
	#if item.is_selected(0):		
	tag_changed.emit(item.get_metadata(0), not item.is_checked(0))
	set_tags_from_data()
#		item.deselect(0)
#	else:
#		tag_changed.emit(item.get_metadata(0), true)		
	
func set_options(tag_data = asset_library.tag_get_names()): #{tag_name: tag_id}	
	if not is_instance_valid(tag_list): await ready
	$HBoxContainer.visible = editable
	tag_list.clear()
	tag_list.create_item()			
	if not group_by_button.button_pressed:
		tag_list.hide_folding = true
		for tag in tag_data:
			if tag_data[tag] == 0: continue		
			add_tag_item(tag_data[tag], tag)	
	else:
		tag_list.hide_folding = false		
		var all_tags: Dictionary = asset_library.tag_get_names()		
		for group in asset_library.group_get_list():
			var group_item := tag_list.get_root().create_child()
			group_item.set_text(0, group)
			group_item.set_selectable(0, false)			
			group_item.set_expand_right(0, true)
			
			for tag_id in asset_library.group_get_tags(group):			
				add_tag_item(tag_id, asset_library.tag_get_name(tag_id), group_item)	
				all_tags.erase(all_tags.find_key(tag_id))
		var group_item := tag_list.get_root().create_child()
		group_item.set_text(0, "(no group)")
		group_item.set_selectable(0, false)			
		group_item.set_expand_right(0, true)
		for tag_name in all_tags:
			add_tag_item(all_tags[tag_name], tag_name, group_item)	
					
func add_tag_item(tag_id, tag, root := tag_list.get_root()):	
	var item = root.create_child()	
	item.set_metadata(0, tag_id)		
	item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
	item.set_editable(0, true)		
	if editable:
		item.set_text(1, tag)					
	else:		
		item.set_text(0, tag)					
		
			
func toggle_tag(button, tag):	
	tag_changed.emit(tag, button.button_pressed)		
	set_tags_from_data()
							
func set_tags_from_data(tags = current_tags): #tags: Array[int32]
	if not is_instance_valid(tag_list): await ready	
	current_tags = tags
	var groups = tag_list.get_root().get_children() if group_by_button.button_pressed else [null]		
	for group in groups:
		var root = group if group is TreeItem else tag_list.get_root()
		for item in root.get_children():		
			var id = item.get_metadata(0)
			if id:									
				item.set_checked(0, id in current_tags)		
