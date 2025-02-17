@tool
extends VBoxContainer

signal collection_activated

@onready var group_button:Button = find_child("group_button")
@onready var group_container = find_child("group_container")
@onready var group_list:ItemList = find_child("group_list")
var asset_placer:Control

func _ready():
	if get_parent() is Control:
		get_parent().connect("mouse_entered",revalidate_icons)
	group_button.toggled.connect(func(toggle_on):
		group_container.visible = toggle_on	
	)
	group_list.clear()			
	var action_menu = load("res://addons/m_terrain/asset_manager/asset_placer_action_menu.gd").new()
	action_menu.item_list = group_list
	group_list.add_child(action_menu)
	group_list.item_clicked.connect(Callable(action_menu,"item_clicked"))
	
func set_group(group_name):
	name = group_name
	group_button.text = group_name

func add_item(item_name, item):
	var i = group_list.add_item(item_name)	
	group_list.set_item_tooltip(i, item_name)
	group_list.set_item_metadata(i, item)	
	var asset_library = MAssetTable.get_singleton()
	if item in asset_library.collections_get_by_type(MAssetTable.ItemType.PACKEDSCENE):
		group_list.set_item_custom_bg_color(i, asset_placer.ITEM_COLORS.PACKEDSCENE) # Color(1,0.5,0,0.15))		
	if item in asset_library.collections_get_by_type(MAssetTable.ItemType.HLOD):
		group_list.set_item_custom_bg_color(i, asset_placer.ITEM_COLORS.HLOD) #Color(0,1,0.8,0.15))
	group_list.set_item_tooltip(i, str(item_name))
	# Now any item has the potential to generate icon
	# if asset Table get_asset_thumbnails_path return empty path this means
	# currently this type is not supported
	set_icon(i) # should be called last	

## Set icon with no dely if thumbnail is valid
func set_icon(item_index:int)->void:
	var current_item_collection_id:int= group_list.get_item_metadata(item_index)
	var tex:Texture2D= ThumbnailManager.get_valid_thumbnail(current_item_collection_id)
	var type = MAssetTable.get_singleton().collection_get_type(current_item_collection_id)
	if tex != null:
		group_list.set_item_icon(item_index,tex)
		group_list.set_item_text(item_index, "")
		return
	if type==MAssetTable.MESH:
		var _cmesh = MAssetMesh.get_collection_merged_mesh(current_item_collection_id,true)
		if _cmesh:		
			ThumbnailManager.thumbnail_queue.push_back({"resource": _cmesh, "caller": item_index, "callback": update_thumbnail, "collection_id": current_item_collection_id})	
	elif type==MAssetTable.DECAL:
		var dtex:=ThumbnailManager.generate_decal_texture(current_item_collection_id)
		if dtex:
			group_list.set_item_icon(item_index,dtex)
			group_list.set_item_text(item_index, "")
	# For HLOD it should be generated at bake time we don't generate that here
	# so normaly it should be grabed by the first step

func update_thumbnail(data):
	if not data.texture is Texture2D:
		push_warning("thumbnail error: ", group_button.name, " item ", data.caller)
	var asset_library = MAssetTable.get_singleton()
	var thumbnail_path = asset_library.get_asset_thumbnails_path(data.collection_id)
	### Updating Cache
	ThumbnailManager.save_thumbnail(data.texture.get_image(), thumbnail_path)
	## This function excute with delay we should check if item collection id is not changed	
	if group_list.get_item_metadata(data.caller) == data.collection_id:			
		group_list.set_item_icon(data.caller,data.texture)
		group_list.set_item_text(data.caller, "")

func revalidate_icons():
	var at:=MAssetTable.get_singleton()
	for i in group_list.item_count:
		var cid = group_list.get_item_metadata(i)
		var thum_path:String=at.get_asset_thumbnails_path(cid)
		if thum_path.is_empty(): return # not supported
		var modify_time=at.collection_get_modify_time(cid)
		if not FileAccess.file_exists(thum_path) or FileAccess.get_modified_time(thum_path) < modify_time:
			set_icon(i)
