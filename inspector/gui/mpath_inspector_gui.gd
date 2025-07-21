@tool
extends Control

var no_icon_tex:Texture2D = preload("res://addons/m_terrain/icons/no_images.png")
@onready var point_count_lable:=$point_count_lable
var lod_reg:=RegEx.create_from_string("[_]?lod[\\d]+")

var selection_info:Label

static var override_clipboard:MCurveOverrideData=null
static var is_override_clipboard_conn:bool

# remebering this to open the correct if node deselcted
static var selected_child:Node

var is_started:=false

var gizmo:EditorNode3DGizmoPlugin
var ur:EditorUndoRedoManager

var current_path:MPath
var current_curve:MCurve
var current_modify_node=null

var connection_mode :=true
var mesh_mode:=true

var child_selector:OptionButton
var items:ItemList
var connection_tab:Button
var intersection_tab:Button
var exclude_connection_btn:Button


# Override copy past
var copy_btn:Button
var past_btn:Button

# Instance Setting
var instance_add_remove_btn:Button
var instance_rev_offset_checkbox:CheckBox
var instance_mirror_checkbox:CheckBox
var instance_start_offset_slider:Slider
var instance_end_offset_slider:Slider
var instance_rand_remove_slider:Slider
var instance_setting_header:Control

enum MODIFY_MODE {
	NONE,
	CURVE_MESH,
	CURVE_INSTANCE,
}

var modify_mode:=MODIFY_MODE.NONE

# Hide on empty
func push_on_warn_lable(msg:String)->void:
	if msg.is_empty():
		$warn_lable.visible = false
		return
	$warn_lable.visible = true
	$warn_lable.text = msg
	$warn_lable/wtimer.start()

func start():
	if is_started: return
	is_started = true
	child_selector = $child_selctor
	items = $itemlist
	items.item_selected.connect(Callable(self,"item_selected"))
	selection_info = $selection_info
	connection_tab = $mesh_header/connection_tab
	intersection_tab = $mesh_header/intersection_tab
	exclude_connection_btn = $button_header/exclude_connection
	connection_tab.connect("pressed",Callable(self,"change_tab").bind(true))
	intersection_tab.connect("pressed",Callable(self,"change_tab").bind(false))
	$button_header/clear_override.connect("button_up",Callable(self,"clear_override"))
	exclude_connection_btn.connect("button_up",Callable(self,"exclude_connection"))
	$mesh_mode_option.connect("item_selected",Callable(self,"mesh_mode_selected"))
	if not gizmo: printerr("Gizmo is NULL")
	gizmo.connect("selection_changed",Callable(self,"update_curve_item_selection"))
	gizmo.connect("point_commit",Callable(self,"update_curve_lenght_info"))
	# Copy past Override
	copy_btn=$copy_past_header/copy_btn
	past_btn=$copy_past_header/past_btn
	copy_btn.button_up.connect(copy_btn_pressed)
	past_btn.button_up.connect(past_btn_pressed)
	# Instance settings
	instance_add_remove_btn = $add_remove
	instance_rev_offset_checkbox = $instance_setting/reverse_offset/rev_offset_checkbox
	instance_mirror_checkbox = $instance_setting/reverse_offset/mirror_checkbox
	instance_start_offset_slider = $instance_setting/start_offset/slider
	instance_end_offset_slider = $instance_setting/end_offset/slider
	instance_rand_remove_slider = $instance_setting/rand_rm/slider
	instance_setting_header = $instance_setting
	instance_add_remove_btn.connect("button_up",instance_add_remove_element)
	instance_rev_offset_checkbox.connect("toggled",instance_set_flag.bind(MCurveInstanceOverride.FLAG.REVERSE_OFFSET))
	instance_mirror_checkbox.connect("toggled",instance_set_flag.bind(MCurveInstanceOverride.FLAG.MIRROR))
	instance_start_offset_slider.connect("value_changed",instance_set_start_offset)
	instance_end_offset_slider.connect("value_changed",instance_set_end_offset)
	instance_rand_remove_slider.connect("value_changed",instance_set_rand_remove)
	#### End commit to save override
	instance_rev_offset_checkbox.connect("button_up",instance_edit_commit.bind(true))
	instance_mirror_checkbox.connect("button_up",instance_edit_commit.bind(true))
	instance_add_remove_btn.connect("button_up",instance_edit_commit.bind(true))
	instance_start_offset_slider.connect("drag_ended",instance_edit_commit)
	instance_end_offset_slider.connect("drag_ended",instance_edit_commit)
	instance_rand_remove_slider.connect("drag_ended",instance_edit_commit)
	# End Instance settings



