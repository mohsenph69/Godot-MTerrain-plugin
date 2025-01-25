#include "mhlod.h"

#include <godot_cpp/classes/resource_loader.hpp>
#ifdef DEBUG_ENABLED
#include "../editor/masset_table.h"
#endif

const char* MHlod::asset_root_dir = "res://massets/";
const char* MHlod::mesh_root_dir = "res://massets/meshes/";
const char* MHlod::material_table_path = "res://massets/material_table.res";
const char* MHlod::physics_settings_dir = "res://massets/collision_setting/";

Ref<MMaterialTable> MHlod::material_table;

void MHlod::_bind_methods(){

    ClassDB::bind_static_method("MHlod",D_METHOD("get_material_from_table","material_id"), &MHlod::get_material_from_table);
    ClassDB::bind_static_method("MHlod",D_METHOD("get_mesh_root_dir"), &MHlod::get_mesh_root_dir);
    ClassDB::bind_static_method("MHlod",D_METHOD("get_material_table_path"), &MHlod::get_material_table_path);
    ClassDB::bind_static_method("MHlod",D_METHOD("get_physics_settings_dir"), &MHlod::get_physics_settings_dir);
    ClassDB::bind_static_method("MHlod",D_METHOD("get_mesh_path","mesh_id"), &MHlod::get_mesh_path);

    ClassDB::bind_method(D_METHOD("set_join_at_lod","input"), &MHlod::set_join_at_lod);
    ClassDB::bind_method(D_METHOD("get_join_at_lod"), &MHlod::get_join_at_lod);
    ADD_PROPERTY(PropertyInfo(Variant::INT,"join_at_lod",PROPERTY_HINT_NONE,"",PROPERTY_USAGE_STORAGE),"set_join_at_lod","get_join_at_lod");

    ClassDB::bind_method(D_METHOD("add_mesh_item","transform","mesh","material","shadow_settings","gi_mode","render_layers","hlod_layers"),&MHlod::add_mesh_item);
    ClassDB::bind_method(D_METHOD("add_sub_hlod","transform","hlod","scene_layers"), &MHlod::add_sub_hlod);
    ClassDB::bind_method(D_METHOD("get_mesh_items_ids"), &MHlod::get_mesh_items_ids);
    ClassDB::bind_method(D_METHOD("get_last_lod_with_mesh"), &MHlod::get_last_lod_with_mesh);
    ClassDB::bind_method(D_METHOD("insert_item_in_lod_table","item_id","lod"), &MHlod::insert_item_in_lod_table);
    ClassDB::bind_method(D_METHOD("get_lod_table"), &MHlod::get_lod_table);

    ClassDB::bind_method(D_METHOD("add_shape_sphere","transform","radius"), &MHlod::add_shape_sphere);

    ClassDB::bind_method(D_METHOD("_set_data","input"), &MHlod::_set_data);
    ClassDB::bind_method(D_METHOD("_get_data"), &MHlod::_get_data);
    ADD_PROPERTY(PropertyInfo(Variant::DICTIONARY,"_data",PROPERTY_HINT_NONE,""),"_set_data","_get_data");


    ClassDB::bind_method(D_METHOD("set_baker_path","input"), &MHlod::set_baker_path);
    ClassDB::bind_method(D_METHOD("get_baker_path"), &MHlod::get_baker_path);
    ADD_PROPERTY(PropertyInfo(Variant::STRING,"baker_path"),"set_baker_path","get_baker_path");
    #ifdef DEBUG_ENABLED
    ClassDB::bind_method(D_METHOD("get_used_mesh_ids"), &MHlod::get_used_mesh_ids);
    #endif

    ClassDB::bind_method(D_METHOD("start_test"), &MHlod::start_test);
}


Ref<Material> MHlod::get_material_from_table(int material_id){
    if(material_table.is_null()){
        String p = String(material_table_path);
        if(ResourceLoader::get_singleton()->exists(p)){
            material_table = ResourceLoader::get_singleton()->load(p);
        }
        if(material_table.is_null()){
            return nullptr;
        }
    }
    if(!material_table->paths.has(material_id)){
        return nullptr;
    }
    return ResourceLoader::get_singleton()->load(material_table->paths[material_id]);
}

