#include "masset_table.h"

#include "mtool.h"

#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/resource_saver.hpp>
#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
int32_t MAssetTable::last_free_mesh_id = -1;
const char* MAssetTable::asset_table_path = "res://massets_editor/asset_table.res";
const char* MAssetTable::asset_editor_root_dir = "res://massets_editor/";
const char* MAssetTable::editor_baker_scenes_dir = "res://massets_editor/baker_scenes/";
const char* MAssetTable::asset_thumbnails_dir = "res://massets_editor/thumbnails/";
const char* MAssetTable::hlod_res_dir = "res://massets/hlod/";
MAssetTable* MAssetTable::asset_table_singelton = nullptr;

void MAssetTable::_bind_methods(){
    ADD_SIGNAL(MethodInfo("finish_import",PropertyInfo(Variant::STRING,"glb_path")));
    ClassDB::bind_static_method("MAssetTable",D_METHOD("set_singleton"), &MAssetTable::set_singleton);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("get_singleton"), &MAssetTable::get_singleton);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("save"), &MAssetTable::save);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("get_asset_table_path"), &MAssetTable::get_asset_table_path);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("get_asset_editor_root_dir"), &MAssetTable::get_asset_editor_root_dir);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("get_editor_baker_scenes_dir"), &MAssetTable::get_editor_baker_scenes_dir);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("get_asset_thumbnails_dir"), &MAssetTable::get_asset_thumbnails_dir);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("get_asset_thumbnails_path","collection_id"), &MAssetTable::get_asset_thumbnails_path);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("get_material_thumbnails_path","material_id"), &MAssetTable::get_material_thumbnails_path);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("get_hlod_res_dir"), &MAssetTable::get_hlod_res_dir);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("reset","hard"), &MAssetTable::reset);

    ClassDB::bind_static_method("MAssetTable",D_METHOD("update_last_free_mesh_id"), &MAssetTable::update_last_free_mesh_id);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("mesh_item_get_max_lod"), &MAssetTable::mesh_item_get_max_lod);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("get_last_free_mesh_id_and_increase"), &MAssetTable::get_last_free_mesh_id_and_increase);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("mesh_item_get_first_lod","mesh_id"), &MAssetTable::mesh_item_get_first_lod);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("mesh_item_get_stop_lod","mesh_id"), &MAssetTable::mesh_item_get_stop_lod);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("mesh_item_ids_no_replace","mesh_id"), &MAssetTable::mesh_item_ids_no_replace);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("mesh_item_meshes_no_replace","mesh_id"), &MAssetTable::mesh_item_meshes_no_replace);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("mesh_item_ids","mesh_id"), &MAssetTable::mesh_item_ids);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("mesh_item_meshes","mesh_id"), &MAssetTable::mesh_item_meshes);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("mesh_item_is_valid","mesh_id"), &MAssetTable::mesh_item_is_valid);

    ClassDB::bind_method(D_METHOD("has_collection","collection_id"), &MAssetTable::has_collection);
    ClassDB::bind_method(D_METHOD("remove_collection","collection_id"), &MAssetTable::remove_collection);
    ClassDB::bind_method(D_METHOD("tag_add","name"), &MAssetTable::tag_add);
    ClassDB::bind_method(D_METHOD("tag_set_name","tag_id","name"), &MAssetTable::tag_set_name);
    ClassDB::bind_method(D_METHOD("tag_get_name","tag_id"), &MAssetTable::tag_get_name);
    ClassDB::bind_method(D_METHOD("tag_get_names"), &MAssetTable::tag_get_names);
    ClassDB::bind_method(D_METHOD("tag_get_id","tag_name"), &MAssetTable::tag_get_id);
    ClassDB::bind_method(D_METHOD("tag_get_collections","tag_id"), &MAssetTable::tag_get_collections);
    ClassDB::bind_method(D_METHOD("tag_get_collections_in_collections","search_collections","tag_id"), &MAssetTable::tag_get_collections_in_collections);
    ClassDB::bind_method(D_METHOD("tags_get_collections_any","tags"), &MAssetTable::tags_get_collections_any);
    ClassDB::bind_method(D_METHOD("tags_get_collections_all","tags"), &MAssetTable::tags_get_collections_all);
    ClassDB::bind_method(D_METHOD("tag_get_tagless_collections"), &MAssetTable::tag_get_tagless_collections);
    ClassDB::bind_method(D_METHOD("tag_names_begin_with","prefix"), &MAssetTable::tag_names_begin_with);
    ClassDB::bind_method(D_METHOD("collection_create","name"), &MAssetTable::collection_create);
    ClassDB::bind_method(D_METHOD("collection_set_glb_id","collection_id","glb_id"), &MAssetTable::collection_set_glb_id);
    ClassDB::bind_method(D_METHOD("collection_get_glb_id","collection_id"), &MAssetTable::collection_get_glb_id);
    ClassDB::bind_method(D_METHOD("collection_set_cache_thumbnail","collection_id","tex","creation_time"), &MAssetTable::collection_set_cache_thumbnail);
    ClassDB::bind_method(D_METHOD("collection_get_cache_thumbnail","collection_id"), &MAssetTable::collection_get_cache_thumbnail);
    ClassDB::bind_method(D_METHOD("collection_get_thumbnail_creation_time","collection_id"), &MAssetTable::collection_get_thumbnail_creation_time);
    ClassDB::bind_method(D_METHOD("collection_set_mesh_id","collection_id","mesh_id"), &MAssetTable::collection_set_mesh_id);
    ClassDB::bind_method(D_METHOD("collection_get_mesh_id","collection_id"), &MAssetTable::collection_get_mesh_id);
    ClassDB::bind_method(D_METHOD("collection_clear","collection_id"), &MAssetTable::collection_clear);
    ClassDB::bind_method(D_METHOD("collection_remove","collection_id"), &MAssetTable::collection_remove);
    ClassDB::bind_method(D_METHOD("collection_get_list"), &MAssetTable::collection_get_list);
    ClassDB::bind_method(D_METHOD("collection_add_tag","collection_id","tag"), &MAssetTable::collection_add_tag);
    ClassDB::bind_method(D_METHOD("collection_add_sub_collection","collection_id","sub_collection_id"), &MAssetTable::collection_add_sub_collection);
    ClassDB::bind_method(D_METHOD("collection_remove_sub_collection","collection_id","sub_collection_id"), &MAssetTable::collection_remove_sub_collection);
    ClassDB::bind_method(D_METHOD("collection_remove_all_sub_collection","collection_id"), &MAssetTable::collection_remove_all_sub_collection);
    ClassDB::bind_method(D_METHOD("collection_get_sub_collections","collection_id"), &MAssetTable::collection_get_sub_collections);
    ClassDB::bind_method(D_METHOD("collection_get_sub_collections_transforms","collection_id"), &MAssetTable::collection_get_sub_collections_transforms);
    ClassDB::bind_method(D_METHOD("collection_get_sub_collections_transform","collection_id","sub_collection_id"), &MAssetTable::collection_get_sub_collections_transform);
    ClassDB::bind_method(D_METHOD("collection_remove_tag","collection_id","tag"), &MAssetTable::collection_remove_tag);
    ClassDB::bind_method(D_METHOD("collection_update_name","collection_id","new_name"), &MAssetTable::collection_update_name);
    ClassDB::bind_method(D_METHOD("collection_get_name","collection_id"), &MAssetTable::collection_get_name);
    ClassDB::bind_method(D_METHOD("collection_get_id","collection_name"), &MAssetTable::collection_get_id);
    ClassDB::bind_method(D_METHOD("collection_get_tags","collection_id"), &MAssetTable::collection_get_tags);
    ClassDB::bind_method(D_METHOD("collection_names_begin_with","prefix"), &MAssetTable::collection_names_begin_with);

    ClassDB::bind_method(D_METHOD("group_exist","group_name"), &MAssetTable::group_exist);
    ClassDB::bind_method(D_METHOD("group_create","group_name"), &MAssetTable::group_create);
    ClassDB::bind_method(D_METHOD("group_rename","group_name","new_name"), &MAssetTable::group_rename);
    ClassDB::bind_method(D_METHOD("group_remove","group_remove"), &MAssetTable::group_remove);
    ClassDB::bind_method(D_METHOD("group_get_list"), &MAssetTable::group_get_list);
    ClassDB::bind_method(D_METHOD("group_count"), &MAssetTable::group_count);
    ClassDB::bind_method(D_METHOD("group_add_tag","group_name","tag"), &MAssetTable::group_add_tag);
    ClassDB::bind_method(D_METHOD("group_remove_tag","group_name","tag"), &MAssetTable::group_remove_tag);
    ClassDB::bind_method(D_METHOD("group_get_tags","group_name"), &MAssetTable::group_get_tags);
    ClassDB::bind_method(D_METHOD("groups_get_collections_any","group_name"), &MAssetTable::groups_get_collections_any);
    ClassDB::bind_method(D_METHOD("groups_get_collections_all","group_name"), &MAssetTable::groups_get_collections_all);
    ClassDB::bind_method(D_METHOD("group_get_collections_with_tags","group_name"), &MAssetTable::group_get_collections_with_tags);

    ClassDB::bind_method(D_METHOD("clear_table"), &MAssetTable::clear_table);

    BIND_ENUM_CONSTANT(NONE);
    BIND_ENUM_CONSTANT(MESH);
    BIND_ENUM_CONSTANT(COLLISION);

    ClassDB::bind_method(D_METHOD("get_data"), &MAssetTable::get_data);
    ClassDB::bind_method(D_METHOD("set_data","data"), &MAssetTable::set_data);
    ADD_PROPERTY(PropertyInfo(Variant::DICTIONARY,"data"),"set_data","get_data");

    ClassDB::bind_method(D_METHOD("get_import_info"), &MAssetTable::get_import_info);
    ClassDB::bind_method(D_METHOD("set_import_info","input"), &MAssetTable::set_import_info);
    ADD_PROPERTY(PropertyInfo(Variant::DICTIONARY,"import_info"),"set_import_info","get_import_info");

    ClassDB::bind_method(D_METHOD("test","data") , &MAssetTable::test);
    ClassDB::bind_method(D_METHOD("debug_test") , &MAssetTable::debug_test);
}

