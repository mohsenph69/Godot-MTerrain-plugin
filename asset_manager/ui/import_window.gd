@tool
extends PanelContainer

@onready var cancel_button:Button = find_child("cancel_button")
@onready var import_button:Button = find_child("import_button")
@onready var import_label:Label = find_child("import_label")
@onready var node_container = find_child("node_container")

var file_name = "file.glb"
var nodes: Array
func _ready():	
	import_label.text = "Importing " + file_name.split("/")[-1]	
	if get_parent() is Window:
		get_parent().close_requested.connect(get_parent().queue_free)
	cancel_button.pressed.connect(func():
		if get_parent() is Window:
			get_parent().queue_free()
	)
	import_button.pressed.connect(func():
		MAssetTable.get_singleton().save()		
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
	var add_import_item = func(node):		
		var hbox = HBoxContainer.new()
		var label = Label.new()
		hbox.add_child(label)
		import_how.select(0)
		if MAssetTable.get_singleton().collection_get_id(node.name.split("_")[0]) != -1:
			import_how.select(1)		
		hbox.add_child(import_how.duplicate())
		
		label.text = node.name
		node_container.add_child(hbox)
	for node:Node in nodes:
		if node is ImporterMeshInstance3D: continue
		add_import_item.call(node)
		for node1:Node in node.get_children():
			if node1 is ImporterMeshInstance3D: continue			
			add_import_item.call(node1)
		
		
