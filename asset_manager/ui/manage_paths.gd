@tool
extends Tree
var material_blend_item

@onready var import_info = MAssetTable.get_singleton().import_info

func _ready():	
	set_column_expand(0, false)
	set_column_custom_minimum_width(0, 200)
	#set_column_expand(1, false)
	
	var root := create_item()
	var settings = import_info["__settings"] if import_info.has("__settings") else null
	if settings:
		for key in import_info["__settings"].keys():					
			var item = root.create_child()	
			item.set_text(0, key)
			item.set_editable(0,false)	
			var data = import_info["__settings"][key]
			if data.type == TYPE_STRING:
				if data.hint == "path_global":					
					item.set_text(1, data.value)	
					item.set_editable(1,true)		
					var open_icon = preload("res://addons/m_terrain/icons/open.svg")
					item.add_button(1, open_icon)	
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
	if not "__settings" in import_info:
		import_info["__settings"] = {}
	import_info["__settings"]["Materials blend file"] = {"value": path, "type":TYPE_STRING, "hint":"path_global"}
	MAssetTable.save()
	