void MAssetTable::set_singleton(Ref<MAssetTable> input){
    make_assets_dir();
    asset_table_singelton = input.ptr();
}

Ref<MAssetTable> MAssetTable::get_singleton(){
    return asset_table_singelton;
}

void MAssetTable::make_assets_dir(){
    if(!DirAccess::dir_exists_absolute(String(MHlod::asset_root_dir))){
        Error err = DirAccess::make_dir_recursive_absolute(String(MHlod::asset_root_dir));
        if(err!=OK){
            WARN_PRINT("Can not create folder");
        }
    }
    if(!DirAccess::dir_exists_absolute(String(MAssetTable::asset_editor_root_dir))){
        Error err = DirAccess::make_dir_recursive_absolute(String(MAssetTable::asset_editor_root_dir));
        if(err!=OK){
            WARN_PRINT("Can not create folder");
        }
    }
    if(!DirAccess::dir_exists_absolute(String(MAssetTable::editor_baker_scenes_dir))){
        Error err = DirAccess::make_dir_recursive_absolute(String(MAssetTable::editor_baker_scenes_dir));
        if(err!=OK){
            WARN_PRINT("Can not create folder");
        }
    }
    if(!DirAccess::dir_exists_absolute(String(MAssetTable::asset_thumbnails_dir))){
        Error err = DirAccess::make_dir_recursive_absolute(String(MAssetTable::asset_thumbnails_dir));
        if(err!=OK){
            WARN_PRINT("Can not create folder");
        }
    }
    if(!DirAccess::dir_exists_absolute(String(MHlod::mesh_root_dir))){
        Error err = DirAccess::make_dir_recursive_absolute(String(MHlod::mesh_root_dir));
        if(err!=OK){
            WARN_PRINT("Can not create folder");
        }
    }
}