func set_path(input:MPath)->void:
	start()
	current_path = input
	current_curve = current_path.curve
	update_curve_lenght_info()
	update_copy_past_selection()
	child_selector.clear()
	child_selector.add_item("ovveride")
	if not input: return
	var children = input.get_children()
	var last_selection_index:=-1
	var i=0
	for child in children:
		if child is MCurveMesh or child is MCurveInstance:
			child_selector.add_item(child.name)
			if child == selected_child:
				last_selection_index = i
			i+=1
	last_selection_index += 1 # ovveride not included
	if last_selection_index!=-1:
		child_selector.select(last_selection_index)
		_on_child_selctor_item_selected(last_selection_index)

func _on_child_selctor_item_selected(index):
	set_modify_gui_visible(false)
	items.clear()
	modify_mode=MODIFY_MODE.NONE
	if index==0 or not current_path:
		selected_child = null
		return
	var cname = child_selector.get_item_text(index)
	var child = current_path.get_node(cname)
	selected_child = child
	if not child: return
	if child is MCurveMesh:
		modify_mode=MODIFY_MODE.CURVE_MESH
		current_modify_node = child
		set_modify_gui_visible(true)
		update_curve_mesh_items()
	if child is MCurveInstance:
		modify_mode=MODIFY_MODE.CURVE_INSTANCE
		current_modify_node = child
		set_modify_gui_visible(true)
		update_curve_instance_items()
		update_curve_instance_selection()

func set_modify_gui_visible(input:bool):
	items.select_mode = ItemList.SELECT_SINGLE
	if not input:
		$mesh_header.visible = false
		$button_header.visible = false
		$mesh_mode_option.visible = false
		$itemlist.visible = false
		instance_setting_header.visible = false
	elif modify_mode==MODIFY_MODE.CURVE_MESH:
		$mesh_header.visible = true
		$button_header.visible = true
		$mesh_mode_option.visible = true
		$itemlist.visible = true
	elif modify_mode==MODIFY_MODE.CURVE_INSTANCE:
		$button_header.visible = true
		$itemlist.visible = true
		instance_setting_header.visible = true

func change_tab(_conn_mod:bool):
	connection_tab.button_pressed = _conn_mod
	intersection_tab.button_pressed = not _conn_mod
	if _conn_mod == connection_mode: return
	connection_mode = _conn_mod
	update_curve_mesh_items()

func update_curve_mesh_items():
	if not current_modify_node: return
	items.clear()
	var ed:=EditorScript.new()
	var preview:EditorResourcePreview= ed.get_editor_interface().get_resource_previewer()
	var count:int = 0
	if not mesh_mode:
		for mat in current_modify_node.materials:
			if not mat:
				items.add_item("empty")
				continue
			var mname:String = mat.get_path().get_file().get_basename()
			if mname.is_empty():
				mname = str(count)
			items.add_item(mname)
			preview.queue_edited_resource_preview(mat,self,"set_icon",count)
			count+=1
		update_curve_item_selection()
		return
	if connection_mode:count = current_modify_node.meshes.size()
	else:count = current_modify_node.intersections.size()
	for i in range(count):
		var mlod:MMeshLod
		if connection_mode: mlod = current_modify_node.meshes[i]
		else: mlod = current_modify_node.intersections[i].mesh
		if not mlod:
			items.add_item("empty")
			continue
		var m:Mesh = mlod.meshes[0]
		if not m:
			items.add_item("empty")
			continue
		var mname:String
		if not m.resource_name.is_empty():
			mname = m.resource_name
		elif m.get_path().find("::") == -1:
			mname = m.get_path().get_file()
		else:
			mname = "Mesh " + str(i)
		mname = lod_reg.sub(mname,"")
		if mname.is_empty():
			mname = str(i)
		items.add_item(mname)
		preview.queue_edited_resource_preview(m,self,"set_icon",i)
	update_curve_item_selection()

