#IMPORT WINDOW ASSETS
@tool
extends PanelContainer

@onready var cancel_button:Button = find_child("cancel_button")
@onready var import_button:Button = find_child("import_button")
@onready var import_label:Label = find_child("import_label")
@onready var node_container = find_child("node_container")

var asset_data:AssetIOData
var asset_library = MAssetTable.get_singleton()
var material_table_items = {}

var invalid_materials := []

var item_thmbnail_queue:Array
var generating_thumbnail:=false ## stop generating when there is a gen process

func _ready():
	#if EditorInterface.get_edited_scene_root() == self or EditorInterface.get_edited_scene_root().is_ancestor_of(self): return

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
	
	#print(asset_data.mesh_data)
	#print(asset_data.materials)
	#print(asset_data.mesh_items)
	#print(asset_data.collections)
	init_collections_tree()	
	init_materials_tree()	
	init_meshes_tree()
	init_variations_tree()
	%variations_tab_button.visible = len(asset_data.variation_groups) >0
	%materials_tab_button.button_group.pressed.connect(func(button):		
		if button == %materials_tab_button:
			%materials_hsplit.visible = true
			%meshes_hsplit.visible = false
			%collections_hsplit.visible = false			
			%variations_hsplit.visible = false
		elif button == %meshes_tab_button:
			%materials_hsplit.visible = false
			%meshes_hsplit.visible = true
			%collections_hsplit.visible = false
			%variations_hsplit.visible = false
		elif button == %collections_tab_button:
			%materials_hsplit.visible = false
			%meshes_hsplit.visible = false
			%collections_hsplit.visible = true
			%variations_hsplit.visible = false
		elif button == %variations_tab_button:			
			%materials_hsplit.visible = false
			%meshes_hsplit.visible = false
			%collections_hsplit.visible = false	
			%variations_hsplit.visible = true	
	)

func init_meshes_tree():
	var mesh_tree: Tree = %meshes_tree	
	mesh_tree.item_edited.connect(func():				
		var item := mesh_tree.get_selected()			
		item.propagate_check(0)
	)
	mesh_tree.check_propagated_to_item.connect(func(item:TreeItem,column):
		pass		
		#var node = item.get_metadata(1)		
		#if is_instance_valid(node):
		#	node.ignore = not item.is_checked(column)
		#	update_collection_details(true, mesh_tree.get_selected().get_metadata(0))
	)	
	var root = mesh_tree.create_item()	
	for mesh_id in asset_data.mesh_data:
		var mesh_name = asset_data.mesh_data[mesh_id].name
		var mesh_tree_node = root.create_child()		
		mesh_tree_node.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		mesh_tree_node.set_editable(0, true)				
		mesh_tree_node.set_checked(0, true)
		mesh_tree_node.set_text(0, mesh_name)		
		for material_array in asset_data.mesh_data[mesh_id].material_sets:
			var set_tree_node = mesh_tree_node.create_child()
			set_tree_node.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
			set_tree_node.set_checked(0, true)
			set_tree_node.set_editable(0, true)
						
			var text = material_array.duplicate()
			for i in len(text):
				if text[i] == "":
					text[i] = "???"
			set_tree_node.set_text(0, "[" + ", ".join(text	) + "]")# "Set")
			#for mat in material_array:
				#var material_tree_node = set_tree_node.create_child()
				#if mat == "":
					#material_tree_node.set_text(0, "(unnamed material)")					
				#else:
					#material_tree_node.set_text(0, mat)	
	
		
func init_collections_tree():
	var collections_tree: Tree = %collection_tree	
	collections_tree.item_edited.connect(func():				
		var item := collections_tree.get_selected()	
		item.propagate_check(0)
	)
	collections_tree.check_propagated_to_item.connect(func(item:TreeItem,column):		
		var node = item.get_metadata(1)		
		if is_instance_valid(node):
			node.ignore = not item.is_checked(column)
			update_collection_details(true, collections_tree.get_selected().get_metadata(0))
	)
	collections_tree.set_column_expand(0,false)
	collections_tree.set_column_expand(1,true)
	collections_tree.set_column_expand(2,false)		
	collections_tree.set_column_custom_minimum_width(1,120)
	collections_tree.set_column_custom_minimum_width(2,120)	
	collections_tree.item_selected.connect(func():						
		update_collection_details(true, collections_tree.get_selected().get_metadata(0))				
	)
	var root = collections_tree.create_item()				
	for key in asset_data.collections:		
		if asset_data.collections[key].has("is_root"):
			build_collection_tree(key, root)

