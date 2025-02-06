@tool
extends Node

@onready var tags_label = find_child("tags_label")
@onready var groups_label = find_child("groups_label")
@onready var cl:= $collections_label

@onready var collections_container = find_child("collections_container")

var asset_library:MAssetTable

func _ready():
	if AssetIO.DEBUG_MODE:
		$clear_btn.visible = true
		$clear_btn.button_down.connect(clear_asset_table)
	else:
		$clear_btn.visible = false
	$reload_btn.button_down.connect(reload_asset_table)
	asset_library = MAssetTable.get_singleton()
	update_all()
	AssetIO.obj_to_call_on_table_update.push_back(self)

func _exit_tree() -> void:
	AssetIO.obj_to_call_on_table_update.erase(self)

func clear():
	cl.clear()

func update_all():
	cl.clear()
	update_collections()

func update_collections():
	var collections = asset_library.collection_get_list()
	cl.push_bold()
	if collections.size() == 0:
		cl.append_text("No Collections")
		cl.pop() #/bold
	else:
		cl.append_text("[b]Collections[/b]\n")
		cl.pop() #/bold
		
		cl.push_table(5)
		
		cl.push_cell()
		cl.set_cell_row_background_color(Color.DARK_SLATE_GRAY,Color.BURLYWOOD)
		cl.set_cell_border_color(Color.SEA_GREEN)
		cl.append_text("ID")
		cl.pop() #end cel
		
		cl.push_cell()
		cl.set_cell_row_background_color(Color.DARK_SLATE_GRAY,Color.BURLYWOOD)
		cl.set_cell_border_color(Color.SEA_GREEN)
		cl.append_text("Name")
		cl.pop() #end cel
	
		cl.push_cell()
		cl.set_cell_row_background_color(Color.DARK_SLATE_GRAY,Color.BURLYWOOD)
		cl.set_cell_border_color(Color.SEA_GREEN)
		cl.append_text("Mesh\nid")
		cl.pop() #end cel
	
		cl.push_cell()
		cl.set_cell_row_background_color(Color.DARK_SLATE_GRAY,Color.BURLYWOOD)
		cl.set_cell_border_color(Color.SEA_GREEN)
		cl.append_text("sub\ncollections")
		cl.pop() #end cel
		
		cl.push_cell()
		cl.set_cell_row_background_color(Color.DARK_SLATE_GRAY,Color.BURLYWOOD)
		cl.set_cell_border_color(Color.SEA_GREEN)
		cl.append_text("collisions")
		cl.pop() #end cel
	
		for cid in collections:
			cl.push_cell()
			cl.set_cell_row_background_color(Color.DARK_BLUE,Color.DARK_BLUE)
			cl.set_cell_border_color(Color.SEA_GREEN)
			cl.append_text(str(cid))
			cl.pop() #end cel
			
			cl.push_cell()
			cl.set_cell_border_color(Color.SEA_GREEN)
			cl.append_text(str(asset_library.collection_get_name(cid)))
			cl.pop() #end cel
			
			cl.push_cell()
			cl.set_cell_border_color(Color.SEA_GREEN)
			cl.append_text(str(asset_library.collection_get_item_id(cid)))
			cl.pop() #end cel
			
			cl.push_cell()
			cl.set_cell_border_color(Color.SEA_GREEN)
			cl.append_text(str(asset_library.collection_get_sub_collections(cid).size()))
			cl.pop() #end cel
			
			cl.push_cell()
			cl.set_cell_border_color(Color.SEA_GREEN)
			var col_text = str(asset_library.collection_get_collision_count(cid))
			col_text += "("+asset_library.collection_get_physics_setting(cid)+")"
			col_text += "["+str(asset_library.collection_get_colcutoff(cid))+"]"
			cl.append_text(col_text)
			cl.pop() #end cel
	cl.pop() # end table
	

func asset_table_update():
	update_all()

func clear_asset_table():
	DirAccess.remove_absolute(MHlod.get_mesh_root_dir())
	DirAccess.make_dir_absolute(MHlod.get_mesh_root_dir())
	asset_library.clear_table()
	update_all()

func reload_asset_table():
	var asset_table = load(MAssetTable.get_asset_table_path())
	MAssetTable.set_singleton(asset_table)