void MAssetTable::save(){
    //ERR_FAIL_COND(asset_table_singelton.is_null());
    make_assets_dir();
    Error err = ResourceSaver::get_singleton()->save(asset_table_singelton,asset_table_path);
    ERR_FAIL_COND_MSG(err!=OK,"can not save asset table!");
}

String MAssetTable::get_asset_table_path(){
    return String(asset_table_path);
}

String MAssetTable::get_asset_editor_root_dir(){
    return asset_editor_root_dir;
}

String MAssetTable::get_editor_baker_scenes_dir(){
    return editor_baker_scenes_dir;
}

String MAssetTable::get_asset_thumbnails_dir(){
    return asset_thumbnails_dir;
}

String MAssetTable::get_asset_thumbnails_path(int collection_id){
    return String(asset_thumbnails_dir) + itos(collection_id) + String(".dat");
}

String MAssetTable::get_material_thumbnails_path(int material_id){
    return String(asset_thumbnails_dir) + "material_" + itos(material_id) + String(".dat");
}

String MAssetTable::get_hlod_res_dir(){
    return hlod_res_dir;
}

MAssetTable::Tag::Tag(){
    clear();
}

MAssetTable::Tag::Tag(const PackedInt64Array& input){
    ERR_FAIL_COND(input.size()!=M_TAG_ELEMENT_COUNT);
    for(int i=0; i < M_TAG_ELEMENT_COUNT; i++){
        tag[i] = input[i];
    }
}

bool MAssetTable::Tag::has_tag(int id) const{
    if(id >= M_MAX_TAG){
        return false;
    }
    int el = id / 64;
    int bit = id % 64;
    return (tag[el] & (1LL << bit)) != 0;
}

bool MAssetTable::Tag::has_match(const Tag& other) const {
    for(int i=0 ; i < M_TAG_ELEMENT_COUNT; i++){
        if((other.tag[i] & tag[i]) != 0){
            return true;
        }
    }
    return false;
}

bool MAssetTable::Tag::has_all(const Tag& other) const{
    Tag t = *this&other;
    return t == other;
}

void MAssetTable::Tag::add_tag(int id){
    ERR_FAIL_COND(id >= M_MAX_TAG);
    int el = id / 64;
    int bit = id % 64;
    tag[el] |= (1LL << bit);
}

void MAssetTable::Tag::remove_tag(int id){
    ERR_FAIL_COND(id > M_MAX_TAG);
    int el = id / 64;
    int bit = id % 64;
    tag[el] &= ~(1 << bit);
}

void MAssetTable::Tag::clear(){
    for(int i=0; i < M_TAG_ELEMENT_COUNT; i++){
        tag[i] = 0;
    }
}

bool MAssetTable::Tag::operator==(const Tag& other) const{
    for(int i=0 ; i < M_TAG_ELEMENT_COUNT; i++){
        if(other.tag[i] != tag[i]){
            return false;
        }
    }
    return true;
}

MAssetTable::Tag MAssetTable::Tag::operator&(const Tag& other) const{
    Tag result;
    for(int i=0 ; i < M_TAG_ELEMENT_COUNT; i++){
        result.tag[i] = other.tag[i]&tag[i];
    }
    return result;
}

MAssetTable::Tag MAssetTable::Tag::operator|(const Tag& other) const{
    Tag result;
    for(int i=0 ; i < M_TAG_ELEMENT_COUNT; i++){
        result.tag[i] = other.tag[i]|tag[i];
    }
    return result;
}

MAssetTable::Tag MAssetTable::Tag::operator^(const Tag& other) const{
    Tag result;
    for(int i=0 ; i < M_TAG_ELEMENT_COUNT; i++){
        result.tag[i] = other.tag[i]^tag[i];
    }
    return result;
}

MAssetTable::Tag MAssetTable::Tag::operator~() const{
    Tag result;
    for(int i=0 ; i < M_TAG_ELEMENT_COUNT; i++){
        result.tag[i] = ~tag[i];
    }
    return result;
}



void MAssetTable::Collection::set_glb_id(int32_t input){
    glb_id = input;
}

int32_t MAssetTable::Collection::get_glb_id() const{
    return glb_id;
}

void MAssetTable::Collection::clear(){
    collision_shapes.clear();
    collision_shapes_transforms.clear();
    sub_collections.clear();
    sub_collections_transforms.clear();
    mesh_id = -1;
}

/*
    data structure:
    4byte (int32_t)  -> mesh_id
    4byte (int32_t) -> glb_id_byte_size
    4byte (uint32_t) -> collision_shapes count
    4byte (uint32_t) -> sub_collection_count
    sizeof(Pair<ItemType,int>) * items.size()
    sizeof(Transform3D) * transforms.size()
    Total size = 8 + i_size + t_size
*/
void MAssetTable::Collection::set_save_data(const PackedByteArray& data){
    if(data.size()==0){
        clear();
        return;
    }
    ERR_FAIL_COND(data.size() < 16);
    mesh_id = data.decode_s32(0);
    glb_id = data.decode_s32(4);
    uint32_t  collision_shapes_count = data.decode_u32(8);
    uint32_t sub_collections_count = data.decode_u32(12);
    ERR_FAIL_COND(collision_shapes_count < 0 || sub_collections_count < 0);
    int i_size = sizeof(Pair<ItemType,int>) * collision_shapes_count;
    int t_size = sizeof(Transform3D) * collision_shapes_count;

    int c_size = sizeof(int) * sub_collections_count;
    int ct_size = sizeof(Transform3D) * sub_collections_count;

    ERR_FAIL_COND(data.size() != 16 + i_size + t_size + c_size + ct_size);
    collision_shapes.resize(collision_shapes_count);
    collision_shapes_transforms.resize(collision_shapes_count);

    sub_collections.resize(sub_collections_count);
    sub_collections_transforms.resize(sub_collections_count);

    int header = 16;
    memcpy(collision_shapes.ptrw(),data.ptr()+header,i_size);
    header += i_size;
    memcpy(collision_shapes_transforms.ptrw(),data.ptr()+header,t_size);
    header += t_size;
    memcpy(sub_collections.ptrw(),data.ptr()+header,c_size);
    header += c_size;
    memcpy(sub_collections_transforms.ptrw(),data.ptr()+header,ct_size);
}