String MHlod::get_mesh_root_dir(){
    return String(mesh_root_dir);
}

String MHlod::get_material_table_path(){
    return String(material_table_path);
}

String MHlod::get_physics_settings_dir(){
    return String(physics_settings_dir);
}

String MHlod::get_mesh_path(int64_t mesh_id){
    return String(mesh_root_dir) + itos(mesh_id) + String(".res");
}

void MHlod::Item::create(){
    switch (type)
    {
    case Type::MESH:
        new (&mesh) MHLodItemMesh();
        break;
    case Type::COLLISION:
        new (&collision) MHLodItemCollision();
        break;
    default:
        ERR_FAIL_MSG("Undefine Item Type!"); 
        break;
    }
}

void MHlod::Item::copy(const Item& other){
    type = other.type;
    item_layers = other.item_layers;
    transform_index = other.transform_index;
    lod = other.lod;
    create();
    switch (type)
    {
    case Type::MESH:
        mesh = other.mesh;
        break;
    case Type::COLLISION:
        collision = other.collision;
        break;
    default:
        ERR_FAIL_MSG("Undefine Item Type!"); 
        break;
    }
}

void MHlod::Item::clear(){
    if(type==Type::NONE){
        return;
    }
    switch (type)
    {
    case Type::MESH:
        mesh.~MHLodItemMesh();
        break;
    case Type::COLLISION:
        collision.~MHLodItemCollision();
        break;
    default:
        ERR_FAIL_MSG("Undefine Item Type!"); 
        break;
    }
}

MHlod::Item::Item(){

}

MHlod::Item::Item(Type _type){
    type = _type;
    create();
}

MHlod::Item::~Item(){
    type = Type::NONE;
    clear();
}

MHlod::Item::Item(const Item& other){
    copy(other);
}

MHlod::Item& MHlod::Item::operator=(const Item& other){
    copy(other);
    return *this;
}

void MHlod::Item::load(){
    switch (type)
    {
    case Type::MESH:
        mesh.load();
        break;
    case Type::COLLISION:
        break;
    default:
        ERR_FAIL_MSG("Undefine Item Type!"); 
        break;
    }
}

void MHlod::Item::unload(){
    switch (type)
    {
    case Type::MESH:
        mesh.unload();
        break;
    case Type::COLLISION:
        break;
    default:
        ERR_FAIL_MSG("Undefine Item Type!"); 
        break;
    }
}

void MHlod::Item::add_user(){
    if(user_count==0){
        load();
    }
    user_count++;
}

void MHlod::Item::remove_user(){
    ERR_FAIL_COND(user_count==0);
    user_count--;
    if(user_count==0){
        unload();
    }
}

void MHlod::Item::set_data(const Dictionary& d){
    ERR_FAIL_COND(!d.has("type"));
    type = (MHlod::Type)((int)d["type"]);
    transform_index = (int)d["t_index"];
    lod = (int)d["lod"];
    item_layers = d.has("item_layers") ? (int64_t)d["item_layers"] : 0;
    switch (type)
    {
    case Type::MESH:
        new (&mesh) MHLodItemMesh();
        mesh.set_data(d["data"]);
        break;
    case Type::COLLISION:
        //new (&collision) MHLodItemCollision();
        //collision.set_data(d);
        break;
    default:
        ERR_FAIL_MSG("Undefine Item Type!"); 
        break;
    }
}

Dictionary MHlod::Item::get_data() const{
    PackedByteArray data;
    switch (type)
    {
    case Type::MESH:
        data = mesh.get_data();
        break;
    case Type::COLLISION:
        //item_data = collision.get_data();
        break;
    default:
        ERR_FAIL_V_MSG(Dictionary(),"Undefine Item Type!"); 
        break;
    }
    Dictionary d;
    d["type"] = (int)type;
    d["t_index"] = transform_index;
    d["item_layers"] = item_layers;
    d["lod"] = (int)lod;
    d["data"] = data;
    return d;
}








