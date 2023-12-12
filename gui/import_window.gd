@tool
extends Window

@onready var fileDialog = $FileDialog
@onready var fileDialog_save_folder = $FileDialog_save
@onready var fileDialog_tmp_folder = $FileDialog_tmp
@onready var tmp_folder_line = $VBoxContainer/tmp/tmp_folder_line
@onready var tmp_container = $VBoxContainer/tmp
@onready var region_container = $VBoxContainer/HBoxContainer2
@onready var save_folder_line = $VBoxContainer/save/save_folder_line
@onready var select_file_line: = $VBoxContainer/HBoxContainer/filepath_line
@onready var image_dimension_root: = $VBoxContainer/image_dimension
@onready var image_width_line: = $VBoxContainer/image_dimension/width
@onready var image_height_line: = $VBoxContainer/image_dimension/height
@onready var min_height_root:= $VBoxContainer/min_height
@onready var max_height_root:= $VBoxContainer/max_height
@onready var unform_name_line:=$VBoxContainer/uniform_name/uniform_name_line
@onready var is_heightmap_checkbox:= $VBoxContainer/is_heightmap_checkbox
@onready var min_height_line := $VBoxContainer/min_height/min_height_line
@onready var max_height_line := $VBoxContainer/max_height/max_height_line
@onready var region_size_line:= $VBoxContainer/HBoxContainer2/region_size_line
@onready var width_line:= $VBoxContainer/image_dimension/width
@onready var height_line:= $VBoxContainer/image_dimension/height
@onready var image_format_option:=$VBoxContainer/uniform_name2/image_format_option
@onready var flips_container := $VBoxContainer/flips
@onready var flip_x_checkbox := $VBoxContainer/flips/flip_x
@onready var flip_y_checkbox := $VBoxContainer/flips/flip_y

const format_RF_index = 8

var file_path:String
var ext:String
var save_path:String
var tmp_path:String
var region_size:int
var unifrom_name:String
var width:int
var height:int
var min_height:float
var max_height:float
var image_format:int
var flip_x:bool
var flip_y:bool

var is_heightmap:=false

func _on_close_requested():
	queue_free()


func _on_button_button_down():
	fileDialog.visible = true

func _on_file_dialog_files_selected(paths):
	var path:String = paths[0]
	select_file_line.text = path 
	_on_filepath_line_text_changed(path)


func _on_filepath_line_text_changed(new_text:String):
	var ext = new_text.get_extension()
	image_dimension_root.visible = ext == "r16"
	var x = get_integer_inside_string("x",new_text)
	var y = get_integer_inside_string("y",new_text)
	var is_tiled = (not x==-1 and not y==-1)
	flips_container.visible = is_tiled
	tmp_container.visible = is_tiled
	region_container.visible = not is_tiled


func _on_check_button_toggled(button_pressed):
	min_height_root.visible = button_pressed
	max_height_root.visible = button_pressed
	unform_name_line.editable = not button_pressed
	is_heightmap = button_pressed
	if(button_pressed):
		unform_name_line.text = "heightmap"
		image_format_option.select(format_RF_index)
		image_format_option.disabled = true
	elif unform_name_line.text == "heightmap":
		unform_name_line.text = ""
		image_format_option.disabled = false


func _on_save_folder_button_pressed():
	fileDialog_save_folder.visible = true

func _on_file_dialog_save_dir_selected(dir):
	save_folder_line.text = dir

func _on_file_dialog_tmp_dir_selected(dir):
	tmp_folder_line.text = dir


func _on_tmp_folder_button_pressed():
	fileDialog_tmp_folder.visible = true

func get_integer_inside_string(prefix:String,path:String)->int:
	path = path.to_lower()
	var reg = RegEx.new()
	reg.compile(prefix+"(\\d+)")
	var result := reg.search(path)
	if not result:
		return -1
	return result.strings[1].to_int()

