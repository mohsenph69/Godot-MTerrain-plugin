#include "mgrass.h"
#include "../mgrid.h"




void MGrass::_bind_methods() {
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

}
MGrass::~MGrass(){

}

void MGrass::init_grass(MGrid* grid) {
    ERR_FAIL_COND(!grass_data.is_valid());
    UtilityFunctions::print("Init grass ", get_name());
    grass_region_pixel_size = (uint32_t)round((float)grid->region_size_meter/grass_data->density);
    UtilityFunctions::print("grass_region_pixel_size ", itos(grass_region_pixel_size));
    int64_t data_size = (grass_region_pixel_size*grid->get_regions_count())/8;
    if(grass_data->data.size()==0){
        // grass data is empty so we create grass data here
        grass_data->data.resize(data_size);
    } else {
        // Data already created so we check if the data size is correct
        ERR_FAIL_COND_EDMSG(grass_data->data.size()!=data_size,"Grass data not match, Some Terrain setting and grass density should not change after grass data creation, change back setting or create a new grass data");
    }
    lod_count = grid->lod_distance.size() + 1;
    is_grass_init = true;
}

void MGrass::clear_grass(){

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
        PropertyInfo m(Variant::OBJECT,"Material_LOD_"+itos(i),PROPERTY_HINT_RESOURCE_TYPE,"Material",PROPERTY_USAGE_EDITOR);
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