////////////////////////
//////////////////////////////////////////////
///////////////////////

void MHlod::set_join_at_lod(int input){
    join_at_lod = input;
}

int MHlod::get_join_at_lod(){
    return join_at_lod;
}

void MHlod::_get_sub_hlod_size_rec(int& size){
    size += sub_hlods.size();
    for(int i=0; i < sub_hlods.size(); i++){
        Ref<MHlod> _s = sub_hlods[i];
        ERR_CONTINUE_MSG(_s.is_null(),"Subhlod is not valid!");
        _s->_get_sub_hlod_size_rec(size);
    }
}

int MHlod::get_sub_hlod_size_rec(){
    int size = 0;
    _get_sub_hlod_size_rec(size);
    return size;
}

void MHlod::add_sub_hlod(const Transform3D& transform,Ref<MHlod> hlod,uint16_t scene_layers){
    ERR_FAIL_COND(hlod.is_null());
    sub_hlods.push_back(hlod);
    sub_hlods_transforms.push_back(transform);
    sub_hlods_scene_layers.push_back(scene_layers);
}

int MHlod::add_mesh_item(const Transform3D& transform,const PackedInt64Array& mesh,const PackedInt32Array& material,const PackedByteArray& shadow_settings,const PackedByteArray& gi_modes,int32_t render_layers,int32_t hlod_layers){
    int lod_count = mesh.size();
    ERR_FAIL_COND_V(lod_count==0,-1);
    ERR_FAIL_COND_V(shadow_settings.size()!=lod_count,-1);
    ERR_FAIL_COND_V(gi_modes.size()!=lod_count,-1);

    int item_index = item_list.size();
    int transform_index = transforms.size();
    transforms.push_back(transform);
    /// Lasts for checking duplicate
    int64_t last_mesh;
    uint8_t last_shadow_setting;
    uint8_t last_gi_mode_setting;
    /////////////////////////////////
    int lod = -1;
    for(int i=0 ; i < lod_count; i++){
        lod++;
        if(
            last_mesh == mesh[i] &&
            last_shadow_setting == shadow_settings[i] &&
            last_gi_mode_setting == gi_modes[i]
        ) {
            /// Duplicate
            continue;
        }
        last_mesh = mesh[i];
        last_shadow_setting = shadow_settings[i];
        last_gi_mode_setting = gi_modes[i];


        Item _item(Type::MESH);
        _item.lod = lod;
        _item.item_layers = hlod_layers;
        _item.transform_index = transform_index;
        /*
        _item.mesh.path = item_path;
        _item.mesh.shadow_setting = (GeometryInstance3D::ShadowCastingSetting)shadow_settings[i];
        _item.mesh.gi_mode = (GeometryInstance3D::GIMode)gi_modes[i];
        */
        _item.mesh.set_data(mesh[i],material[i],shadow_settings[i],gi_modes[i],render_layers);
        item_list.push_back(_item);
    }
    return item_index;
}

Dictionary MHlod::get_mesh_item(int item_id){
    Dictionary out;
    /*
    ERR_FAIL_INDEX_V(item_id,item_list.size(),out);
    ERR_FAIL_COND_V(item_list[item_id].type!=Type::MESH,out);
    int transform_index = item_list[item_id].transform_index;
    ERR_FAIL_INDEX_V(transform_index,transforms.size(),out);
    out["transform"] = transforms[transform_index];
    PackedStringArray mesh_paths;
    PackedStringArray material_paths;
    PackedInt32Array shadow_setting;
    PackedInt32Array gi_mode;
    int8_t last_lod = -1;
    while (true)
    {
        if(item_list.size() == item_id || item_list[item_id].transform_index != transform_index){
            /// Reach end of this item
            break;
        }
        if(item_list[item_id].lod > (last_lod + 1) && mesh_paths.size() > 0){
            // Duplicating as we have same lod
            int ci = mesh_paths.size() - 1;
            mesh_paths.push_back(mesh_paths[ci]);
            material_paths.push_back(material_paths[ci]);
            shadow_setting.push_back(shadow_setting[ci]);
            gi_mode.push_back(gi_mode[ci]);
            item_id++;
            last_lod++;
            continue;;
        }
        ERR_FAIL_COND_V(item_list[item_id].type!=Type::MESH,out);
        PackedStringArray __p = item_list[item_id].mesh.path.rsplit(";");
        ERR_FAIL_COND_V(__p.size()!=2,out);
        mesh_paths.push_back(__p[0]);
        material_paths.push_back(__p[1]);
        shadow_setting.push_back(item_list[item_id].mesh.get_shadow_setting());
        gi_mode.push_back(item_list[item_id].mesh.gi_mode);
        item_id++;
    }
    out["mesh_paths"] = mesh_paths;
    out["material_paths"] = material_paths;
    out["shadow_settings"] = shadow_setting;
    out["gi_modes"] = gi_mode;
    */
    return out;
}

