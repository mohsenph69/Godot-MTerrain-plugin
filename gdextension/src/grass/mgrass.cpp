#include "mgrass.h"
#include "../mgrid.h"


#define CHUNK_INFO grid->grid_update_info[grid_index]


void MGrass::_bind_methods() {
    ADD_SIGNAL(MethodInfo("grass_is_ready"));
    ClassDB::bind_method(D_METHOD("set_grass_by_pixel","x","y","val"), &MGrass::set_grass_by_pixel);
    ClassDB::bind_method(D_METHOD("get_grass_by_pixel","x","y"), &MGrass::get_grass_by_pixel);
    ClassDB::bind_method(D_METHOD("update_dirty_chunks"), &MGrass::update_dirty_chunks);

    ClassDB::bind_method(D_METHOD("set_grass_data","input"), &MGrass::set_grass_data);
    ClassDB::bind_method(D_METHOD("get_grass_data"), &MGrass::get_grass_data);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT,"grass_data",PROPERTY_HINT_RESOURCE_TYPE,"MGrassData"),"set_grass_data","get_grass_data");
    ClassDB::bind_method(D_METHOD("set_grass_in_cell","input"), &MGrass::set_grass_in_cell);
    ClassDB::bind_method(D_METHOD("get_grass_in_cell"), &MGrass::get_grass_in_cell);
    ADD_PROPERTY(PropertyInfo(Variant::INT, "grass_in_cell"),"set_grass_in_cell","get_grass_in_cell");
    ClassDB::bind_method(D_METHOD("set_min_grass_cutoff","input"), &MGrass::set_min_grass_cutoff);
    ClassDB::bind_method(D_METHOD("get_min_grass_cutoff"), &MGrass::get_min_grass_cutoff);
    ADD_PROPERTY(PropertyInfo(Variant::INT, "min_grass_cutoff"),"set_min_grass_cutoff","get_min_grass_cutoff");
    ClassDB::bind_method(D_METHOD("set_meshes","input"), &MGrass::set_meshes);
    ClassDB::bind_method(D_METHOD("get_meshes"), &MGrass::get_meshes);
    ADD_PROPERTY(PropertyInfo(Variant::ARRAY,"meshes",PROPERTY_HINT_NONE,"",PROPERTY_USAGE_STORAGE),"set_meshes","get_meshes");
    ClassDB::bind_method(D_METHOD("set_materials"), &MGrass::set_materials);
    ClassDB::bind_method(D_METHOD("get_materials"), &MGrass::get_materials);
    ADD_PROPERTY(PropertyInfo(Variant::ARRAY,"materials",PROPERTY_HINT_NONE,"",PROPERTY_USAGE_STORAGE),"set_materials","get_materials");
}

MGrass::MGrass(){
    dirty_points_id = memnew(VSet<int>);
}
MGrass::~MGrass(){
    memdelete(dirty_points_id);
}

void MGrass::init_grass(MGrid* _grid) {
    ERR_FAIL_COND(!grass_data.is_valid());
    grid = _grid;
    scenario = grid->get_scenario();
    region_grid_width = grid->get_region_grid_size().x;
    UtilityFunctions::print("Init grass ", get_name());
    grass_region_pixel_width = (uint32_t)round((float)grid->region_size_meter/grass_data->density);
    grass_region_pixel_size = grass_region_pixel_width*grass_region_pixel_width;
    base_grid_size_in_pixel = (uint32_t)round((double)grass_region_pixel_width/(double)grid->region_size);
    UtilityFunctions::print("grass_region_pixel_width ", itos(grass_region_pixel_width));
    width = grass_region_pixel_width*grid->get_region_grid_size().x;
    height = grass_region_pixel_width*grid->get_region_grid_size().z;
    UtilityFunctions::print("Grass Pixel Limit ", width, " , ",height);
    int64_t data_size = ((grass_region_pixel_size*grid->get_regions_count() - 1)/8) + 1;
    UtilityFunctions::print("Grass data size ", data_size);
    if(grass_data->data.size()==0){
        // grass data is empty so we create grass data here
        grass_data->data.resize(data_size);
    } else {
        // Data already created so we check if the data size is correct
        ERR_FAIL_COND_EDMSG(grass_data->data.size()!=data_size,"Grass data not match, Some Terrain setting and grass density should not change after grass data creation, change back setting or create a new grass data");
    }
    meshe_rids.clear();
    material_rids.clear();
    for(int i=0;i<meshes.size();i++){
        Ref<Mesh> m = meshes[i];
        if(m.is_valid()){
            meshe_rids.push_back(m->get_rid());
        } else {
            meshe_rids.push_back(RID());
        }
    }
    for(int i=0;i<materials.size();i++){
        Ref<Material> m = materials[i];
        if(m.is_valid()){
            material_rids.push_back(m->get_rid());
        } else {
            material_rids.push_back(RID());
        }
    }
    is_grass_init = true;
    emit_signal("grass_is_ready");
}

