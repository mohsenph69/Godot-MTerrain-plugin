@tool
extends Popup

signal replace_material_requested

@onready var cancel_button:Button = find_child("cancel_button")
@onready var replace_button:Button = find_child("replace_button")
@onready var original_item_tree:Tree = find_child("original_item_tree")
@onready var material_list_tree:Tree = find_child("material_list_tree")
@onready var material_table := MMaterialTable.get_singleton()

var original_material_id: int
var new_material: String

var filesystem

func _ready():
	close_requested.connect(queue_free)
	cancel_button.pressed.connect(queue_free)
	replace_button.pressed.connect(func():
		replace_material_requested.emit(original_material_id, new_material)
		queue_free()
	)
	
	original_item_tree.set_column_expand(0,false)
	original_item_tree.set_column_expand(1,false)	
	original_item_tree.set_column_custom_minimum_width(0, 36)
	original_item_tree.set_column_custom_minimum_width(1, 36)	
	
	var original_item = original_item_tree.create_item()
	original_item.set_text(0, str(original_material_id))
	original_item.set_metadata(0, original_material_id)
	original_item.set_icon(1, AssetIO.get_thumbnail( AssetIO.get_thumbnail_path(original_material_id, false)))
	original_item.set_text(2, material_table.table[original_material_id])
		
	material_list_tree.set_column_expand(0,false)
	material_list_tree.set_column_expand(1,false)	
	material_list_tree.set_column_custom_minimum_width(0, 36)
	material_list_tree.set_column_custom_minimum_width(1, 36)	
	
	material_list_tree.item_selected.connect(func():
		new_material = material_list_tree.get_selected().get_metadata(0)				
	)
	var root = material_list_tree.create_item()
	var base_path = "res://massets/materials/"
	filesystem  = EditorInterface.get_resource_filesystem()
	for file in DirAccess.get_files_at(base_path):
		if not filesystem.get_file_type(base_path + file) in  ["StandardMaterial3D", "ShaderMaterial", "ORMMaterial3D"]: 
			continue			
		var material_item = root.create_child()
		material_item.set_metadata(0, base_path.path_join(file))
		var id = material_table.table.find_key(base_path.path_join(file))
		if id != null:
			material_item.set_icon(1, AssetIO.get_thumbnail( AssetIO.get_thumbnail_path(id, false)))		
		material_item.set_text(0, str(id))		
		material_item.set_text(2, file)
		
		
	