int MHlod::add_collision_item(const Transform3D& transform,const PackedStringArray& shape_path){

    return 0;
}

PackedInt32Array MHlod::get_mesh_items_ids() const{
    PackedInt32Array out;
    int last_transform_index = -1;
    for(int i=0; i < item_list.size(); i++){
        if(item_list[i].transform_index != last_transform_index && item_list[i].type == Type::MESH){
            last_transform_index = item_list[i].transform_index;
            out.push_back(i);
        }
    }
    return out;
}

int MHlod::get_last_lod_with_mesh() const{
    for(int l=lods.size()-1; l >= 0; l--){
        const VSet<int32_t>& items_ids = lods.ptr()[l];
        for(int j=0; j < items_ids.size(); j++){
            int32_t item_id = items_ids[j];
            if(item_list[item_id].type == Type::MESH){
                return l;
            }
        }
    }
    return -1;
}

void MHlod::insert_item_in_lod_table(int item_id,int lod){
    ERR_FAIL_INDEX(item_id,item_list.size());
    if(lod >= lods.size()){
        lods.resize(lod+1);
    }
    if(item_list[item_id].lod != lod){
        int transform_index = item_list[item_id].transform_index;
        item_id++;
        while(true){
            if(item_id >= item_list.size() || transform_index != item_list[item_id].transform_index || item_list[item_id].lod > lod){
                item_id--;
                break;
            }
            if(item_list[item_id].lod == lod){
                break;
            }
            item_id++;
        }
    }
    lods.ptrw()[lod].insert(item_id);
}

Array MHlod::get_lod_table(){
    Array out;
    for(int i=0; i < lods.size(); i++){
        PackedInt32Array l;
        l.resize(lods[i].size());
        for(int j=0; j < lods[i].size(); j++){
            l.set(j,lods[i][j]);
        }
        out.push_back(l);
    }
    return out;
}

void MHlod::clear(){
    lods.clear();
    transforms.clear();
    item_list.clear();
    sub_hlods.clear();
    sub_hlods_transforms.clear();
}

int MHlod::add_shape_sphere(const Transform3D& _transform,float radius){
    MHLodItemCollision mcol;
    mcol.param.type = MHLodItemCollision::Param::Type::SHPERE;
    mcol.param.param_1 = radius;
    Item _item(MHlod::Type::COLLISION);
    _item.collision = mcol;
    transforms.push_back(_transform);
    _item.transform_index = transforms.size() - 1;
    item_list.push_back(_item);
    return item_list.size() - 1;
}

void MHlod::set_baker_path(const String& input){
    #ifdef DEBUG_ENABLED
    baker_path = input;
    #endif
}

String MHlod::get_baker_path(){
    #ifdef DEBUG_ENABLED
    return baker_path;
    #else
    return String("");
    #endif
}
#ifdef DEBUG_ENABLED
Dictionary MHlod::get_used_mesh_ids() const{
    Dictionary out;
    for(const Item& item : item_list){
        if(item.type == Type::MESH){
            int32_t mesh_id = item.mesh.mesh_id;
            mesh_id = mesh_id < 0 ? MAssetTable::mesh_join_get_first_lod(mesh_id) : MAssetTable::mesh_item_get_first_lod(mesh_id);
            out[mesh_id] = true;
        }
    }
    return out;
}
#endif