func update_curve_instance_items():
	items.clear()
	var element_count = MCurveInstance.get_element_count()
	var current_element:MCurveInstanceElement = null
	var ed:=EditorScript.new()
	var preview:EditorResourcePreview= ed.get_editor_interface().get_resource_previewer()
	for i in range(0,element_count):
		current_element = current_modify_node.get("element_"+str(i))
		var element_name = "Element_"+str(i)
		if current_element:
			if not current_element.name.is_empty():
				element_name = current_element.name
		else:
			element_name += " (Currently Null)"
		var index = items.add_item(element_name,null,true)
		var mesh:Mesh
		if current_element and current_element.mesh:
			for m in current_element.mesh.meshes:
				if m: mesh = m
		if mesh:
			preview.queue_edited_resource_preview(mesh,self,"set_icon",index)
		else:
			items.set_item_icon(index,no_icon_tex)
		

# must be called after update_curve_mesh_items()
func update_curve_lenght_info()->void:
	if not is_instance_valid(current_curve) or not is_instance_valid(current_path): return
	var point_sel:PackedInt32Array = gizmo.get_selected_points32()
	if point_sel.size()==1:
		selection_info.text = "Point " + str(point_sel[0])
		if point_sel[0]!=current_path.get_current_editing_point():
			current_path.set_current_editing_point(point_sel[0])
		return
	if current_path.get_current_editing_point()!=0:
		current_path.set_current_editing_point(0)
	var conn_sel:PackedInt64Array= gizmo.get_selected_connections()
	if conn_sel.size()!=0:
		selection_info.visible = true
		var l:float=0.0
		for cid in conn_sel:
			l += current_curve.get_conn_lenght(cid)
		if conn_sel.size()!=1:
			selection_info.text = "Lenght: %.1fm" %  l
		else:
			selection_info.text = "Lenght: %.1fm (%d)" %  [l,conn_sel[0]]

func update_curve_item_selection():
	update_curve_lenght_info()
	update_copy_past_selection()
	if not current_modify_node or not gizmo: return
	if modify_mode==MODIFY_MODE.CURVE_MESH:
		update_curve_mesh_selection()
	elif modify_mode==MODIFY_MODE.CURVE_INSTANCE:
		update_curve_instance_selection()

func update_copy_past_selection():
	if not is_instance_valid(current_curve) or not is_instance_valid(current_path): return
	var point_sel:PackedInt32Array = gizmo.get_selected_points32()
	var conn_sel:PackedInt64Array= gizmo.get_selected_connections()
	## Copy button
	copy_btn.disabled=not((point_sel.size()==1 and conn_sel.size()==0) or (point_sel.size()==2 and conn_sel.size()==1))
	# past button
	if override_clipboard:
		if is_override_clipboard_conn: past_btn.disabled = conn_sel.size()==0
		else: past_btn.disabled = point_sel.size()==0
	else:
		past_btn.disabled = true

func update_curve_mesh_selection():
	var ids:PackedInt64Array = get_selected_ids()
	var ov_index:int=-100 # some invalide number
	for cid in ids:
		var current_index:int
		if mesh_mode: current_index = current_modify_node.override.get_mesh_override(cid)
		else: current_index = current_modify_node.override.get_material_override(cid)
		if ov_index == -100: ov_index = current_index
		if current_index != ov_index: ## multiple connection is selected with multiple ovverride value
			ov_index = -1
			break
		### Up to this point connection ovveride is same
		ov_index = current_index
	exclude_connection_btn.set_pressed_no_signal(connection_mode and ov_index == -2)
	if ov_index < 0:
		items.deselect_all()
	else:
		items.select(ov_index)