PackedByteArray MAssetTable::Collection::get_save_data() const {
    PackedByteArray data;
    ERR_FAIL_COND_V(collision_shapes.size()!=collision_shapes_transforms.size(),data);
    ERR_FAIL_COND_V(sub_collections.size()!=sub_collections_transforms.size(),data);
    if(mesh_id==-1 && collision_shapes.size()==0 && sub_collections.size() == 0){
        return data;
    }
    int i_size = sizeof(CollisionShape) * collision_shapes.size();
    int t_size = sizeof(Transform3D) * collision_shapes_transforms.size();

    int c_size = sizeof(int) * sub_collections.size();
    int ct_size = sizeof(Transform3D) * sub_collections_transforms.size();

    data.resize(16 + i_size + t_size + c_size + ct_size);
    data.encode_s32(0,mesh_id);
    data.encode_s32(4,glb_id);
    data.encode_u32(8,collision_shapes.size());
    data.encode_u32(12,sub_collections.size());
    int header = 16;
    memcpy(data.ptrw()+header,collision_shapes.ptr(),i_size);
    header += i_size;
    memcpy(data.ptrw()+header,collision_shapes_transforms.ptr(),t_size);
    header += t_size;
    memcpy(data.ptrw()+header,sub_collections.ptr(),c_size);
    header += c_size;
    memcpy(data.ptrw()+header,sub_collections_transforms.ptr(),ct_size);
    return data;
}

void MAssetTable::_increase_collection_buffer_size(int q){
    if(q<=0){
        return;
    }
    ERR_FAIL_COND(collections_tags.size() != collections.size());
    ERR_FAIL_COND(collections_tags.size() != collections_names.size());
    int64_t lsize = collections.size();
    godot::Error err = collections.resize(lsize + q);
    ERR_FAIL_COND_MSG(err!=godot::Error::OK,"Can't increase collection item buffer size, possible fragmentation error!");
    err = collections_tags.resize(lsize + q);
    ERR_FAIL_COND_MSG(err!=godot::Error::OK,"Can't increase collection item buffer size, possible fragmentation error!");
    collections_names.resize(lsize + q);
    for(int64_t i=collections.size() - 1; i >= lsize ; i--){
        free_collections.push_back(i);
    }
}

int MAssetTable::_get_free_collection_index(){
    if(free_collections.size()==0){
        _increase_collection_buffer_size(10);
    }
    ERR_FAIL_COND_V(free_collections.size()==0,-1);
    int index = free_collections[free_collections.size() - 1];
    free_collections.remove_at(free_collections.size() - 1);
    return index;
}

bool MAssetTable::has_collection(int id) const{
    return id >= 0 && id < collections.size() && !free_collections.has(id);
}

void MAssetTable::remove_collection(int id){
    ERR_FAIL_COND(!has_collection(id));
    collections.ptrw()[id].clear();
    collections_tags.ptrw()[id].clear();
    collections_names.set(id,"");
    UtilityFunctions::print("Removing collection clearing id ",id, " name afer clear ",collections_names[id]);
    free_collections.push_back(id);
    for(int i=0; i < collections.size(); i++){
        if(collections[i].sub_collections.has(id)){
            collections.ptrw()[i].sub_collections.remove_at(i);
            collections.ptrw()[i].sub_collections_transforms.remove_at(i);
        }
    }
}

MAssetTable::MAssetTable(){

}

MAssetTable::~MAssetTable(){

}

void MAssetTable::init_asset_table(){
    tag_names.resize(M_MAX_TAG);
}

int MAssetTable::tag_add(const String& name){
    ERR_FAIL_COND_V_MSG(tag_names.has(name),-1,"Tag \""+name+"\" already exist");
    for(int i=0; i < M_MAX_TAG; i++){
        if(tag_names[i].is_empty()){
            tag_names.set(i,name);
            return i;
        }
    }
    ERR_FAIL_V_MSG(-1,"No empty Tag");
}

void MAssetTable::tag_set_name(int tag_id,const String& name){
    ERR_FAIL_COND(tag_id > M_MAX_TAG || tag_id < 0);
    tag_names.set(tag_id,name);
}

String MAssetTable::tag_get_name(int tag_id) const {
    ERR_FAIL_COND_V(tag_id > M_MAX_TAG || tag_id < 0,String(""));
    if(tag_id > tag_names.size()){
        return "";
    }
    return tag_names[tag_id];
}

Dictionary MAssetTable::tag_get_names() const{
    Dictionary out;
    for(int i=0; i < M_MAX_TAG; i++){
        if(!tag_names[i].is_empty()){
            out[tag_names[i]] = i;
        }
    }
    return out;
}

int MAssetTable::tag_get_id(const String& tag_name){
    return tag_names.find(tag_name);
}

PackedInt32Array MAssetTable::tag_get_collections(int tag_id) const{
    PackedInt32Array out;
    for(int i=0; i < collections_tags.size(); i++){
        if(collections_tags[i].has_tag(tag_id)){
            out.push_back(i);
        }
    }
    return out;
}