void MGrass::clear_grass(){
    for(HashMap<int64_t,MGrassChunk*>::Iterator it = grid_to_grass.begin();it!=grid_to_grass.end();++it){
        memdelete(it->value);
    }
    grid_to_grass.clear();
    is_grass_init = false;
}

void MGrass::update_dirty_chunks(){
    update_mutex.lock();
    for(int i=0;i<dirty_points_id->size();i++){
        UtilityFunctions::print("dirty_points ",(*dirty_points_id)[i]);
        int64_t terrain_instance_id = grid->get_point_instance_id_by_point_id((*dirty_points_id)[i]);
        UtilityFunctions::print("terrain_instance_id ",terrain_instance_id);
        ERR_FAIL_COND(!grid_to_grass.has(terrain_instance_id));
        MGrassChunk* g = grid_to_grass[terrain_instance_id];
        UtilityFunctions::print("MGrassChunk count ",g->count, " right ",g->pixel_region.right);
        create_grass_chunk(-1,g);
    }
    update_mutex.unlock();
    memdelete(dirty_points_id);
    dirty_points_id = memnew(VSet<int>);
}

void MGrass::update_grass(){
    /*
    set_grass(0,0,true);
    set_grass(1,0,true);
    set_grass(31,0,true);
    set_grass(32,0,true);
    set_grass(33,0,true);
    set_grass(1023,0,true);
    set_grass(0,1023,true);
    set_grass(511,511,true);
    set_grass(512,512,true);
    set_grass(1023,1023,true);
    */
    int new_chunk_count = grid->grid_update_info.size();
    //UtilityFunctions::print("new_chunk_count ",new_chunk_count);
    update_mutex.lock();
    for(int i=0;i<new_chunk_count;i++){
        create_grass_chunk(i);
        //return; // For now for test remove later
    }
    update_mutex.unlock();
}