void MHlod::_set_data(const Dictionary& data){
    ERR_FAIL_COND(!data.has("items"));
    ERR_FAIL_COND(!data.has("lods"));
    ERR_FAIL_COND(!data.has("transforms"));
    ERR_FAIL_COND(!data.has("subhlods"));
    ERR_FAIL_COND(!data.has("subhlods_transforms"));
    item_list.clear();
    lods.clear();
    transforms.clear();
    sub_hlods.clear();
    sub_hlods_transforms.clear();
    Array __lods = data["lods"];
    for(int i=0; i < __lods.size();i++){
        PackedInt32Array __lod = __lods[i];
        VSet<int32_t> __l;
        for(int j=0; j < __lod.size(); j++){
            __l.insert(__lod[j]);
        }
        lods.push_back(__l);
    }
    /// Items
    Array __items = data["items"];
    item_list.resize(__items.size());
    for(int i=0; i < __items.size(); i++){
        item_list.ptrw()[i].set_data(__items[i]);
    }
    Array __transforms = data["transforms"];
    transforms.resize(__transforms.size());
    for(int i=0; i < __transforms.size(); i++){
        transforms.set(i,__transforms[i]);
    }
    Array __subhlods = data["subhlods"];
    Array __subhlods_transforms = data["subhlods_transforms"];
    ERR_FAIL_COND(__subhlods.size()!=__subhlods_transforms.size());
    for(int i=0; i < __subhlods.size(); i++){
        Ref<MHlod> __shlod = __subhlods[i];
        if(__shlod.is_null()){
            continue;
        }
        Transform3D st = __subhlods_transforms[i];
        sub_hlods.push_back(__shlod);
        sub_hlods_transforms.push_back(st);
    }
    PackedByteArray __sub_hlod_scene_layers = data["sub_hlods_scene_layers"];
    sub_hlods_scene_layers.resize(__subhlods.size());
    memcpy(sub_hlods_scene_layers.ptrw(),__sub_hlod_scene_layers.ptr(),sub_hlods_scene_layers.size() * sizeof(uint16_t));
}

Dictionary MHlod::_get_data() const{
    Dictionary out;
    //// LODS
    Array __lods;
    for(int i=0; i < lods.size(); i++){
        PackedInt32Array __lod;
        VSet<int32_t> __l = lods[i];
        for(int j=0; j < __l.size(); j++){
            __lod.push_back(__l[j]);
        }
        __lods.push_back(__lod);
    }
    out["lods"] = __lods;
    /// Items
    Array __items;
    __items.resize(item_list.size());
    for(int i=0; i < item_list.size(); i++){
        __items[i] = item_list[i].get_data();
    }
    out["items"] = __items;
    Array __transforms;
    __transforms.resize(transforms.size());
    for(int i=0; i < transforms.size(); i++){
        __transforms[i] = transforms[i];
    }
    out["transforms"] = __transforms;
    Array __subhlods;
    Array __subhlods_transforms;
    __subhlods.resize(sub_hlods.size());
    __subhlods_transforms.resize(sub_hlods.size());
    for(int i=0; i < sub_hlods.size(); i++){
        __subhlods[i] = sub_hlods[i];
        __subhlods_transforms[i] = sub_hlods_transforms[i];
    }
    out["subhlods"] = __subhlods;
    out["subhlods_transforms"] = __subhlods_transforms;
    PackedByteArray __sub_hlod_scene_layers;
    __sub_hlod_scene_layers.resize(sub_hlods_scene_layers.size() * sizeof(uint16_t));
    memcpy(__sub_hlod_scene_layers.ptrw(),sub_hlods_scene_layers.ptr(),__sub_hlod_scene_layers.size());
    out["sub_hlods_scene_layers"] = __sub_hlod_scene_layers;
    return out;
}