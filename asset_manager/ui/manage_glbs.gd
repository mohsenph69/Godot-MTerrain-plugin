@tool
extends Control

@onready var glb_tree:Tree = find_child("glb_tree")
@onready var glb_details:ItemList = find_child("glb_details")

var import_info = MAssetTable.get_singleton().import_info
var asset_library = MAssetTable.get_singleton()

func _ready():
	visibility_changed.connect(init_tree)
	glb_tree.set_column_expand(1, false)
	glb_tree.create_item()
	glb_tree.item_selected.connect(func():
		var glb_path = glb_tree.get_selected().get_text(0)				
		glb_details.clear()
		for collection_name in import_info[glb_path].keys():
			if "__" in collection_name: continue
			var thumbnail_path = str("res://massets/thumbnails/", import_info[glb_path][collection_name].id, ".png")		
			var texture = load(thumbnail_path) if FileAccess.file_exists(thumbnail_path) else null
			glb_details.add_item(collection_name, texture)
	)
	glb_tree.button_clicked.connect(func(item:TreeItem, column, id, mouse_button_index):
		var glb_path = item.get_text(0)
		for collection in import_info[glb_path].keys():
			if "__" in collection: continue
			var collection_id = import_info[glb_path][collection].id
			if asset_library.has_collection(collection_id):
				for mesh_item_id in import_info[glb_path][collection].mesh_items.values():
					if asset_library.has_mesh_item(mesh_item_id):
						asset_library.remove_mesh_item(mesh_item_id)										
				asset_library.remove_collection(collection_id)
		import_info.erase(glb_path)		
		init_tree()
	)
	
func init_tree():
	var root := glb_tree.get_root()
	for child in root.get_children():
		root.remove_child(child)
	
	for glb_path in import_info.keys():
		if glb_path.begins_with("__"): continue
		var item = root.create_child()
		item.set_text(0, glb_path)		
		var image := Image.load_from_file("res://addons/m_terrain/icons/icon_close.svg")
		image.resize(32,32)
		var texture := ImageTexture.create_from_image(image)				
		texture.get_image().resize(12,12)
		item.add_button(1, texture)
		
		
	