void MGrass::create_grass_chunk(int grid_index,MGrassChunk* grass_chunk){
    MGrassChunk* g;
    MPixelRegion px;
    if(grass_chunk==nullptr){
    px.left = (uint32_t)round(((double)grass_region_pixel_width)*CHUNK_INFO.region_offset_ratio.x);
    px.top = (uint32_t)round(((double)grass_region_pixel_width)*CHUNK_INFO.region_offset_ratio.y);
    int size_scale = pow(2,CHUNK_INFO.chunk_size);
    px.right = px.left + base_grid_size_in_pixel*size_scale - 1;
    px.bottom = px.top + base_grid_size_in_pixel*size_scale - 1;
    //UtilityFunctions::print("Region id ", CHUNK_INFO.region_id);
    //UtilityFunctions::print("L ",itos(px.left)," R ",itos(px.right)," T ",itos(px.top), " B ",itos(px.bottom));
    g = memnew(MGrassChunk(px,CHUNK_INFO.region_world_pos,CHUNK_INFO.lod,CHUNK_INFO.region_id));
    grid_to_grass.insert(CHUNK_INFO.terrain_instance.get_id(),g);
    } else {
        g = grass_chunk;
        px = grass_chunk->pixel_region;
    }
    int lod_scale = pow(2,g->lod);
    int grass_region_pixel_width_lod = grass_region_pixel_width/lod_scale;


    

    const uint8_t* ptr = grass_data->data.ptr() + g->region_id*grass_region_pixel_size/8;

    //UtilityFunctions::print("OFFSET ",g->region_id*grass_region_pixel_size/8 , " Region id ",g->region_id);
    uint32_t count=0;
    uint32_t index;
    uint32_t x=px.left;
    uint32_t y=px.top;
    uint32_t i=0;
    uint32_t j=1;
    PackedFloat32Array buffer;
    while (true)
    {
        while (true){
            x = px.left + i*lod_scale;
            if(x>px.right){
                break;
            }
            i++;
            uint32_t offs = (y*grass_region_pixel_width + x);
            //UtilityFunctions::print("OFFSET in region ", offs);
            uint32_t ibyte = offs/8;
            //UtilityFunctions::print("ibyte ", ibyte);
            uint32_t ibit = offs%8;
            //UtilityFunctions::print("ibit ", ibit);
            if( (ptr[ibyte] & (1 << ibit)) != 0){
                //UtilityFunctions::print("Found some grass ",x," , ",y);
                for(int r=0;r<grass_in_cell;r++){
                    index=count*BUFFER_STRID_FLOAT;
                    buffer.resize(buffer.size()+12);
                    buffer[index]=1;
                    buffer[index+5]=1;
                    buffer[index+10]=1;
                    int rand_index = y*grass_region_pixel_width_lod + x + r;
                    Vector3 pos;
                    pos.x = g->world_pos.x + x*grass_data->density;
                    pos.z = g->world_pos.z + y*grass_data->density;
                    buffer.set(index+3,pos.x);
                    buffer.set(index+7,grid->get_height(pos));
                    buffer.set(index+11,pos.z);
                    count++;
                }
            }
        }
        i= 0;
        y= px.top + j*lod_scale;
        if(y>px.bottom){
            break;
        }
        j++;
    }
    // Discard grass chunk in case there is no mesh RID or count is less than min_grass_cutoff
    if(meshe_rids[g->lod] == RID() || count < min_grass_cutoff){
        return;
    }
    g->set_buffer(count,scenario,meshe_rids[g->lod],material_rids[g->lod],buffer);
    // IF grass chunk is nullpointer this is not a grass chunk update
    // it is a grass chunk creation so we relax that
    if(grass_chunk==nullptr){
        g->relax();
    }
    to_be_visible.push_back(g);
}

void MGrass::apply_update_grass(){
    for(int i=0;i<to_be_visible.size();i++){
        to_be_visible[i]->unrelax();
    }
    for(int i=0;i<grid->remove_instance_list.size();i++){
        if(grid_to_grass.has(grid->remove_instance_list[i].get_id())){
            MGrassChunk* g = grid_to_grass.get(grid->remove_instance_list[i].get_id());
            memdelete(g);
            grid_to_grass.erase(grid->remove_instance_list[i].get_id());
        } else {
            WARN_PRINT("Instance not found for removing");
        }
    }
    to_be_visible.clear();
}

void MGrass::recalculate_grass_config(int max_lod){
    lod_count = max_lod + 1;
    if(meshes.size()!=lod_count){
        meshes.resize(lod_count);
    }
    if(materials.size()!=lod_count){
        materials.resize(lod_count);
    }
    notify_property_list_changed();
}

void MGrass::set_grass_by_pixel(uint32_t px, uint32_t py, bool p_value){
    ERR_FAIL_INDEX(px, width);
    ERR_FAIL_INDEX(py, height);
    Vector2 flat_pos(float(px)*grass_data->density,float(py)*grass_data->density);
    int point_id = grid->get_point_id_by_non_offs_ws(flat_pos);
    dirty_points_id->insert(point_id);
    uint32_t rx = px/grass_region_pixel_width;
    uint32_t ry = py/grass_region_pixel_width;
    uint32_t rid = ry*region_grid_width + rx;
    uint32_t x = px%grass_region_pixel_width;
    uint32_t y = py%grass_region_pixel_width;
    uint32_t offs = rid*grass_region_pixel_size + y*grass_region_pixel_width + x;
    uint32_t ibyte = offs/8;
    uint32_t ibit = offs%8;

    uint8_t b = grass_data->data[ibyte];

    if(p_value){
        b |= (1 << ibit);
    } else {
        b &= ~(1 << ibit);
    }
    grass_data->data.set(ibyte,b);
}

