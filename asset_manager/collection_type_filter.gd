@tool
extends Tree
signal asset_type_filter_changed

@onready var asset_placer:=$"../../../.."

var selected_types:int = 0
const OPTIONS = {MAssetTable.ItemType.MESH: "Mesh", MAssetTable.ItemType.HLOD:"HLOD", MAssetTable.ItemType.PACKEDSCENE: "PackedScene", MAssetTable.ItemType.DECAL: "Decal"}
func _init():		

	var refresh_tex = load("res://addons/m_terrain/icons/rotation.svg")
	var root = create_item()	
	for id in OPTIONS:
		var item = root.create_child()		
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_text(0, OPTIONS[id])
		item.set_metadata(0, id)
		item.set_checked(0, true)
		item.set_editable(0,true)
		item.collapsed = true		
		if id!=MAssetTable.ItemType.MESH:									
			item.add_button(0,refresh_tex,-1,false,"Refresh base on file in Directory")
			item.set_metadata(0, id)
		selected_types |= id
	
	asset_type_filter_changed.emit.call_deferred(selected_types)		
	item_edited.connect(func():
		var id = get_edited().get_metadata(0)
		var current_item = get_edited()
		if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_SHIFT):
			current_item.set_checked(0,true)
			selected_types = id
			for item in get_root().get_children():
				if item!=current_item: item.set_checked(0,false)
		else:
			var checked = current_item.is_checked(0)
			if checked:
				selected_types = selected_types | id
			else:
				selected_types = selected_types & ~id
		asset_type_filter_changed.emit(selected_types)		
	)
	
	button_clicked.connect(_on_button_clicked)

func _on_button_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int) -> void:
	if MAssetTable.get_singleton():
		
		MAssetTable.get_singleton().auto_asset_update_from_dir( item.get_metadata(0) )
		asset_placer.regroup()
