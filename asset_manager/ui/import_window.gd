@tool
extends PanelContainer

@onready var cancel_button:Button = find_child("cancel_button")
@onready var import_button:Button = find_child("import_button")
@onready var import_label:Label = find_child("import_label")
@onready var node_container = find_child("node_container")

var asset_data:AssetIOData
var asset_library = MAssetTable.get_singleton()
var material_table_items = {}
func _ready():
	if EditorInterface.get_edited_scene_root() == self: return

	if get_parent() is Window:
		get_parent().close_requested.connect(get_parent().queue_free)
	cancel_button.pressed.connect(func():
		if get_parent() is Window:
			get_parent().queue_free()
	)
	if asset_data == null:
		return
		
	import_button.pressed.connect(func():						
		AssetIO.glb_import_commit_changes()		
		if get_parent() is Window:
			get_parent().queue_free()
	)
	get_window().title = "Importing: " + asset_data.glb_path
	init_collections_tree()	
	init_materials_tree()	
	%materials_tab_button.button_group.pressed.connect(func(button):		
		if button == %materials_tab_button:
			%collections_hsplit.visible = false
			%materials_hsplit.visible = true
		else:
			%collections_hsplit.visible = true
			%materials_hsplit.visible = false
	)
	
func init_collections_tree():
	var tree: Tree = %collection_tree	
	tree.item_edited.connect(func():				
		var item := tree.get_selected()	
		item.propagate_check(0)
	)
	tree.check_propagated_to_item.connect(func(item:TreeItem,column):		
		var node = item.get_metadata(1)		
		if is_instance_valid(node):
			node.ignore = not item.is_checked(column)
			update_collection_details(true, tree.get_selected().get_metadata(0))
	)
	tree.set_column_expand(0,false)
	tree.set_column_expand(1,true)
	tree.set_column_expand(2,false)		
	tree.set_column_custom_minimum_width(1,120)
	tree.set_column_custom_minimum_width(2,120)	
	tree.item_selected.connect(func():				
		#tree.select_mode = Tree.SELECT_SINGLE
		update_collection_details(true, tree.get_selected().get_metadata(0))
		#tree.select_mode = Tree.SELECT_ROW
		
	)
	var root = tree.create_item()			
	for key in asset_data.collections:		
		if asset_data.collections[key].has("is_root"):
			build_tree(key, root)
	
func update_collection_details(is_collection:bool, item_node:Dictionary ):
	if not item_node:
		return
	var tree:Tree
	#var root = tree.create_item()
	if is_collection:
		tree = %collection_details_tree		
		tree.clear()
		var root : TreeItem = tree.create_item()
		var meshes := root.create_child()
		meshes.set_text(0, "Meshes")
		for mesh_item_name in item_node.mesh_items:
			var mesh_item = meshes.create_child()
			var mesh_array = asset_data.mesh_items[mesh_item_name].meshes.duplicate()
			mesh_array = Array(mesh_array).map(func(a): return a if a is int else "Mesh" )
			var text = str(mesh_item_name, ": ",mesh_array ) #item_node.mesh_items[mesh_item_name].origin)
			##for mesh_id in asset_data.meshes[mesh_item_name].meshes:
				
			mesh_item.set_text(0, text)
		var collisions = root.create_child()
		collisions.set_text(0, "Collisions")		
		for collision_item_data in item_node.collision_items:			
			var collision_item = collisions.create_child()
			var text =  str(AssetIOData.COLLISION_TYPE.keys()[collision_item_data.type]).to_pascal_case()
			text += str(": ", snapped(collision_item_data.transform.origin, Vector3(0.1, 0.1,0.1) ))
			collision_item.set_text(0, text)				
		var sub_collections = root.create_child()
		sub_collections.set_text(0, "Sub Collections")
		for sub_collection_name in item_node.sub_collections:
			for sub_collection_transform in item_node.sub_collections[sub_collection_name]:
				var sub_collection_item = sub_collections.create_child()			
				var text = str(sub_collection_name,": ",snapped(sub_collection_transform.origin, Vector3(0.1, 0.1,0.1) ) )
				sub_collection_item.set_text(0, text)
		#build_tree(item_name,root)
	else:
		tree = %material_details_tree
	
	#if asset_data.materials[material_name] != null:
	#	material_node.set_text(1, asset_data.materials[material_name])	
	#var node_name = item.get_text(0)
	#if node_name in asset_data.collections:
	#	%preview_dictionary_label.text = str(asset_data.collections[node_name]).erase(0,2).replace("{", "{\n").replace("}", "\n}").replace("}, ", "},\n")	
	
func init_materials_tree():
	var materials_tree: Tree = %materials_tree	
	materials_tree.set_column_expand(1, false)	
	materials_tree.set_column_custom_minimum_width(1, 64)	
	materials_tree.item_edited.connect(func():
		var item = materials_tree.get_edited()
		var i = item.get_range(2)
		
	)
	
	var root := materials_tree.create_item()	
	var material_table := MMaterialTable.get_singleton()
	
	for material_name in asset_data.materials.keys():
		var material_node = root.create_child()
		var text = str(material_name) if material_name != "" else "(unnamed material)" 
		material_node.set_text(0, text)										
		if asset_data.materials[material_name].material is int:								
			material_node.set_text(1, str(asset_data.materials[material_name].material))								
			
	var material_details_tree:Tree = %material_details_tree
	root = material_details_tree.create_item()		
	for id in material_table.table:				
		var item = root.create_child() 		
		material_table_items[id] = item
		var material_path = material_table.table[id]
		item.set_text(0,material_path.get_file())
		item.set_metadata(0, id)
		item.set_tooltip_text(0, material_path)
		update_material_icon(item, id)
		#item.set_icon(1, EditorResourcePreview)
	materials_tree.item_selected.connect(func():
		material_details_tree.visible = true
		var id = materials_tree.get_selected().get_text(1)
		if id.is_valid_int():
			material_table_items[int(id)].select(0)
		else:			
			material_details_tree.deselect_all()	
	)
	material_details_tree.item_selected.connect(func():
		var selected_glb_material_item := materials_tree.get_selected()
		if not selected_glb_material_item:
			return
		var glb_material_name = selected_glb_material_item.get_text(0) 
		if glb_material_name == "(unnamed material)": glb_material_name = ""
		if asset_data.materials.has(glb_material_name):
			var selected_material = material_details_tree.get_selected()
			asset_data.materials[glb_material_name].material = int(selected_material.get_metadata(0))
			selected_glb_material_item.set_text(1, str(asset_data.materials[glb_material_name].material))						
			selected_glb_material_item.set_icon(1, selected_material.get_icon(0))
	)
	
func update_material_icon(item:TreeItem, id):
	var thumbnail = AssetIO.generate_material_thumbnail(id, update_material_icon.bind(item,id))	
	if thumbnail:		
		item.set_icon(0, thumbnail)
	else:		
		await get_tree().create_timer(0.5).timeout.connect(update_material_icon.bind(item, id))
					
func build_tree(node_name:String, root:TreeItem):	
	var item := root.create_child()		
	var node = asset_data.collections[node_name] if asset_data.collections.has(node_name) else {}
	
	item.set_cell_mode(0,TreeItem.CELL_MODE_CHECK)		
	item.set_editable(0, true)	
	item.set_checked(0, not node.ignore)			
	
	item.set_text(1, node_name)		
	item.set_metadata(0, node)		
	
	
	if node.state > 1:						
		item.set_text(2, AssetIOData.IMPORT_STATE.keys()[node.state])
	if node.has("collections"):		
		for key in node.collections:			
			build_tree(key, item)