PackedInt32Array MAssetTable::tag_get_collections_in_collections(const PackedInt32Array& search_collections,int tag_id) const{
    PackedInt32Array out;
    for(int i=0; i < search_collections.size(); i++){
        int cid = search_collections[i];
        if(collections_tags[cid].has_tag(tag_id)){
            out.push_back(cid);
        }
    }
    return out;
}

PackedInt32Array MAssetTable::tags_get_collections_any(const PackedInt32Array& tags) const{
    Tag mtag;
    for(int32_t t : tags){
        mtag.add_tag(t);
    }
    PackedInt32Array out;
    for(int i=0; i < collections_tags.size(); i++){
        if(collections_tags[i].has_match(mtag)){
            out.push_back(i);
        }
    }
    return out;
}

PackedInt32Array MAssetTable::tags_get_collections_all(const PackedInt32Array& tags) const{
    Tag mtag;
    for(int32_t t : tags){
        mtag.add_tag(t);
    }
    PackedInt32Array out;
    for(int i=0; i < collections_tags.size(); i++){
        if(collections_tags[i].has_all(mtag)){
            out.push_back(i);
        }
    }
    return out;
}

PackedInt32Array MAssetTable::tags_get_collections_in_collections_any(const PackedInt32Array& search_collections,const PackedInt32Array& tags) const{
    Tag mtag;
    for(int32_t t : tags){
        mtag.add_tag(t);
    }
    PackedInt32Array out;
    for(int i=0; i < search_collections.size(); i++){
        int cid = search_collections[i];
        if(collections_tags[cid].has_match(mtag)){
            out.push_back(cid);
        }
    }
    return out;
}

PackedInt32Array MAssetTable::tags_get_collections_in_collections_all(const PackedInt32Array& search_collections,const PackedInt32Array& tags) const{
    Tag mtag;
    for(int32_t t : tags){
        mtag.add_tag(t);
    }
    PackedInt32Array out;
    for(int i=0; i < search_collections.size(); i++){
        int cid = search_collections[i];
        if(collections_tags[cid].has_all(mtag)){
            out.push_back(cid);
        }
    }
    return out;
}

PackedInt32Array MAssetTable::tag_get_tagless_collections() const{
    Tag clear_tag; //clear tag
    PackedInt32Array out;
    for(int i=0; i < collections_tags.size(); i++){
        if(collections_tags[i] == clear_tag && !free_collections.has(i)){
            out.push_back(i);
        }
    }
    return out;
}

PackedInt32Array MAssetTable::tag_names_begin_with(const String& prefix){
    PackedInt32Array out;
    for(int i=0; i < tag_names.size(); i++){
        if(tag_names[i].begins_with(prefix)){
            out.push_back(i);
        }
    }
    return out;
}

void MAssetTable::update_last_free_mesh_id(){
    Ref<DirAccess> mesh_dir = DirAccess::open(MHlod::get_mesh_root_dir());
    Error err = mesh_dir->list_dir_begin();
    ERR_FAIL_COND_MSG(err!=OK,"Can not open mesh root dir");
    PackedStringArray files = mesh_dir->get_files();
    int biggest_id = -1;
    for(String f : files){
        f = f.get_basename();
        int id = f.to_int();
        if(biggest_id < id){
            biggest_id = id;
        }
    }
    last_free_mesh_id = biggest_id + MAX_MESH_LOD;
    last_free_mesh_id = last_free_mesh_id - (last_free_mesh_id%MAX_MESH_LOD);
}

int MAssetTable::mesh_item_get_max_lod(){
    return MAX_MESH_LOD;
}

int32_t MAssetTable::get_last_free_mesh_id_and_increase(){
    ERR_FAIL_COND_V_MSG(last_free_mesh_id<0,-1,"Please call update_last_free_mesh_id before each import");
    ERR_FAIL_COND_V(last_free_mesh_id%MAX_MESH_LOD!=0,-1);
    int id = last_free_mesh_id;
    last_free_mesh_id += MAX_MESH_LOD;
    return id;
}

int32_t MAssetTable::mesh_item_get_first_lod(int mesh_id){
    ERR_FAIL_COND_V(mesh_id<0,-1);
    return mesh_id - mesh_id%MAX_MESH_LOD;
}

int32_t MAssetTable::mesh_item_get_stop_lod(int mesh_id){
    int32_t _first_id = mesh_item_get_first_lod(mesh_id);
    String stop_ext = ".stop";
    for(int i=0; i < MAX_MESH_LOD; i++){
        int32_t mi = i + _first_id;
        String mpath = MHlod::get_mesh_path(mi);
        String mstop_path = mpath.get_basename() + stop_ext;
        if(FileAccess::file_exists(mstop_path)){
            return i;
        }
    }
    return -1;
}

PackedInt32Array MAssetTable::mesh_item_ids_no_replace(int mesh_id){
    int32_t _first_id = mesh_item_get_first_lod(mesh_id);
    PackedInt32Array out_lods;
    String stop_ext = ".stop";
    for(int i=0; i < MAX_MESH_LOD; i++){
        int32_t mi = i + _first_id;
        String mpath = MHlod::get_mesh_path(mi);
        String mstop_path = mpath.get_basename() + stop_ext;
        if(FileAccess::file_exists(mstop_path)){
            out_lods.push_back(-2);
        }
        if(FileAccess::file_exists(mpath)){
            out_lods.push_back(mi);
        } else {
            out_lods.push_back(-1);
        }
    }
    return out_lods;
}

TypedArray<MMesh> MAssetTable::mesh_item_meshes_no_replace(int mesh_id){
    PackedInt32Array ids = mesh_item_ids_no_replace(mesh_id);
    Array out;
    for(int32_t id : ids){
        if(id<0){
            out.push_back(Ref<MMesh>());
        } else {
            out.push_back(ResourceLoader::get_singleton()->load(MHlod::get_mesh_path(id)));
        }
    }
    return out;
}