func update_curve_instance_selection():
	# Clear to default sate
	instance_setting_header.visible = false
	var sel_index = items.get_selected_items()
	var total_capacity:int= MCurveInstance.get_instance_count()
	instance_add_remove_btn.text = "add"
	var element_count = MCurveInstance.get_element_count()
	for i in range(0,element_count):
		items.set_item_custom_fg_color(i,Color(0.8,0.8,0.8))
	exclude_connection_btn.button_pressed = false
	# end clear
	var ids:PackedInt64Array = gizmo.get_selected_connections()
	if ids.size()!=1:
		instance_add_remove_btn.disabled = true
		return
	instance_add_remove_btn.disabled = sel_index.size()!=1
	instance_add_remove_btn.text = "add (capacity "+str(total_capacity)+")"
	var cid := ids[0]
	var curve_instance:MCurveInstance= current_modify_node
	var ov:MCurveInstanceOverride = curve_instance.override_data
	if not ov or not ov.has_override(cid):
		return
	# selecting element if they are active
	for i in range(0,element_count):
		if ov.has_element(cid,i):
			items.set_item_custom_fg_color(i,Color(0.4,0.9,0.4))
	var sel_elemenet:int = get_selected_element()
	exclude_connection_btn.set_pressed_no_signal(ov.get_exclude(cid))
	if sel_elemenet!=-1 and ov.has_element(cid,sel_elemenet):
		instance_setting_header.visible = true
		instance_rev_offset_checkbox.button_pressed = ov.get_flag(cid,sel_elemenet,MCurveInstanceOverride.FLAG.REVERSE_OFFSET)
		instance_mirror_checkbox.button_pressed = ov.get_flag(cid,sel_elemenet,MCurveInstanceOverride.FLAG.MIRROR)
		instance_start_offset_slider.value = ov.get_start_offset(cid,sel_elemenet)
		instance_end_offset_slider.value = ov.get_end_offset(cid,sel_elemenet)
		instance_rand_remove_slider.value = ov.get_rand_remove(cid,sel_elemenet)
	else:
		instance_setting_header.visible = false
	total_capacity = ov.get_conn_element_capacity(cid)
	
	if sel_index.size()==1:
		if ov.has_element(cid,sel_index[0]):
			instance_add_remove_btn.text = "remove (capacity "+str(total_capacity)+")"
		else:
			instance_add_remove_btn.text = "add (capacity "+str(total_capacity)+")"
			
			

func set_icon(path:String,preview:Texture2D,thumnail_preview:Texture2D,index:int):
	items.set_item_icon(index,preview)

func item_selected(index:int):
	if not is_instance_valid(current_modify_node) or not gizmo: return
	if current_modify_node is MCurveMesh and not current_modify_node.override:
		current_modify_node.override = MCurveMeshOverride.new()
	if modify_mode==MODIFY_MODE.CURVE_MESH:
		var ids:PackedInt64Array = get_selected_ids()
		for cid in ids:
			if mesh_mode:
				current_modify_node.override.set_mesh_override(cid,index)
			else:
				current_modify_node.override.set_material_override(cid,index)
		update_curve_item_selection()
	elif modify_mode==MODIFY_MODE.CURVE_INSTANCE:
		update_curve_instance_selection()

func clear_override():
	if not is_instance_valid(current_modify_node) or not gizmo: return
	if modify_mode==MODIFY_MODE.CURVE_MESH:
		var ids:PackedInt64Array = get_selected_ids()
		if mesh_mode:
			for cid in ids:
				current_modify_node.override.clear_mesh_override(cid)
		else:
			for cid in ids:
				current_modify_node.override.clear_material_override(cid)
		update_curve_item_selection()
	elif modify_mode==MODIFY_MODE.CURVE_INSTANCE:
		var ov:MCurveInstanceOverride = current_modify_node.override_data
		if not ov: return
		var ids:PackedInt64Array = get_selected_ids()
		if ids.size()==1:
			ov.clear_to_default(ids[0])
		update_curve_instance_selection()

func exclude_connection()->void:
	if not is_instance_valid(current_modify_node) or not gizmo: return
	if modify_mode==MODIFY_MODE.CURVE_MESH:
		var ids:PackedInt64Array = get_selected_ids()
		for cid in ids:
			current_modify_node.override.set_mesh_override(cid,-2)
		update_curve_item_selection()
	elif modify_mode==MODIFY_MODE.CURVE_INSTANCE:
		var ids:PackedInt64Array= gizmo.get_selected_connections()
		var ov:MCurveInstanceOverride = current_modify_node.override_data
		if not ov:
			ov = MCurveInstanceOverride.new()
			current_modify_node.override_data = ov
		if ids.size()==1:
			var sel_element:int = get_selected_element()
			var val = not ov.get_exclude(ids[0])
			ov.set_exclude(ids[0],val)
			update_curve_instance_selection()
			

# will use only in curve_mesh mode
func get_selected_ids()->PackedInt64Array:
	if connection_mode:
		return gizmo.get_selected_connections()
	else:
		return gizmo.get_selected_points64()

func mesh_mode_selected(index:int):
	mesh_mode = index == 0
	update_curve_mesh_items()


func _on_update_info_timer_timeout():
	if not is_instance_valid(current_curve): return
	var point_count:int = 0
	if current_curve:
		point_count = current_curve.get_points_count()
	point_count_lable.text = "Point count " + str(point_count)

func _on_wtimer_timeout() -> void:
	push_on_warn_lable("")