func _on_import_pressed():
	file_path= select_file_line.text
	ext = select_file_line.text.get_extension()
	save_path= save_folder_line.text
	region_size = region_size_line.text.to_int()
	unifrom_name = unform_name_line.text
	width = width_line.text.to_int()
	height = height_line.text.to_int()
	min_height = min_height_line.text.to_float()
	max_height = max_height_line.text.to_float()
	image_format = image_format_option.get_selected_id()
	flip_x = flip_x_checkbox.button_pressed
	flip_y = flip_y_checkbox.button_pressed
	if unifrom_name == "":
		printerr("Uniform name is empty")
		return
	var x = get_integer_inside_string("x",file_path)
	var y = get_integer_inside_string("y",file_path)
	#In this case there is no tile and we should tile that
	if(x==-1 or y==-1):
		import_no_tile()
	else: #And in this case there is tiled already and regions size will ignored
		tmp_path = tmp_folder_line.text
		if not DirAccess.dir_exists_absolute(tmp_path) or tmp_path.is_empty():
			printerr("tmp folder does not exist")
			return
		import_tile()

func is_valid_2n_plus_one(input:int):
	if input<3:
		return false
	input -= 1
	while true:
		if input == 1:
			return true
		if input%2!=0:
			return false
		input /=2

func is_power_of_two(input:int):
	while true:
		if input == 1:
			return true
		if input%2!=0:
			return false
		input /=2

func import_no_tile():
	if(region_size<33):
		printerr("Region size can not be smaller than 33")
		return
	if(not is_valid_2n_plus_one(region_size)):
		printerr("Region size in non tiled must be 2^n + 1, like 65, 129, 257 ...")
		return
	var img:Image
	if ext=="r16":
		img=MRaw16.get_image(file_path,width,height,min_height,max_height,false)
	else:
		img = Image.load_from_file(file_path)
	if not img:
		printerr("Can not load image")
		return
	var img_size = img.get_size()
	if ext!="r16" and is_heightmap:
		img.convert(Image.FORMAT_RF)
		var data = img.get_data().to_float32_array()
		for i in range(0,data.size()):
			data[i] *= (max_height - min_height)
			data[i] += min_height
		img = Image.create_from_data(img_size.x,img_size.y,false,Image.FORMAT_RF, data.to_byte_array())
	var region_grid_size:= Vector2i()
	region_grid_size.x = ceil(float(img_size.x)/(region_size))
	region_grid_size.y = ceil(float(img_size.y)/(region_size))
	var total_regions = region_grid_size.x*region_grid_size.y
	if(total_regions>8192):
		printerr("make region size bigger, too many regions, region count: "+str(total_regions))
		return
	for y in range(0, region_grid_size.x):
		for x in range(0, region_grid_size.y):
			var r_save_name:String = unifrom_name+"_x"+str(x)+"_y"+str(y)+".res"
			var r_save_path:String = save_path.path_join(r_save_name)
			var pos:=Vector2i(x,y)
			pos *= (region_size-1)
			var rect = Rect2i(pos, Vector2i(region_size,region_size));
			var region_img:= img.get_region(rect)
			if(image_format>=0 and not is_heightmap):
				region_img.convert(image_format)
			ResourceSaver.save(region_img, r_save_path)
			print("saving ", r_save_path)
	queue_free()

func get_file_path(x:int,y:int,path_pattern:String)->String:
	var regx = RegEx.new()
	var regy = RegEx.new()
	var patternx = "(?i)(x)(\\d+)"
	var paterrny = "(?i)(y)(\\d+)"
	regx.compile(patternx)
	regy.compile(paterrny)
	var resx = regx.search(path_pattern)
	var resy = regy.search(path_pattern)
	## This is because in some cases we have x1 in other cases we have x01
	for i in range(1,4):
		var digit_pattern = "%0"+str(i)+"d"
		var xstr = digit_pattern % x
		var ystr = digit_pattern % y
		var sub = regx.sub(path_pattern, resx.strings[1]+xstr)
		sub = regy.sub(sub, resy.strings[1]+ystr)
		if FileAccess.file_exists(sub):
			return sub
	return ""