PackedInt32Array MAssetTable::mesh_item_ids(int mesh_id){
    int32_t _first_id = mesh_item_get_first_lod(mesh_id);
    int32_t last_valid_mesh = -1;
    PackedInt32Array out_lods;
    String stop_ext = ".stop";
    for(int i=0; i < MAX_MESH_LOD; i++){
        int32_t mi = i + _first_id;
        String mpath = MHlod::get_mesh_path(mi);
        String mstop_path = mpath.get_basename() + stop_ext;
        if(FileAccess::file_exists(mstop_path)){
            break;
        }
        if(FileAccess::file_exists(mpath)){
            out_lods.push_back(mi);
            last_valid_mesh = mi;
        } else {
            out_lods.push_back(last_valid_mesh);
        }
    }
    return out_lods;
}

TypedArray<MMesh> MAssetTable::mesh_item_meshes(int mesh_id){
    Array out;
    PackedInt32Array mesh_ids = mesh_item_ids(mesh_id);
    for(int i=0; i < mesh_ids.size(); i++){
        if(mesh_ids[i]<0){
            if(i == mesh_ids.size()-1){
                return out;
            } else {
                out.push_back(Ref<MMesh>());
                continue;
            }
        }
        Ref<MMesh> _m = ResourceLoader::get_singleton()->load(MHlod::get_mesh_path(mesh_ids[i]));
        out.push_back(_m);
    }
    return out;
}

bool MAssetTable::mesh_item_is_valid(int mesh_id){
    PackedInt32Array mesh_ids = mesh_item_ids(mesh_id);
    for(int i=0; i < mesh_ids.size(); i++){
        if(mesh_ids[i]>=0){
            return true;
        }
    }
    return false;
}

int MAssetTable::collection_create(String name){
    ERR_FAIL_COND_V(name.length()==0,-1);
    if(collections_names.has(name)){
        int lcount = 2;
        while (true)
        {
            String uname = name + itos(lcount);
            if(!collections_names.has(uname)){
                name = uname;
                break;
            }
            ERR_FAIL_COND_V_MSG(lcount > 10000,-1,"Can not find a unique name please try another name");
            lcount++;
        }
    }
    int index = _get_free_collection_index();
    ERR_FAIL_COND_V(index==-1,-1);
    collections_names.set(index,name);
    return index;
}

void MAssetTable::collection_set_glb_id(int collection_id,int32_t glb_id){
    ERR_FAIL_COND(!has_collection(collection_id));
    collections.ptrw()[collection_id].set_glb_id(glb_id);
}

int32_t MAssetTable::collection_get_glb_id(int collection_id) const{
    ERR_FAIL_COND_V(!has_collection(collection_id),-1);
    return collections[collection_id].get_glb_id();
}

void MAssetTable::collection_set_cache_thumbnail(int collection_id,Ref<Texture2D> tex,double creation_time){
    ERR_FAIL_COND(!has_collection(collection_id));
    collections.ptrw()[collection_id].cached_thumbnail = tex;
    collections.ptrw()[collection_id].thumbnail_creation_time = creation_time;
}

double MAssetTable::collection_get_thumbnail_creation_time(int collection_id) const {
    ERR_FAIL_COND_V(!has_collection(collection_id),-1.0);
    return collections[collection_id].thumbnail_creation_time;
}

Ref<Texture2D> MAssetTable::collection_get_cache_thumbnail(int collection_id) const {
    ERR_FAIL_COND_V(!has_collection(collection_id),nullptr);
    return collections[collection_id].cached_thumbnail;
}

void MAssetTable::collection_set_mesh_id(int collection_id,int32_t mesh_id){
    ERR_FAIL_COND(!has_collection(collection_id));
    collections.ptrw()[collection_id].mesh_id = mesh_id;
}

int32_t MAssetTable::collection_get_mesh_id(int collection_id){
    ERR_FAIL_COND_V(!has_collection(collection_id),-1);
    return collections[collection_id].mesh_id;
}

void MAssetTable::collection_clear(int collection_id){
    ERR_FAIL_COND(!has_collection(collection_id));
    collections.ptrw()[collection_id].clear();
}

void MAssetTable::collection_remove(int collection_id){
    ERR_FAIL_COND(!has_collection(collection_id));
    free_collections.push_back(collection_id);
    collections.ptrw()[collection_id].clear();
    collections_names.set(collection_id,"");
    collections_tags.ptrw()[collection_id].clear();
}

PackedInt32Array MAssetTable::collection_get_list() const{
    PackedInt32Array out;
    for(int i=0; i < collections.size(); i++){
        if(free_collections.has(i)){
            continue;
        }
        out.push_back(i);
    }
    return out;
}

void MAssetTable::collection_add_tag(int collection_id,int tag){
    ERR_FAIL_COND(!has_collection(collection_id));
    ERR_FAIL_COND(tag > M_MAX_TAG);
    collections_tags.ptrw()[collection_id].add_tag(tag);
}

bool MAssetTable::collection_add_sub_collection(int collection_id,int sub_collection_id,const Transform3D& transform){
    ERR_FAIL_COND_V(!has_collection(collection_id),false);
    ERR_FAIL_COND_V(!has_collection(sub_collection_id),false);
    // Checking for recursive collection
    PackedInt32Array proc_collections;
    proc_collections.append_array(collections[collection_id].sub_collections);
    while (proc_collections.size()!=0)
    {
        int cur_collection = proc_collections[proc_collections.size() - 1];
        proc_collections.remove_at(proc_collections.size() - 1);
        ERR_FAIL_COND_V_MSG(cur_collection==collection_id,false,"Recursive Collection");
        proc_collections.append_array(collections[cur_collection].sub_collections);
    }
    // So we are cool to continue
    collections.ptrw()[collection_id].sub_collections.push_back(sub_collection_id);
    collections.ptrw()[collection_id].sub_collections_transforms.push_back(transform);
    return true;
}

