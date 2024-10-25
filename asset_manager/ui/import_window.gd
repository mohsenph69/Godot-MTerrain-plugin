@tool
extends PanelContainer

@onready var cancel_button:Button = find_child("cancel_button")
@onready var import_button:Button = find_child("import_button")
@onready var import_label:Label = find_child("import_label")
@onready var node_container = find_child("node_container")

var glb_path = "path_to_file.glb"
var collections_to_import: Dictionary
func _ready():	
	var asset_library = MAssetTable.get_singleton()
	import_label.text = "Importing " + glb_path.split("/")[-1]	
	if get_parent() is Window:
		get_parent().close_requested.connect(get_parent().queue_free)
	cancel_button.pressed.connect(func():
		if get_parent() is Window:
			get_parent().queue_free()
	)
	import_button.pressed.connect(func():		
		AssetIO.glb_import_commit_changes(collections_to_import, glb_path)		
		if get_parent() is Window:
			get_parent().queue_free()
	)
	for child in node_container.get_children():
		node_container.remove_child(child)
		child.queue_free()				
			
				
	var existing_collections = {}	
	if glb_path in asset_library.import_info.keys():
		for n in asset_library.import_info[glb_path]["root_collections"]:
			existing_collections[n] = asset_library.import_info[glb_path][n]
	#print(existing_collections)
	var diffs = compare_collections(existing_collections, collections_to_import)				
	
	for collection_name in diffs.overwrite_or_remove:	
		if collection_name in diffs.remove:		
			add_import_item(collection_name, existing_collections[collection_name], {},2)		
		else:
			add_import_item(collection_name, existing_collections[collection_name], collections_to_import[collection_name],1)					
	for collection_name in diffs.add:		
		add_import_item(collection_name, {}, collections_to_import[collection_name],0)				
		
		
func add_import_item(collection_name, existing_collection, new_collection, import_how_id, indent = 0):		
	var asset_library = MAssetTable.get_singleton()
	var import_how = OptionButton.new()	
	var hbox = HBoxContainer.new()		
	var label = Button.new() if "meshes" in existing_collection or "meshes" in new_collection else Label.new()
	hbox.add_child(label)			
	if import_how_id == 0:
		import_how.add_item("new")			
		import_how.add_item("ignore")		
		import_how.item_selected.connect(func(id):
			new_collection["ignore"] = id == 1
		)						
	if import_how_id == 1:			
		import_how.add_item("overwrite")			
		import_how.add_item("ignore")
		import_how.item_selected.connect(func(id):
			new_collection["ignore"] = id == 1
		)						
	if import_how_id == 2:
		import_how.add_item("remove")
		import_how.add_item("ignore")	
		import_how.item_selected.connect(func(id):
			existing_collection["ignore"] = id == 1
		)						
	
	hbox.add_child(import_how)		
	var prefix = ""
	for i in indent:
		prefix += "\u2014 "
	label.text = prefix + collection_name
	if label is Button:
		label.pressed.connect(func():
			var details_container = find_child("details_container")
			for child in details_container.get_children():
				details_container.remove_child(child)
				child.queue_free()
			
			if "meshes" in existing_collection.keys():
				var title = Label.new()
				details_container.add_child(title)
				title.text = "Original " + label.text
				for mesh in existing_collection["meshes"]:
					var mesh_label = Label.new()					
					var mesh_item = asset_library.collection_get_mesh_items_info(mesh)[0]
					#var mesh_item = asset_library.mesh_item_get_info(mesh_id)
					mesh_label.text = mesh_item_make_readable(collection_name.get_slice("_mesh", 0), mesh_item)
					details_container.add_child(mesh_label)
			if "meshes" in new_collection.keys():
				var title = Label.new()
				details_container.add_child(title)
				title.text = "New " + label.text
				var mesh_label = Label.new()
				details_container.add_child(mesh_label)
				for mesh in new_collection["meshes"]:					
					mesh_label.text += str(mesh.name) + "\n"
					
		)
	node_container.add_child(hbox)		
	var a = {}
	if "collections" in existing_collection.keys():		
		for sub_collection_name in existing_collection.collections:
			a[sub_collection_name] = asset_library.import_info[glb_path][sub_collection_name]
	var b = new_collection.collections if "collections" in new_collection.keys() else {}	
	var diffs = compare_collections(a,b)			
	for sub_collection_name in diffs.overwrite_or_remove:	
		if sub_collection_name in diffs.remove:		
			add_import_item(sub_collection_name, a[sub_collection_name], {}, 2, indent+1)		
		elif sub_collection_name in diffs.overwrite:			
			if sub_collection_name in a.keys() and sub_collection_name in b.keys():
				add_import_item(sub_collection_name, a[sub_collection_name], b[sub_collection_name], 1, indent+1)			
			else:
				print(a.collections.keys(), " | ", b.collections.keys())
	for sub_collection_name in diffs.add:		
		add_import_item(sub_collection_name, {}, new_collection.collections[sub_collection_name], 0, indent+1)								

func compare_collections(a, b):
	var result = {"add":[], "overwrite": [], "remove":[], "overwrite_or_remove":[]}
	if not a is Dictionary or not b is Dictionary:				
		return result
	for key in a.keys():
		if not key in b.keys():
			result.remove.push_back(key)
		else:
			result.overwrite.push_back(key)
		result.overwrite_or_remove.push_back(key)
	for key in b.keys():
		if not key in a.keys():
			result.add.push_back(key)
	return result
	
func mesh_item_make_readable(base_name, mesh_item):
	var last_id = -1
	var last_lod = -1
	var result = []
	for i in len(mesh_item["mesh"]):
		last_lod += 1
		if last_id != mesh_item["mesh"][i]: 
			last_id = mesh_item["mesh"][i]
			result.push_back(str(base_name, "_lod_", last_lod))
	return "\n".join(result)
			
