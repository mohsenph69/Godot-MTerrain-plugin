@tool
extends EditorScript
var asset_table := MAssetTable.get_singleton()

func run():
	#########
	# Items #
	#########
	#save mesh
	save_mesh_new_mesh()
	#save_mesh_existing_mesh()
	#remove mesh
	#remove_mesh_existing_mesh()
	
		
	#add item
	add_item_new_item()
	add_item_existing_item()
	add_item_no_meshes()
	add_item_array_lengths_mismatched()
	add_item_mesh_file_does_not_exist() 
	
	#has item

func save_mesh_new_mesh():
	var mesh = BoxMesh.new()
	var path = asset_table.mesh_get_path(mesh)
	ResourceSaver.save(mesh, path)
	if not FileAccess.file_exists(path):
		push_error("failed save new mesh to ", path, ": file_access file does not exists")
	
	
func add_item_new_item():				
	var mesh_item_id = asset_table.mesh_item_add([],-1)
	if not has_mesh_item(mesh_item_id):		
		push_error("add_item_new_item failed, table does not have mesh item id ", mesh_item_id)
		return false
	var mesh_item_info = asset_table.mesh_item_get_info(mesh_item_id)
	

func has_mesh_item(mesh_item_id):
	if not asset_table.has_mesh_item(mesh_item_id):
		push_error("has_mesh_item failed for mesh item id: ", mesh_item_id )		
		return false 
	if not mesh_item_id in asset_table.mesh_item_get_list():
		push_error("mesh_item_get_list does not contain mesh item ", mesh_item_id  )		
		return false
	return true
		
func add_item_existing_item():
	var ids = asset_table.mesh_item_get_list()
	if len(ids)==0:
		add_item_new_item()
	var existing_item = asset_table.mesh_item_get_info(ids[0])
	asset_table.mesh_item_add(existing_item.mesh, existing_item.material)
	
func add_item_no_meshes():
	asset_table.mesh_item_add([],-1)
	
func add_item_array_lengths_mismatched():
	asset_table.mesh_item_add([],0)

func add_item_mesh_file_does_not_exist():
	var mesh_files = DirAccess.get_files_at(MHlod.get_mesh_root_dir())		
	var last_id = int(mesh_files[-1].split("/")[-1])	
	asset_table.mesh_item_add([last_id + 1],-1)
	


#	- remove item
#		- func remove_item_item_exists
#		- func remove_item_no_item
#	- get item id (has item)
#	- get item mesh_array
#	- get item material_array
#	- remove all items
		
# Asset Library Functionality:

# - Collections
#	- add collection
#	- remove collection
#	- rename collection
#	- remove all collections
#	- add item to collection
#	- remove item from collection
#	- add tag to collection
#	- remove tag from collection
#	- get collection by id
#	- get collection by name
#	- get collections names by ids
# - Tags
#	- add tag
#	- remove tag
#	- rename tag
#	- get all tag names
#	- get tag by name
#	- get tag by id
#	- search tag names
# - Groups
#	- add group
#	- remove group
#	- rename group
#	- add tag to group
#	- remove tag from group
#	- get all groups
#	- get tags in group
#	- get group by name
#	- get group by id
#	- get collections by group ( returns dictionary: {tag1: [collection 0,collection1]}, {tag2:[collection2,collection3]}
