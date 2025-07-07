@tool
extends Window

const max_lod:int=10

@onready var path_selector:=$FileDialog
@onready var mesh_dir:=$vb/hb/mesh_dir
@onready var meshlod_dir:=$vb/hb2/meshlod_dir
@onready var parsed_meshes_info:=$vb/Panel/parsed_meshes_info
@onready var fill_all_checkbox:=$vb/hb3/fill_all
@onready var fill_between_checkbox:=$vb/hb3/fill_between
@onready var lodcutoff_spinbox:=$vb/hb3/lodcutoff

@onready var root_control:=$vb
@onready var no_hide:=[$vb/sep,$vb/Label,$vb/hb]

var mesh_regex:RegEx = RegEx.create_from_string("(.*)[_|\\s]lod[_|\\s]?(\\d+)")
const config_file_name:="parse_mmeshlod.cfg"
var is_mesh_dir_path_mode:=false
var parsed_meshes:Dictionary

func select_path_pressed(mesh_dir_path:bool)->void:
	is_mesh_dir_path_mode = mesh_dir_path
	path_selector.visible = true

func _on_file_dialog_dir_selected(dir: String) -> void:
	if is_mesh_dir_path_mode:
		mesh_dir.text = dir
		parse_meshes(dir)
	else: meshlod_dir.text = dir

func clear_data():
	parsed_meshes_info.text = ""
	meshlod_dir.text = ""
	

func get_avilable_lod(mesh_name:String)->PackedInt32Array:
	var out:PackedInt32Array
	if not parsed_meshes.has(mesh_name): return out
	var lod_names:PackedStringArray = parsed_meshes[mesh_name]
	for lod in range(lod_names.size()):
		if not lod_names[lod].is_empty():
			out.push_back(lod)
	return out

func update_parsed_mesh_info_text()->void:
	var t:String=""
	for n in parsed_meshes:
		var lods = get_avilable_lod(n)
		t += " -" + n + "  [table=1][cell border=dark_green bg=DIM_GRAY]"
		for i in range(lods.size()):
			if i!=0: t+=","
			t += str(lods[i])
		t+= "[/cell][/table]\n"
	parsed_meshes_info.text = t

func load_config_file(mesh_dir:String)->void:
	var cpath = mesh_dir.path_join(config_file_name)
	if FileAccess.file_exists(cpath):
		var cfile:=ConfigFile.new()
		if cfile.load(cpath)==OK:
			var save_path = cfile.get_value("parse_mmeshlod","save_path","")
			fill_all_checkbox.button_pressed = cfile.get_value("parse_mmeshlod","fill_all",fill_all_checkbox.button_pressed)
			fill_between_checkbox.button_pressed = cfile.get_value("parse_mmeshlod","fill_between",fill_between_checkbox.button_pressed)
			lodcutoff_spinbox.value = cfile.get_value("parse_mmeshlod","cutoff_lod",lodcutoff_spinbox.value)
			meshlod_dir.text = save_path

func save_config_file(mesh_dir:String)->void:
	var cfile:=ConfigFile.new()
	cfile.set_value("parse_mmeshlod","save_path",meshlod_dir.text)
	cfile.set_value("parse_mmeshlod","fill_all",fill_all_checkbox.button_pressed)
	cfile.set_value("parse_mmeshlod","fill_between",fill_between_checkbox.button_pressed)
	cfile.set_value("parse_mmeshlod","cutoff_lod",lodcutoff_spinbox.value)
	if cfile.save(mesh_dir.path_join(config_file_name))!=OK:
		printerr("Error saving config file")

func set_mesh_setting_visibility(is_showing:bool)->void:
	for child in root_control.get_children():
		if no_hide.find(child)==-1:
			child.visible = is_showing

func parse_meshes(dir_path:String)->void:
	clear_data()
	load_config_file(dir_path)
	if not DirAccess.dir_exists_absolute(dir_path):
		set_mesh_setting_visibility(false)
		return
	var file_names:PackedStringArray= DirAccess.get_files_at(dir_path)
	for f:String in file_names:
		var fpath:=dir_path.path_join(f)
		if not ResourceLoader.exists(fpath): continue
		var mres = ResourceLoader.load(fpath)
		if not mres is Mesh: continue
		var file_name:= f
		var lod:int = 0
		var search_result: = mesh_regex.search(f)
		if search_result:
			file_name = search_result.strings[1]
			lod = search_result.strings[2].to_int()
		var lod_names:PackedStringArray
		if parsed_meshes.has(file_name):
			lod_names = parsed_meshes[file_name]
		if lod_names.size() <= lod:
			lod_names.resize(lod+1)
		lod_names[lod] = f
		parsed_meshes[file_name] = lod_names
	update_parsed_mesh_info_text()
	set_mesh_setting_visibility(parsed_meshes.size()!=0)

func update_mmeshlod()->void:
	var mesh_dir_path:String = mesh_dir.text
	var save_path:String = meshlod_dir.text
	if save_path.is_empty():
		printerr("Save path is empty")
		return
	if not save_path.is_absolute_path():
		printerr("Save path is not not valid")
		return
	if not DirAccess.dir_exists_absolute(save_path):
		printerr("Save path does not exist")
		return
	save_config_file(mesh_dir_path)
	var fill_all:bool=fill_all_checkbox.button_pressed
	var fill_between:bool=fill_between_checkbox.button_pressed
	var lodcutoff:int=lodcutoff_spinbox.value
	for k in parsed_meshes:
		var sm := save_path.path_join(k+".res")
		var mmesh:=MMeshLod.new()
		var meshes:Array
		var meshe_names:PackedStringArray = parsed_meshes[k]
		var mesh_array_size:int = meshe_names.size()
		if fill_all: mesh_array_size = max_lod
		if lodcutoff!=-1 and lodcutoff>mesh_array_size: mesh_array_size=lodcutoff+1
		var last_valid_mesh:Mesh=null
		for i in range(mesh_array_size):
			var current_mesh:Mesh=null
			if i<meshe_names.size():
				var mpath:=mesh_dir_path.path_join(meshe_names[i])
				print("Lading mesh ",mpath)
				if ResourceLoader.exists(mpath): current_mesh=ResourceLoader.load(mpath)
				if current_mesh==null and fill_between: current_mesh=last_valid_mesh
			else:
				current_mesh=last_valid_mesh
			meshes.push_back(current_mesh)
			if current_mesh!=null: last_valid_mesh = current_mesh
		mmesh.meshes = meshes
		ResourceSaver.save(mmesh,sm)
		mmesh.take_over_path(sm)
	queue_free()













#end