func import_tile():
	var tiled_files:Dictionary
	var x:int=0
	var y:int=0
	var x_size = 0
	var y_size = 0
	while true:
		var r_path = get_file_path(x,y,file_path)
		if(r_path == ""):
			x = 0
			y += 1
			r_path = get_file_path(x,y,file_path)
			if(r_path == ""):
				break
		tiled_files[Vector2i(x,y)] = r_path
		if x > x_size: x_size = x
		if y > y_size: y_size = y
		x+=1
	if flip_y:
		var tmp:Dictionary
		var j = y_size
		var oj = 0
		while  j>= 0:
			for i in range(0,x_size+1):
				tmp[Vector2i(i,oj)] = tiled_files[Vector2i(i,j)]
			j-=1
			oj+=1
		tiled_files = tmp
	if flip_x:
		var tmp:Dictionary
		var i = y_size
		var oi = 0
		while  i>= 0:
			for j in range(0,y_size+1):
				tmp[Vector2i(oi,j)] = tiled_files[Vector2i(i,j)]
			i-=1
			oi+=1
		tiled_files = tmp
	for i in range(0,x_size+1):
		for j in range(0,y_size+1):
			var r_path = tiled_files[Vector2i(i,j)]
			var r_save_name:String = unifrom_name+"_x"+str(i)+"_y"+str(j)+".res"
			var r_save_path:String = tmp_path.path_join(r_save_name)
			var img:Image
			if ext == "r16":
				img=MRaw16.get_image(r_path,0,0,min_height,max_height,false)
			else:
				img = Image.load_from_file(r_path)
			if not img:
				printerr("Can not load image")
				return
			if img.get_size().x != img.get_size().y:
				printerr("In tiled mode image width and height should be equal")
				return
			if not is_power_of_two(img.get_size().x):
				printerr("In tiled mode image height and width should be in power of two")
				return
			var img_size = img.get_size().x
			if ext!="r16" and is_heightmap:
				img.convert(Image.FORMAT_RF)
				var data = img.get_data().to_float32_array()
				for d in range(0,data.size()):
					data[d] *= (max_height - min_height)
					data[d] += min_height
				img = Image.create_from_data(img_size,img_size,false,Image.FORMAT_RF, data.to_byte_array())
			if(image_format>=0 and not is_heightmap):
				img.convert(image_format)
			print("path ", img.get_path())
			ResourceSaver.save(img, r_save_path)
	### Now Correcting the edges
	correct_edges(unifrom_name, tmp_path)
	queue_free()


func get_img_or_black(x:int,y:int,u_name:String,dir:String,size:Vector2i,format:int)->Image:
	var file_name = u_name + "_x"+str(x)+"_y"+str(y)+".res"
	var path = dir.path_join(file_name)
	if ResourceLoader.exists(path):
		return load(path)
	else:
		var img:= Image.create(size.x,size.y,false,format)
		img.fill(Color(-10000000000, 0,0))
		return img

func correct_edges(u_name:String, dir:String):
	var x:int =0
	var y:int =0
	while true:
		var file_name = u_name + "_x"+str(x)+"_y"+str(y)+".res"
		var path = dir.path_join(file_name)
		if !ResourceLoader.exists(path):
			x = 0
			y+=1
			file_name = u_name + "_x"+str(x)+"_y"+str(y)+".res"
			path = dir.path_join(file_name)
			if !ResourceLoader.exists(path):
				break
		var img:Image = load(path)
		var size = img.get_size()
		var right_img:Image = get_img_or_black(x+1,y,u_name,dir,size,img.get_format())
		var bottom_img:Image = get_img_or_black(x,y+1,u_name,dir,size,img.get_format())
		var right_bottom_img:Image = get_img_or_black(x+1,y+1,u_name,dir,size,img.get_format())
		img = img.get_region(Rect2i(0,0,size.x+1,size.y+1))
		##Correct right side
		for j in range(0,size.y):
			var col = right_img.get_pixel(0, j)
			img.set_pixel(size.x, j, col)
		##Correct bottom side
		for i in range(0,size.x):
			var col = bottom_img.get_pixel(i, 0)
			img.set_pixel(i , size.y, col)
		##Correct right bottom corner
		var col = right_bottom_img.get_pixel(0,0)
		img.set_pixel(size.x , size.y, col)
		var save_name = u_name + "_x"+str(x)+"_y"+str(y)+".res"
		var r_save_path = save_path.path_join(save_name)
		ResourceSaver.save(img, r_save_path)
		print("svae ", r_save_path)
		x+=1











