#class_name Asset_Placer 
@tool
extends PanelContainer

signal selection_changed
signal assets_changed

const hlod_baker_script:=preload("res://addons/m_terrain/asset_manager/hlod_baker.gd")

@onready var asset_filter_control = %asset_placer_filter
@onready var asset_place_control = %asset_placer_place
@onready var asset_add_control = %asset_placer_add

var popup_button_group: ButtonGroup
@onready var asset_type_filter_button:Button = find_child("asset_type_filter_button")
@onready var filter_button:Button = find_child("filter_button")
@onready var grouping_button:Button = find_child("grouping_button")
@onready var sort_by_button:Button = find_child("sort_by_button")
@onready var add_asset_button:Button = find_child("add_asset_button")


@onready var settings_button:Button = find_child("settings_button")

@onready var assets_tree: Tree = %assets_tree
							
var asset_library := MAssetTable.get_singleton()
var current_selection := [] #array of collection name


static var thumbnail_manager 

func _ready():	
	#############
	## GLOBALS ##
	#############
	if AssetIO.asset_placer==null:
		AssetIO.asset_placer = self
	thumbnail_manager = ThumbnailManager.new()
	add_child(thumbnail_manager)
		
	asset_library.tag_set_name(1, "hidden")
	asset_library.finish_import.connect(func(_arg): 
		assets_changed.emit(_arg)
	)	
	assets_changed.connect(func(_who):
		regroup()
	)			
	
	asset_place_control.assets_tree = assets_tree
	asset_filter_control.assets_tree = assets_tree
	
	popup_button_group = ButtonGroup.new()
	popup_button_group.allow_unpress = true
	for button:Button in [asset_type_filter_button, filter_button, grouping_button, sort_by_button, add_asset_button ]:
		button.button_group = popup_button_group
	
	assets_tree.item_activated.connect(asset_place_control.add_asset_to_scene_from_assets_tree_selection_with_confirmation)			
	assets_tree.item_mouse_selected.connect(asset_place_control.validate_place_button)		
	
func regroup():
	assets_tree.regroup_tree()
	
func add_asset_finished(do_regroup = true):
	add_asset_button.button_pressed = false
	if do_regroup:
		regroup()
		
func _can_drop_data(at_position: Vector2, data: Variant):		
	if "files" in data and ".glb" in data.files[0]:
		return true

func _drop_data(at_position, data):		
	for file in data.files:
		AssetIO.glb_load(file)
		
#region Debug	
#########
# DEBUG #
#########		
func init_debug_tags():
	var groups = {"colors": [0,1,2], "sizes":[3,4,5], "building_parts": [6,7,8,9]}   #data.categories
	var tags = ["red", "green", "blue", "small", "medium", "large", "wall", "floor", "roof", "door"]#data.tags		
	asset_library.tag_set_name(0, "single_item_collection")
	asset_library.tag_set_name(1, "hidden")
	for tag in tags:
		if asset_library.tag_get_id(tag) == -1:
			for j in 256:
				if j < 2: continue #0: single_item_collection, 1: hidden
				if asset_library.tag_get_name(j) == "":
					asset_library.tag_set_name(j, tag)
					break
			#asset_library.tag_add(tag)					
	for group in groups:
		if not asset_library.group_exist(group):			
			asset_library.group_create(group)
		for i in groups[group]:				
			var tag_name = tags[i]
			var tag_id = asset_library.tag_get_id(tag_name)
			asset_library.group_add_tag(group, tag_id)			
	asset_library.save()	
#endregion

#####################
## SETTINGS WINDOW ##
#####################
func open_settings_window(tab, data):
	if tab == "tag":
		settings_button.button_pressed = true
		settings_button.settings.select_tab("manage_tags")
		settings_button.settings.manage_tags_control.select_collection(data)		

func on_main_screen_changed():
	settings_button.button_pressed = false
