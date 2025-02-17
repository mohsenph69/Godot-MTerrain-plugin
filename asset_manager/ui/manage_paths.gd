@tool
extends Tree
var material_blend_item

@onready var import_info = MAssetTable.get_singleton().import_info

func _ready():	
	set_column_expand(0, false)
	set_column_custom_minimum_width(0, 200)
	#set_column_expand(1, false)
	
	var root := create_item()
	material_blend_item = root.create_child()	
	material_blend_item.set_text(0, "Materials blend file")
	material_blend_item.set_editable(0,false)	
	var material_blend_path = import_info["__blend_files"]["__materials"] if "__materials" in import_info["__blend_files"] else "(...)"
	material_blend_item.set_text(1, material_blend_path)	
	material_blend_item.set_editable(1,true)		
	var open_icon = preload("res://addons/m_terrain/icons/open.svg")
	material_blend_item.add_button(1, open_icon)	
	item_edited.connect(on_item_edited)
	button_clicked.connect(on_button_clicked)

func on_item_edited():
	var item = get_edited()	
	if item == material_blend_item:
		update_material_blend_path(item.get_text(1))
		
func on_button_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int):
	if item == material_blend_item:
		var dialog := EditorFileDialog.new()
		add_child(dialog)
		dialog.access = EditorFileDialog.ACCESS_FILESYSTEM		
		# = "Replace %s as materials blend file" % item.get_text(1).get_file()		
		if DirAccess.dir_exists_absolute(item.get_text(1).get_base_dir()):					
			dialog.current_dir = item.get_text(1).get_base_dir() 								
		dialog.add_filter("*.blend", "blender file")
		dialog.display_mode = EditorFileDialog.DISPLAY_LIST
		dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		dialog.file_selected.connect(func(path): 			
			item.set_text(1,path))								
		dialog.file_selected.connect(update_material_blend_path)								
		dialog.popup_file_dialog()									

func update_material_blend_path(path):			
	if not "__blend_files" in import_info:
		import_info["__blend_files"] = {}
	import_info["__blend_files"]["__materials"] = path
	MAssetTable.save()
	
