@tool
extends Window

@onready var cancel_button = find_child("cancel_button")
@onready var commit_button = find_child("commit_button")

var baker: HLod_Baker
var nodes_to_join = []	
var original_nodes_to_join = []

func _ready():	
	if EditorInterface.get_edited_scene_root() == self or EditorInterface.get_edited_scene_root().is_ancestor_of(self): return
	title = "\"" + baker.name + "\" joined mesh settings"
	commit_button.pressed.connect(commit)
	cancel_button.pressed.connect(queue_free)
	close_requested.connect(queue_free)
	
	var node_tree:Tree = find_child("node_tree")
	var root = node_tree.create_item()
	node_tree.hide_root = true
	#node_tree.columns = 2
	#root.set_text(0, "Join at...")
	#node_tree.set_column_expand(1, false)	
	#node_tree.set_column_custom_minimum_width(1, 130) 	
	#root.set_cell_mode(1, TreeItem.CELL_MODE_RANGE)
	#root.set_range_config(1, -1, AssetIO.LOD_COUNT, 1)
	#root.set_range(1, 1)	
	#var text = "Do Not Join"
	#for i in AssetIO.LOD_COUNT:
		#text += ", Lod " + str(i)
	#root.set_text(1, text)	
	#root.set_editable(1,true)
	for node in baker.get_children():
		build_tree(node, root)
		
	node_tree.item_edited.connect(func():		
		var item := node_tree.get_selected()	
		item.propagate_check(0)
	)
	node_tree.check_propagated_to_item.connect(func(item:TreeItem,column):		
		var node = item.get_metadata(column)
		if is_instance_valid(node):
			if item.is_checked(0):
				if not node in nodes_to_join:
					nodes_to_join.push_back(node)
			else:
				if node in nodes_to_join:
					nodes_to_join.erase(node)
	)
	#var import_info = MAssetTable.get_singleton().import_info
	#var joined_mesh_glb_path = baker.get_joined_mesh_path()
	#if import_info.has(joined_mesh_glb_path):
		#if import_info[joined_mesh_glb_path].has("__metadata"):
			#if import_info[joined_mesh_glb_path]["__metadata"].has
		
	%JoinLod.value = baker.join_at_lod
	%JoinLod.max_value = AssetIO.LOD_COUNT-1	
						
	%export_joined_mesh_toggle.button_pressed = not baker.has_joined_mesh_glb() 
	set_update_mode(not baker.has_joined_mesh_glb())
	%export_joined_mesh_toggle.disabled = not baker.has_joined_mesh_glb()
	%export_joined_mesh_toggle.toggled.connect(set_update_mode)
	%show_joined_mesh_glb_button.pressed.connect(func():
		var path = baker.get_joined_mesh_glb_path()
		EditorInterface.get_file_system_dock().navigate_to_path(path)		
	)
	var remove_joined_mesh = %remove_joined_mesh
	remove_joined_mesh.visible = baker.has_joined_mesh_glb()
	remove_joined_mesh.pressed.connect(func():
		var dialog := ConfirmationDialog.new()
		dialog.dialog_text = "Are you sure you want to delete the joined mesh .glb file?"
		dialog.confirmed.connect(func():		
			baker.remove_joined_mesh()
			remove_joined_mesh.visible = false
			%export_joined_mesh_toggle.button_pressed = true
			%export_joined_mesh_toggle.disabled = true
		)
		add_child(dialog)
		dialog.popup_centered()
	)
	
func set_update_mode(toggle_on):
	%remove_joined_mesh.visible = not toggle_on
	%node_tree.visible = toggle_on
	%join_at_lod_hbox.visible = toggle_on
	%show_joined_mesh_glb_button.visible = not toggle_on
	%warning_label.visible = toggle_on and baker.has_joined_mesh_glb()
	if toggle_on:
		%export_joined_mesh_toggle.text = "Export from scene"
		commit_button.text = "Make Joined Mesh"
	else:
		%export_joined_mesh_toggle.text = "Reimport GLB"
		commit_button.text = "Reimport"
	
	
func build_tree(parent_node, parent_item:TreeItem):		
	if not parent_node is Node3D: return
	#if not parent_node.owner == baker: return
	var item := parent_item.create_child()			
	item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)	
	item.set_editable(0, true)
	item.set_metadata(0, parent_node)
	item.set_text(0, parent_node.name)		
	if parent_node is MAssetMesh:
		var tags = MAssetTable.get_singleton().collection_get_tags(parent_node.collection_id)
		var should_join = null
		if baker.meshes_to_join_overrides.has(parent_node.name):
			should_join = baker.meshes_to_join_overrides[parent_node.name] #true or false							
		if not 1 in tags:
			original_nodes_to_join.push_back(parent_node)
			if should_join != false:				
				nodes_to_join.push_back(parent_node)			
				item.set_checked(0, true)
				item.propagate_check(0,  true)			
		elif should_join:
			item.set_checked(0, true)
			nodes_to_join.push_back(parent_node)
			item.propagate_check(0,  true)			
			
	if not parent_node is MAssetMesh:
		for child in parent_node.get_children():
			build_tree(child, item)

func commit():			
	baker.join_at_lod = %JoinLod.value	
	if %export_joined_mesh_toggle.button_pressed:				
		baker.make_joined_mesh(nodes_to_join, %JoinLod.value)
		for node in original_nodes_to_join:
			if not node in nodes_to_join:						
				baker.meshes_to_join_overrides[node.name] = false
			else:
				baker.meshes_to_join_overrides.erase(node.name)
		for node in nodes_to_join:
			if not node in original_nodes_to_join:
				baker.meshes_to_join_overrides[node.name] = true
			else:
				baker.meshes_to_join_overrides.erase(node.name)
	else:
		baker.update_joined_mesh_from_glb()
	queue_free()
