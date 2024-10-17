@tool
extends HFlowContainer
var material_table: MMaterialTable = MMaterialTable.get_singelton()

func _enter_tree():		
	for m in material_table.table:			
		var texture_rect = TextureRect.new()
		add_child(texture_rect)
		EditorInterface.get_resource_previewer().queue_resource_preview(material_table.table[m], self, "update_material_preview",texture_rect)					
func _ready():
	if get_child_count()>1:
		$Label.queue_free()
func _can_drop_data(at_position: Vector2, data: Variant):
	if "files" in data:
		for file in data.files:
			var resource = load(file)
			if resource is Material:
				return true

func _drop_data(at_position: Vector2, data: Variant):
	var materials = []
	for file in data.files:
		var resource = load(file)
		if resource is Material:
			if material_table.find_material_id(file) == -1:
				material_table.add_material(file)
				var texture_rect = TextureRect.new()
				add_child(texture_rect)
				EditorInterface.get_resource_previewer().queue_resource_preview(material_table.table.values()[-1], self, "update_material_preview",texture_rect)					
	if has_node("Label"):
		$Label.queue_free()
	notify_property_list_changed()
			#materials.push_back(resource)
	
func update_material_preview(path, preview, thumbnail, texture_rect):
	texture_rect.texture = preview