func init_variations_tree():	
	var root = %variations_tree.create_item()
	for group in asset_data.variation_groups:			
		var group_item = root.create_child()
		for node_name in asset_data.collections:
			if not asset_data.collections[node_name].has("is_root"): continue
			var fixed_name = node_name.split("_")
			fixed_name.resize(fixed_name.size()-1)
			fixed_name = "".join(fixed_name)				
			if fixed_name in group:				
				var item = group_item.create_child(0)
				item.set_text(0, node_name)
				
		group_item.set_text(0, "variation group")			
	
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
		#for collection in item_node.mesh_items:
			#var mesh_item = meshes.create_child()
			#var mesh_array = asset_data.mesh_items[mesh_item_name].meshes.duplicate()
			#mesh_array = Array(mesh_array).map(func(a): return a if a is int else "Mesh" )
			#var text = str(mesh_item_name, ": ",mesh_array, " set ", asset_data.mesh_items[mesh_item_name].material_set_id  ) #item_node.mesh_items[mesh_item_name].origin)
			###for mesh_id in asset_data.meshes[mesh_item_name].meshes:
				#
			#mesh_item.set_text(0, text)
		var collisions = root.create_child()
		collisions.set_text(0, "Collisions")		
		for collision_item_data in item_node.collision_items:			
			var collision_item = collisions.create_child()
			var text =  str(AssetIOData.COLLISION_TYPE.keys()[collision_item_data.type]).to_pascal_case()
			text += str(": ", snapped(collision_item_data.transform.origin, Vector3(0.1, 0.1,0.1) ))
			collision_item.set_text(0, text)				
		var sub_collections = root.create_child()
		sub_collections.set_text(0, "Sub Collections")
		#for sub_collection_name in item_node.sub_collections:
			#for sub_collection_transform in item_node.sub_collections[sub_collection_name]:
				#var sub_collection_item = sub_collections.create_child()			
				#var text = str(sub_collection_name,": ",snapped(sub_collection_transform.origin, Vector3(0.1, 0.1,0.1) ) )
				#sub_collection_item.set_text(0, text)
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
	var material_table = AssetIOMaterials.get_material_table()
	var root := materials_tree.create_item()		
	for material_name in asset_data.materials.keys():
		var material_tree_node = root.create_child()
		var text = str(material_name) if material_name != "" else "???" 
		material_tree_node.set_text(0, text)										
		if asset_data.materials[material_name].material is int:								
			var material_id = asset_data.materials[material_name].material
			material_tree_node.set_text(1, str(material_id))			
			ThumbnailManager.thumbnail_queue.push_back({"resource": AssetIOMaterials.get_material(material_id), "caller":material_tree_node, "callback": update_material_icon, "column": 1})			
		else:
			invalid_materials.push_back(material_name)
			%materials_tab_button.text = "Materials (!)"
			import_button.disabled = true
			material_tree_node.set_text(1, "???")
			material_tree_node.set_custom_color(1, Color.ORANGE)
					
	var material_details_tree:Tree = %material_details_tree
	root = material_details_tree.create_item()		
	var null_item = root.create_child() 		
	material_table_items[-1] = null_item	
	null_item.set_text(0,"(no material)")
	null_item.set_metadata(0, -1)
	for id in material_table:				
		var item = root.create_child() 		
		material_table_items[id] = item
		var material_path = material_table[id].path
		item.set_text(0,material_path.get_file())
		item.set_metadata(0, id)
		item.set_tooltip_text(0, material_path)				
		ThumbnailManager.thumbnail_queue.push_back({"resource": AssetIOMaterials.get_material(id), "caller":item, "callback": update_material_icon, "column": 0})					
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
		if glb_material_name == "???": glb_material_name = ""
		if asset_data.materials.has(glb_material_name):
			var selected_material_item = material_details_tree.get_selected()			
			if glb_material_name in invalid_materials:
				invalid_material_fixed(glb_material_name)
			asset_data.materials[glb_material_name].material = int(selected_material_item.get_metadata(0))			
			if asset_data.materials[glb_material_name].material != asset_data.materials[glb_material_name].original_material:				
				for mesh_id in asset_data.materials[glb_material_name].meshes:
					pass
					#if asset_data.meshes[mesh_id].state = 
			selected_glb_material_item.set_text(1, str(asset_data.materials[glb_material_name].material))						
			selected_glb_material_item.set_icon(1, selected_material_item.get_icon(0))
	)
func invalid_material_fixed(material_name):
	invalid_materials.erase(material_name)
	if len(invalid_materials) == 0:
		%materials_tab_button.text = "Materials"
		validate_can_import()
		
func validate_can_import():
	import_button.disabled = true
	if len(invalid_materials) == 0:
		import_button.disabled = false
	
func update_material_icon(data):		
	data.caller.set_icon(data.column, data.texture)
	
					
func build_collection_tree(node_name:String, root:TreeItem):	
	var item := root.create_child()		
	var node = asset_data.collections[node_name] if asset_data.collections.has(node_name) else {}
	
	item.set_cell_mode(0,TreeItem.CELL_MODE_CHECK)		
	item.set_editable(0, true)	
	item.set_checked(0, not node.ignore)			
	
	item.set_text(1, node_name)					
	var lod = 0	
	set_thumbnail(item, node_name, asset_data.collections[node_name].meshes[lod].get_mesh(), asset_data.collections[node_name].id)		
	
	item.set_metadata(0, node)		
	
	
	if node.state > 1:						
		item.set_text(2, AssetIOData.IMPORT_STATE.keys()[node.state])
	if node.has("collections"):		
		for key in node.collections:			
			build_collection_tree(key, item)

## Set icon with no dely if thumbnail is valid
func set_thumbnail(item:TreeItem, node_name, mesh:ArrayMesh, id)->void:
	var tex:Texture2D	
	tex = ThumbnailManager.get_valid_thumbnail(id)
	if tex != null:
		item.set_icon(1, tex)
	else:				
		ThumbnailManager.thumbnail_queue.push_back({"resource": mesh, "caller": item, "callback": update_thumbnail})			
	
func update_thumbnail(data):					
	data.caller.set_icon(1, data.texture)