void MAssetTable::collection_remove_sub_collection(int collection_id,int sub_collection_id){
    ERR_FAIL_COND(!has_collection(collection_id));
    ERR_FAIL_COND(!has_collection(sub_collection_id));
    int index = collections[collection_id].sub_collections.find(sub_collection_id);
    ERR_FAIL_COND_MSG(index<0,"Can't find sub_collection id");
    collections.ptrw()[collection_id].sub_collections.remove_at(index);
    collections.ptrw()[collection_id].sub_collections_transforms.remove_at(index);
}

void MAssetTable::collection_remove_all_sub_collection(int collection_id){
    ERR_FAIL_COND(!has_collection(collection_id));
    collections.ptrw()[collection_id].sub_collections.clear();
    collections.ptrw()[collection_id].sub_collections_transforms.clear();
}

PackedInt32Array MAssetTable::collection_get_sub_collections(int collection_id) const{
    ERR_FAIL_COND_V(!has_collection(collection_id),PackedInt32Array());
    return collections[collection_id].sub_collections;
}

Array MAssetTable::collection_get_sub_collections_transforms(int collection_id) const{
    ERR_FAIL_COND_V(!has_collection(collection_id),Array());
    Array out;
    for(int i=0; i < collections.ptr()[collection_id].sub_collections_transforms.size(); i++){
        out.push_back(collections.ptr()[collection_id].sub_collections_transforms[i]);
    }
    return out;
}

Array MAssetTable::collection_get_sub_collections_transform(int collection_id,int sub_collection_id) const{
    ERR_FAIL_COND_V(!has_collection(collection_id),Array());
    Array result;
    for(int i=0; i < collections[collection_id].sub_collections.size(); i++){
        if(sub_collection_id == collections[collection_id].sub_collections[i]){
            result.push_back(collections[collection_id].sub_collections_transforms[i]);
        }
    }
    return result;
}

void MAssetTable::collection_remove_tag(int collection_id,int tag){
    ERR_FAIL_COND(!has_collection(collection_id));
    ERR_FAIL_COND(tag > M_MAX_TAG);
    collections_tags.ptrw()[collection_id].remove_tag(tag);
}

void MAssetTable::collection_update_name(int collection_id,String name){
    ERR_FAIL_COND(!has_collection(collection_id));
    ERR_FAIL_COND(name.length()==0);
    int fid = collections_names.find(name);
    if(fid != collection_id || collections_names.find(name,collection_id+1)!=-1){ // Exclude itself
        int lcount = 2;
        while (true)
        {
            String uname = name + itos(lcount);
            fid = collections_names.find(uname);
            if( fid==collection_id || !collections_names.find(name,collection_id+1)!=-1){
                name = uname;
                break;
            }
            ERR_FAIL_COND_MSG(lcount > 10000,"Can not find a unique name please try another name");
            lcount++;
        }
    }
    collections_names.set(collection_id,name);
}

String MAssetTable::collection_get_name(int collection_id) const{
    ERR_FAIL_COND_V(!has_collection(collection_id),"");
    return collections_names[collection_id];
}

int MAssetTable::collection_get_id(const String& name) const{
    return collections_names.find(name);
}

PackedInt32Array MAssetTable::collection_get_tags(int collection_id) const{
    PackedInt32Array out;
    ERR_FAIL_COND_V(!has_collection(collection_id),out);
    Tag tag = collections_tags[collection_id];
    for(int i=0; i < M_MAX_TAG; i++){
        if(tag.has_tag(i)){
            out.push_back(i);
        }
    }
    return out;
}

PackedInt32Array MAssetTable::collection_names_begin_with(const String& prefix) const{
    PackedInt32Array out;
    for(int i=0; i < collections_names.size();i++){
        if(collections_names[i].begins_with(prefix)){
            out.push_back(i);
        }
    }
    return out;
}

Vector<Pair<int,Transform3D>> MAssetTable::collection_get_sub_collection_id_transform(int collection_id){
    Vector<Pair<int,Transform3D>> out;
    ERR_FAIL_COND_V(!has_collection(collection_id),out);
    const Collection& c_collection = collections.ptr()[collection_id];
    const int32_t* id_ptr = c_collection.sub_collections.ptr();
    const Transform3D* transform_ptr = c_collection.sub_collections_transforms.ptr();
    int size = c_collection.sub_collections.size();
    for(int i=0; i < size; i++) {
        out.push_back({id_ptr[i],transform_ptr[i]});
    }
    return out;
}

bool MAssetTable::group_exist(const String& name) const{
    return group_names.find(name) >= 0;
}

bool MAssetTable::group_create(const String& name){
    ERR_FAIL_COND_V(name.length()==0,false);
    if(group_names.push_back(name)){
        groups.push_back(Tag());
        return true;
    }
    return false;
}

bool MAssetTable::group_rename(const String& name,const String& new_name){
    ERR_FAIL_COND_V(name.length()==0,false);
    ERR_FAIL_COND_V(new_name.length()==0,false);
    int index = group_names.find(name);
    if(index < 0){
        return false;
    }
    group_names.set(index, new_name);
    return true;
}

void MAssetTable::group_remove(const String& name){
    int index = group_names.find(name);
    if(index >= 0){
        group_names.remove_at(index);
        groups.remove_at(index);
    }
}

PackedStringArray MAssetTable::group_get_list() const{
    return group_names;
}

int MAssetTable::group_count() const{
    return groups.size();
}

void MAssetTable::group_add_tag(const String& name,int tag){
    int index = group_names.find(name);
    ERR_FAIL_COND_MSG(index < 0,"Can not find group with name "+name);
    groups.ptrw()[index].add_tag(tag);
}

