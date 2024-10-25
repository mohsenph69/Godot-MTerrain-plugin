@tool
extends PanelContainer

@onready var cancel_button:Button = find_child("cancel_button")
@onready var import_button:Button = find_child("import_button")
@onready var import_label:Label = find_child("import_label")
@onready var node_container = find_child("node_container")

var file_name = "file.glb"
var collections_to_import: Dictionary
func _ready():	
	import_label.text = "Importing " + file_name.split("/")[-1]	
	if get_parent() is Window:
		get_parent().close_requested.connect(get_parent().queue_free)
	cancel_button.pressed.connect(func():
		if get_parent() is Window:
			get_parent().queue_free()
	)
	import_button.pressed.connect(func():
		AssetIO.glb_import_collections(collections_to_import, file_name)
		
		if get_parent() is Window:
			get_parent().queue_free()
	)
	for child in node_container.get_children():
		node_container.remove_child(child)
		child.queue_free()		
	
	var import_how = OptionButton.new()
	import_how.add_item("new")
	import_how.add_item("overwrite")
	import_how.add_item("ignore")	
	var add_import_item = func(collection_name, collection, indent = 0):		
		var hbox = HBoxContainer.new()		
		var label = Label.new()
		hbox.add_child(label)
		import_how.select(0)
		if MAssetTable.get_singleton().collection_get_id(collection_name) != -1:
			import_how.select(1)		
		hbox.add_child(import_how.duplicate())		
		var prefix = ""
		for i in indent:
			prefix += "\u2014 "
		label.text = prefix + collection_name		
		node_container.add_child(hbox)
	for collection_name in collections_to_import.keys():		
		add_import_item.call(collection_name, collections_to_import[collection_name])
		if not "collections" in collections_to_import[collection_name]: continue
		for sub_collection_name in collections_to_import[collection_name].collections.keys():			
			add_import_item.call(sub_collection_name, collections_to_import[collection_name].collections, 1)
		
		