func instance_add_remove_element()->void:
	var ov:MCurveInstanceOverride = current_modify_node.override_data
	if not ov:
		ov = MCurveInstanceOverride.new()
	current_modify_node.override_data = ov
	var ids:PackedInt64Array = gizmo.get_selected_connections()
	if ids.size()!=1: return
	var cid:int = ids[0]
	var sel_items = items.get_selected_items()
	if sel_items.size()!=1: return
	var element_index = sel_items[0]
	if ov.has_element(cid,element_index): # is add
		ov.remove_element(cid,element_index)
	else: # is remove
		ov.add_element(cid,element_index)
	update_curve_instance_selection()

func instance_set_flag(value:bool,flag:MCurveInstanceOverride.FLAG)->void:
	var ov:MCurveInstanceOverride = current_modify_node.override_data
	if not ov: return
	var ids:PackedInt64Array = gizmo.get_selected_connections()
	if ids.size()!=1: return
	var cid:int = ids[0]
	var sel_element := get_selected_element()
	if sel_element!=-1:
		ov.set_flag(cid,sel_element,flag,value)

func instance_set_start_offset(value:float)->void:
	var ov:MCurveInstanceOverride = current_modify_node.override_data
	if not ov: return
	var ids:PackedInt64Array = gizmo.get_selected_connections()
	if ids.size()!=1: return
	var cid:int = ids[0]
	var sel_element := get_selected_element()
	if sel_element!=-1:
		ov.set_start_offset(cid,sel_element,value)

func get_selected_element()->int:
	var sels := items.get_selected_items()
	if sels.size()!=1: return -1
	return sels[0];

func instance_set_end_offset(value:float)->void:
	var ov:MCurveInstanceOverride = current_modify_node.override_data
	if not ov: return
	var ids:PackedInt64Array = gizmo.get_selected_connections()
	if ids.size()!=1: return
	var cid:int = ids[0]
	var sel_element := get_selected_element()
	if sel_element!=-1:
		ov.set_end_offset(cid,sel_element,value)

func instance_set_rand_remove(value:float)->void:
	var ov:MCurveInstanceOverride = current_modify_node.override_data
	if not ov: return
	var ids:PackedInt64Array = gizmo.get_selected_connections()
	if ids.size()!=1: return
	var cid:int = ids[0]
	var sel_element := get_selected_element()
	if sel_element!=-1:
		ov.set_rand_remove(cid,sel_element,value)

func instance_edit_commit(is_changed:bool)->void:
	if is_changed and current_modify_node and current_modify_node is MCurveInstance:
		var ov:MCurveInstanceOverride = current_modify_node.override_data
		if ov: ResourceSaver.save(ov,ov.resource_path)


########### Copy Paste Override

func copy_btn_pressed()->void:
	if not is_instance_valid(current_curve) or not is_instance_valid(current_path): return
	var point_sel:PackedInt32Array = gizmo.get_selected_points32()
	var conn_sel:PackedInt64Array= gizmo.get_selected_connections()
	if conn_sel.size()==0 and point_sel.size()==1:
		override_clipboard = current_curve.get_override_entry(point_sel[0])
		is_override_clipboard_conn = false
		update_copy_past_selection()
		return
	if conn_sel.size()==1 and point_sel.size()==2:
		override_clipboard = current_curve.get_override_entry(conn_sel[0])
		is_override_clipboard_conn = true
		update_copy_past_selection()
		return

func past_btn_pressed()->void:
	if not is_instance_valid(current_curve) or not is_instance_valid(current_path) or not override_clipboard: return
	var ids:PackedInt64Array
	var ov_array:Array
	var ov_undo_array:Array
	if is_override_clipboard_conn:
		for cid in gizmo.get_selected_connections():
			ids.push_back(cid)
			ov_array.push_back(override_clipboard)
			ov_undo_array.push_back(current_curve.get_override_entry(cid))
	else:
		for pid in gizmo.get_selected_points32():
			ids.push_back(pid)
			ov_array.push_back(override_clipboard)
			ov_undo_array.push_back(current_curve.get_override_entry(pid))
	# creating action
	ur.create_action("PastOverride",0,EditorInterface.get_edited_scene_root())
	ur.add_do_method(current_curve,"set_override_entries_and_apply",ids,ov_array,is_override_clipboard_conn)
	ur.add_undo_method(current_curve,"set_override_entries_and_apply",ids,ov_undo_array,is_override_clipboard_conn)
	ur.commit_action(true)
	
	
	
	
	
	
	
	
	
	
	
	
### end