void MAssetTable::group_remove_tag(const String& name,int tag){
    int index = group_names.find(name);
    ERR_FAIL_COND_MSG(index < 0,"Can not find group with name "+name);
    groups.ptrw()[index].remove_tag(tag);
}

PackedInt32Array MAssetTable::group_get_tags(const String& gname) const {
    PackedInt32Array out;
    int gindex = group_names.find(gname);
    ERR_FAIL_COND_V_MSG(gindex < 0,out,"Can not find group with name "+gname);
    Tag gtag = groups[gindex];
    for(int i=0; i < M_MAX_TAG; i++){
        if(gtag.has_tag(i)){
            out.push_back(i);
        }
    }
    return out;
}

PackedInt32Array MAssetTable::groups_get_collections_any(const String& name) const{
    PackedInt32Array out;
    int index = group_names.find(name);
    ERR_FAIL_COND_V_MSG(index < 0,out,"Can not find group with name "+name);
    const Tag gtag = groups[index];
    for(int i=0; i < collections_tags.size(); i++){
        if(free_collections.has(i)){
            continue;
        }
        if(gtag.has_match(collections_tags[i])){
            out.push_back(i);
        }
    }
    return out;
}

PackedInt32Array MAssetTable::groups_get_collections_all(const String& name) const{
    PackedInt32Array out;
    int index = group_names.find(name);
    ERR_FAIL_COND_V_MSG(index < 0,out,"Can not find group with name "+name);
    const Tag gtag = groups[index];
    for(int i=0; i < collections_tags.size(); i++){
        if(free_collections.has(i)){
            continue;
        }
        if(collections_tags[i].has_all(gtag)){
            out.push_back(i);
        }
    }
    return out;
}

Dictionary MAssetTable::group_get_collections_with_tags(const String& gname) const{
    Dictionary out;
    int index = group_names.find(gname);
    ERR_FAIL_COND_V_MSG(index < 0,out,"Can not find group with name "+gname);
    Tag gtag = groups[index];
    for(int t=0; t < M_MAX_TAG; t++){
        if(gtag.has_tag(t)){
            for(int j=0; j < collections_tags.size(); j++){
                if(free_collections.has(j)){
                    continue;
                }
                if(collections_tags[j].has_tag(t)){
                    if(out.has(t)){
                        Array l = out[t];
                        l.push_back(j);
                        out[t] = l;
                    } else {
                        Array l;
                        l.push_back(j);
                        out[t] = l;
                    }
                }
            }
        }
    }
    return out;
}

void MAssetTable::clear_table(){
    collections.clear();
    free_collections.clear();
    collections_names.clear();
    collections_tags.clear();
    tag_names.clear();
    groups.clear();
    group_names.clear();
}

void MAssetTable::set_data(const Dictionary& data){
    ERR_FAIL_COND(!data.has("collections"));
    ERR_FAIL_COND(!data.has("collections_tags"));
    ERR_FAIL_COND(!data.has("groups"));
    ERR_FAIL_COND(!data.has("collections_names"));
    ERR_FAIL_COND(!data.has("tag_names"));
    ERR_FAIL_COND(!data.has("group_names"));
    clear_table();
    free_collections = MTool::packed_byte_array_to_vector<int32_t>(data["free_collections"]);
    {
        Array s_collections = data["collections"];
        for(int i=0; i < s_collections.size();i++){
            Collection c;
            c.set_save_data(s_collections[i]);
            collections.push_back(c);
        }
    }

    collections_tags = MTool::packed_byte_array_to_vector<Tag>(data["collections_tags"]);
    groups = MTool::packed_byte_array_to_vector<Tag>(data["groups"]);

    collections_names = data["collections_names"];
    tag_names = data["tag_names"];
    group_names = data["group_names"];
}

Dictionary MAssetTable::get_data(){
    Dictionary data;
    {
        Array s_collections;
        for(int i=0; i < collections.size(); i++){
            PackedByteArray __d = collections[i].get_save_data();
            s_collections.push_back(__d);
        }
        data["collections"] = s_collections;
    }
    data["free_collections"] = MTool::vector_to_packed_byte_array<int32_t>(free_collections);

    data["collections_tags"] = MTool::vector_to_packed_byte_array<Tag>(collections_tags);
    data["groups"] = MTool::vector_to_packed_byte_array<Tag>(groups);

    data["collections_names"] = collections_names;
    data["tag_names"] = tag_names;
    data["group_names"] = group_names;
    return data;
}

void MAssetTable::_notification(int32_t what){
    switch (what)
    {
    case NOTIFICATION_POSTINITIALIZE:
        init_asset_table();
        break;
    
    default:
        break;
    }
}

void MAssetTable::test(Dictionary d){
    uint8_t a = 4;
    a = ~a;
    UtilityFunctions::print("A ",a);
}

void MAssetTable::set_import_info(const Dictionary& input){
    import_info = input;
}

Dictionary MAssetTable::get_import_info(){
    return import_info;
}

void MAssetTable::reset(bool hard){

}


void MAssetTable::debug_test(){
    int combo_id = collection_get_id("combo");
    if(combo_id==-1){
        return;
    }
    UtilityFunctions::print("Combo id is ",combo_id);
    PackedByteArray data = collections[combo_id].get_save_data();
    UtilityFunctions::print("Combo data size ",data.size());
    Collection dummy_collection;
    dummy_collection.set_save_data(data);
    UtilityFunctions::print("dummy_collection size ",dummy_collection.sub_collections.size());
    return;
    UtilityFunctions::print("dummy_collectionA ",dummy_collection.sub_collections[0]);
    UtilityFunctions::print("dummy_collectionB ",dummy_collection.sub_collections[1]);
    UtilityFunctions::print("dummy_collectionA ",dummy_collection.sub_collections_transforms[0]);
    UtilityFunctions::print("dummy_collectionB ",dummy_collection.sub_collections_transforms[1]);
}