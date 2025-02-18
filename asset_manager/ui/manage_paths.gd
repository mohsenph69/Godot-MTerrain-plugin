@tool
extends Tree
var material_blend_item

var import_info

func _ready():	
	var asset_library = MAssetTable.get_singleton()
	asset_library.clear_import_info_cache()
	import_info = asset_library.import_info
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
					item_edited.connect(update_setting)
					button_clicked.connect(on_button_clicked)
		
func on_button_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int):	
	var setting_name = item.get_text(0)
	import_info = MAssetTable.get_singleton().import_info	
	if import_info["__settings"][setting_name].hint == "path_global":
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
		dialog.file_selected.connect(func(path):
			item.set_text(1, path)
			update_setting.call_deferred(item)
		)								
		dialog.popup_file_dialog()	
											
func update_setting(item = get_edited()):				
	if not "__settings" in import_info:
		import_info["__settings"] = {}
	var setting_name = item.get_text(0)
	var value
	match int(import_info["__settings"][setting_name].type):
		TYPE_STRING: value = item.get_text(1)
		TYPE_INT, TYPE_FLOAT: value = item.get_range(1)				
	import_info["__settings"][setting_name] = {"value": value, "type":TYPE_STRING, "hint":"path_global"}
	MAssetTable.save()	
	