bool MGrass::get_grass_by_pixel(uint32_t px, uint32_t py) {
    ERR_FAIL_INDEX_V(px, width,false);
    ERR_FAIL_INDEX_V(py, height,false);
    uint32_t rx = px/grass_region_pixel_width;
    uint32_t ry = py/grass_region_pixel_width;
    uint32_t rid = ry*region_grid_width + rx;
    uint32_t x = px%grass_region_pixel_width;
    uint32_t y = py%grass_region_pixel_width;
    uint32_t offs = rid*grass_region_pixel_size + y*grass_region_pixel_width + x;
    uint32_t ibyte = offs/8;
    uint32_t ibit = offs%8;
    return (grass_data->data[ibyte] & (1 << ibit)) != 0;
}

void MGrass::set_grass_data(Ref<MGrassData> d){
    grass_data = d;
}

Ref<MGrassData> MGrass::get_grass_data(){
    return grass_data;
}

void MGrass::set_grass_in_cell(int input){
    ERR_FAIL_COND(input<1);
    grass_in_cell = input;
}
int MGrass::get_grass_in_cell(){
    return grass_in_cell;
}

void MGrass::set_min_grass_cutoff(int input){
    ERR_FAIL_COND(input<0);
    min_grass_cutoff = input;
}

int MGrass::get_min_grass_cutoff(){
    return min_grass_cutoff;
}

void MGrass::set_meshes(Array input){
    meshes = input;
}
Array MGrass::get_meshes(){
    return meshes;
}

void MGrass::set_materials(Array input){
    materials = input;
}

Array MGrass::get_materials(){
    return materials;
}

void MGrass::_get_property_list(List<PropertyInfo> *p_list) const{
    PropertyInfo sub_lod(Variant::INT, "Grass Materials", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_SUBGROUP);
    p_list->push_back(sub_lod);
    for(int i=0;i<materials.size();i++){
        PropertyInfo m(Variant::OBJECT,"Material_LOD_"+itos(i),PROPERTY_HINT_RESOURCE_TYPE,"StandardMaterial3D,ORMMaterial3D,ShaderMaterial",PROPERTY_USAGE_EDITOR);
        p_list->push_back(m);
    }
    PropertyInfo sub_lod2(Variant::INT, "Grass Meshes", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_SUBGROUP);
    p_list->push_back(sub_lod2);
    for(int i=0;i<meshes.size();i++){
        PropertyInfo m(Variant::OBJECT,"Mesh_LOD_"+itos(i),PROPERTY_HINT_RESOURCE_TYPE,"Mesh",PROPERTY_USAGE_EDITOR);
        p_list->push_back(m);
    }
}

bool MGrass::_get(const StringName &p_name, Variant &r_ret) const{
    if(p_name.begins_with("Material_LOD_")){
        PackedStringArray s = p_name.split("_");
        int index = s[2].to_int();
        if(index>materials.size()-1){
            return false;
        }
        r_ret = materials[index];
        return true;
    }
    if(p_name.begins_with("Mesh_LOD_")){
        PackedStringArray s = p_name.split("_");
        int index = s[2].to_int();
        if(index>meshes.size()-1){
            return false;
        }
        r_ret = meshes[index];
        return true;
    }
    return false;
}
bool MGrass::_set(const StringName &p_name, const Variant &p_value){
    if(p_name.begins_with("Material_LOD_")){
        PackedStringArray s = p_name.split("_");
        int index = s[2].to_int();
        if(index>materials.size()-1){
            return false;
        }
        materials[index] = p_value;
        return true;
    }
    if(p_name.begins_with("Mesh_LOD_")){
        PackedStringArray s = p_name.split("_");
        int index = s[2].to_int();
        if(index>meshes.size()-1){
            return false;
        }
        meshes[index] = p_value;
        return true;
    }
    return false;
}