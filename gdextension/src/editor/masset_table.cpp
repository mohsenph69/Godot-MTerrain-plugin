#include "masset_table.h"

#include "mtool.h"

#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/resource_saver.hpp>
#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/classes/scene_state.hpp>
#include <godot_cpp/classes/packed_scene.hpp>
#include <godot_cpp/classes/time.hpp>
int32_t MAssetTable::last_free_item_id = -1;
const char* MAssetTable::import_info_path="res://massets_editor/import_info.json";
const char* MAssetTable::asset_table_path = "res://massets_editor/asset_table.res";
const char* MAssetTable::asset_editor_root_dir = "res://massets_editor/";
const char* MAssetTable::editor_baker_scenes_dir = "res://massets_editor/baker_scenes/";
const char* MAssetTable::asset_thumbnails_dir = "res://massets_editor/thumbnails_meshes/";
const char* MAssetTable::thumbnails_dir = "res://massets_editor/thumbnails/";
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
    ClassDB::bind_static_method("MAssetTable",D_METHOD("mesh_item_get_first_lod","item_id"), &MAssetTable::mesh_item_get_first_lod);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("mesh_item_get_first_valid_id","item_id"), &MAssetTable::mesh_item_get_first_valid_id);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("mesh_item_get_stop_lod","item_id"), &MAssetTable::mesh_item_get_stop_lod);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("mesh_item_ids_no_replace","item_id"), &MAssetTable::mesh_item_ids_no_replace);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("mesh_item_meshes_no_replace","item_id"), &MAssetTable::mesh_item_meshes_no_replace);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("mesh_item_ids","item_id"), &MAssetTable::mesh_item_ids);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("mesh_item_meshes","item_id"), &MAssetTable::mesh_item_meshes);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("mesh_item_is_valid","item_id"), &MAssetTable::mesh_item_is_valid);

    ClassDB::bind_static_method("MAssetTable",D_METHOD("get_last_free_mesh_join_id"), &MAssetTable::get_last_free_mesh_join_id);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("mesh_join_get_first_lod","item_id"), &MAssetTable::mesh_join_get_first_lod);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("mesh_join_get_stop_lod","item_id"), &MAssetTable::mesh_join_get_stop_lod);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("mesh_join_ids_no_replace","item_id"), &MAssetTable::mesh_join_ids_no_replace);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("mesh_join_meshes_no_replace","item_id"), &MAssetTable::mesh_join_meshes_no_replace);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("mesh_join_ids","item_id"), &MAssetTable::mesh_join_ids);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("mesh_join_meshes","item_id"), &MAssetTable::mesh_join_meshes);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("mesh_join_is_valid","item_id"), &MAssetTable::mesh_join_is_valid);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("mesh_join_start_lod","item_id"), &MAssetTable::mesh_join_start_lod);

    ClassDB::bind_static_method("MAssetTable",D_METHOD("get_last_free_decal_id"), &MAssetTable::get_last_free_decal_id);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("get_last_free_packed_scene_id"), &MAssetTable::get_last_free_packed_scene_id);
    ClassDB::bind_static_method("MAssetTable",D_METHOD("get_last_free_hlod_id"), &MAssetTable::get_last_free_hlod_id);

    ClassDB::bind_method(D_METHOD("has_collection","collection_id"), &MAssetTable::has_collection);
    ClassDB::bind_method(D_METHOD("tag_add","name"), &MAssetTable::tag_add);
    ClassDB::bind_method(D_METHOD("tag_set_name","tag_id","name"), &MAssetTable::tag_set_name);
    ClassDB::bind_method(D_METHOD("tag_get_name","tag_id"), &MAssetTable::tag_get_name);
    ClassDB::bind_method(D_METHOD("tag_get_names"), &MAssetTable::tag_get_names);
    ClassDB::bind_method(D_METHOD("tag_get_id","tag_name"), &MAssetTable::tag_get_id);
    ClassDB::bind_method(D_METHOD("tag_get_collections","tag_id"), &MAssetTable::tag_get_collections);
    ClassDB::bind_method(D_METHOD("tags_get_collections_any","search_collections","tags","exclude_tags"), &MAssetTable::tags_get_collections_any);
    ClassDB::bind_method(D_METHOD("tags_get_collections_all","search_collections","tags","exclude_tags"), &MAssetTable::tags_get_collections_all);
    ClassDB::bind_method(D_METHOD("tag_get_tagless_collections"), &MAssetTable::tag_get_tagless_collections);
    ClassDB::bind_method(D_METHOD("collection_create","name","item_id","type","glb_id"), &MAssetTable::collection_create);
    ClassDB::bind_method(D_METHOD("collection_update_item_id", "collection_id", "new_item_id"), &MAssetTable::collection_update_item_id);
    ClassDB::bind_method(D_METHOD("collection_get_modify_time","collection_id"), &MAssetTable::collection_get_modify_time);
    ClassDB::bind_method(D_METHOD("collection_update_modify_time","collection_id"), &MAssetTable::collection_update_modify_time);
    ClassDB::bind_method(D_METHOD("collection_set_physics_setting","collection_id","physics_name"), &MAssetTable::collection_set_physics_setting);
    ClassDB::bind_method(D_METHOD("collection_get_physics_setting","collection_id"), &MAssetTable::collection_get_physics_setting);
    ClassDB::bind_method(D_METHOD("collection_set_colcutoff","collection_id","value"), &MAssetTable::collection_set_colcutoff);
    ClassDB::bind_method(D_METHOD("collection_get_colcutoff","collection_id"), &MAssetTable::collection_get_colcutoff);
    ClassDB::bind_method(D_METHOD("collection_get_type","collection_id"), &MAssetTable::collection_get_type);
    ClassDB::bind_method(D_METHOD("collection_get_glb_id","collection_id"), &MAssetTable::collection_get_glb_id);
    ClassDB::bind_method(D_METHOD("collection_get_item_id","collection_id"), &MAssetTable::collection_get_item_id);
    ClassDB::bind_method(D_METHOD("collection_clear_sub_and_col","collection_id"), &MAssetTable::collection_clear_sub_and_col);
    ClassDB::bind_method(D_METHOD("collection_remove","collection_id"), &MAssetTable::collection_remove);
    ClassDB::bind_method(D_METHOD("collection_get_list"), &MAssetTable::collection_get_list);
    ClassDB::bind_method(D_METHOD("collections_get_by_type","item_types"), &MAssetTable::collections_get_by_type);
    ClassDB::bind_method(D_METHOD("collection_add_tag","collection_id","tag"), &MAssetTable::collection_add_tag);
    ClassDB::bind_method(D_METHOD("collection_add_sub_collection","collection_id","sub_collection_id"), &MAssetTable::collection_add_sub_collection);
    ClassDB::bind_method(D_METHOD("collection_add_collision","collection_id","col_type","col_transform","base_transform"), &MAssetTable::collection_add_collision);
    ClassDB::bind_method(D_METHOD("collection_get_sub_collections","collection_id"), &MAssetTable::collection_get_sub_collections);
    ClassDB::bind_method(D_METHOD("collection_get_collision_count","collection_id"), &MAssetTable::collection_get_collision_count);
    ClassDB::bind_method(D_METHOD("collection_remove_tag","collection_id","tag"), &MAssetTable::collection_remove_tag);
    ClassDB::bind_method(D_METHOD("collection_set_name","collection_id","expected_type","new_name"), &MAssetTable::collection_set_name);
    ClassDB::bind_method(D_METHOD("collection_get_name","collection_id"), &MAssetTable::collection_get_name);
    ClassDB::bind_method(D_METHOD("collection_get_id","collection_name"), &MAssetTable::collection_get_id);
    ClassDB::bind_method(D_METHOD("collection_get_tags","collection_id"), &MAssetTable::collection_get_tags);

    ClassDB::bind_method(D_METHOD("group_exist","group_name"), &MAssetTable::group_exist);
    ClassDB::bind_method(D_METHOD("group_create","group_name"), &MAssetTable::group_create);
    ClassDB::bind_method(D_METHOD("group_rename","group_name","new_name"), &MAssetTable::group_rename);
    ClassDB::bind_method(D_METHOD("group_remove","group_remove"), &MAssetTable::group_remove);
    ClassDB::bind_method(D_METHOD("group_get_list"), &MAssetTable::group_get_list);
    ClassDB::bind_method(D_METHOD("group_count"), &MAssetTable::group_count);
    ClassDB::bind_method(D_METHOD("group_add_tag","group_name","tag"), &MAssetTable::group_add_tag);
    ClassDB::bind_method(D_METHOD("group_remove_tag","group_name","tag"), &MAssetTable::group_remove_tag);
    ClassDB::bind_method(D_METHOD("group_get_tags","group_name"), &MAssetTable::group_get_tags);
    ClassDB::bind_method(D_METHOD("collection_find_with_item_type_item_id","type","item_id"), &MAssetTable::collection_find_with_item_type_item_id);
    ClassDB::bind_method(D_METHOD("groups_get_collections_any","group_name"), &MAssetTable::groups_get_collections_any);
    ClassDB::bind_method(D_METHOD("groups_get_collections_all","group_name"), &MAssetTable::groups_get_collections_all);
    ClassDB::bind_method(D_METHOD("group_get_collections_with_tags","group_name"), &MAssetTable::group_get_collections_with_tags);

    ClassDB::bind_method(D_METHOD("clear_table"), &MAssetTable::clear_table);

    BIND_ENUM_CONSTANT(NONE);
    BIND_ENUM_CONSTANT(MESH);
    BIND_ENUM_CONSTANT(COLLISION);
    BIND_ENUM_CONSTANT(PACKEDSCENE);
    BIND_ENUM_CONSTANT(DECAL);
    BIND_ENUM_CONSTANT(HLOD);

    BIND_ENUM_CONSTANT(UNDEF);
    BIND_ENUM_CONSTANT(SHPERE);
    BIND_ENUM_CONSTANT(CYLINDER);
    BIND_ENUM_CONSTANT(CAPSULE);
    BIND_ENUM_CONSTANT(BOX);

    ClassDB::bind_method(D_METHOD("get_data"), &MAssetTable::get_data);
    ClassDB::bind_method(D_METHOD("set_data","data"), &MAssetTable::set_data);
    ADD_PROPERTY(PropertyInfo(Variant::DICTIONARY,"data"),"set_data","get_data");

    ClassDB::bind_method(D_METHOD("clear_import_info_cache"), &MAssetTable::clear_import_info_cache);
    ClassDB::bind_method(D_METHOD("save_import_info"), &MAssetTable::save_import_info);
    ClassDB::bind_method(D_METHOD("get_import_info"), &MAssetTable::get_import_info);
    ClassDB::bind_method(D_METHOD("set_import_info","input"), &MAssetTable::set_import_info);
    ADD_PROPERTY(PropertyInfo(Variant::DICTIONARY,"import_info",PROPERTY_HINT_NONE,"",PROPERTY_USAGE_NONE),"set_import_info","get_import_info");

    ClassDB::bind_method(D_METHOD("auto_asset_update_from_dir","type"), &MAssetTable::auto_asset_update_from_dir);

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
    if(!DirAccess::dir_exists_absolute(String(MHlod::get_asset_root_dir()))){
        Error err = DirAccess::make_dir_recursive_absolute(String(MHlod::get_asset_root_dir()));
        if(err!=OK){WARN_PRINT("Can not create folder");}
    }
    if(!DirAccess::dir_exists_absolute(String(MAssetTable::asset_editor_root_dir))){
        Error err = DirAccess::make_dir_recursive_absolute(String(MAssetTable::asset_editor_root_dir));
        if(err!=OK){WARN_PRINT("Can not create folder");}
    }
    if(!DirAccess::dir_exists_absolute(String(MAssetTable::editor_baker_scenes_dir))){
        Error err = DirAccess::make_dir_recursive_absolute(String(MAssetTable::editor_baker_scenes_dir));
        if(err!=OK){WARN_PRINT("Can not create folder");}
    }
    if(!DirAccess::dir_exists_absolute(String(MAssetTable::asset_thumbnails_dir))){
        Error err = DirAccess::make_dir_recursive_absolute(String(MAssetTable::asset_thumbnails_dir));
        if(err!=OK){WARN_PRINT("Can not create folder");}
    }
    if(!DirAccess::dir_exists_absolute(String(MAssetTable::thumbnails_dir))){
        Error err = DirAccess::make_dir_recursive_absolute(String(MAssetTable::thumbnails_dir));
        if(err!=OK){WARN_PRINT("Can not create folder");}
    }
    if(!DirAccess::dir_exists_absolute(String(MHlod::get_mesh_root_dir()))){
        Error err = DirAccess::make_dir_recursive_absolute(String(MHlod::get_mesh_root_dir()));
        if(err!=OK){ WARN_PRINT("Can not create folder");}
    }
    if(!DirAccess::dir_exists_absolute(String(MHlod::get_hlod_root_dir()))){
        Error err = DirAccess::make_dir_recursive_absolute(String(MHlod::get_hlod_root_dir()));
        if(err!=OK){ WARN_PRINT("Can not create folder");}
    }
    if(!DirAccess::dir_exists_absolute(String(MHlod::get_packed_scene_root_dir()))){
        Error err = DirAccess::make_dir_recursive_absolute(String(MHlod::get_packed_scene_root_dir()));
        if(err!=OK){ WARN_PRINT("Can not create folder");}
    }
    if(!DirAccess::dir_exists_absolute(String(MHlod::get_decal_root_dir()))){
        Error err = DirAccess::make_dir_recursive_absolute(String(MHlod::get_decal_root_dir()));
        if(err!=OK){ WARN_PRINT("Can not create folder");}
    }
    if(!DirAccess::dir_exists_absolute(String(MHlod::get_collision_root_dir()))){
        Error err = DirAccess::make_dir_recursive_absolute(String(MHlod::get_collision_root_dir()));
        if(err!=OK){ WARN_PRINT("Can not create folder");}
    }
    if(!DirAccess::dir_exists_absolute(String(MHlod::get_physics_settings_dir()))){
        Error err = DirAccess::make_dir_recursive_absolute(String(MHlod::get_physics_settings_dir()));
        if(err!=OK){ WARN_PRINT("Can not create folder");}
    }
}

void MAssetTable::save(){
    //ERR_FAIL_COND(asset_table_singelton.is_null());
    make_assets_dir();
    Error err = ResourceSaver::get_singleton()->save(asset_table_singelton,asset_table_path);
    asset_table_singelton->collection_clear_unused_physics_settings();
    asset_table_singelton->save_import_info();
    asset_table_singelton->clear_import_info_cache();
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

String MAssetTable::get_thumbnails_dir(){
    return thumbnails_dir;
}

String MAssetTable::get_asset_thumbnails_path(int collection_id){
    ERR_FAIL_COND_V(asset_table_singelton==nullptr,"");
    ItemType type = asset_table_singelton->collection_get_type(collection_id);
    String tprefix;
    switch (type)
    {
    case MESH:
        /* No Prefix */
        break;
    case DECAL:
        tprefix = "d";
        break;
    case HLOD:
        tprefix = "h";
        break;
    default:
        return "";
    }
    const char* tdir = type==MESH ? asset_thumbnails_dir : thumbnails_dir;
    return String(tdir) + tprefix +itos(collection_id) + String(".dat");
}

String MAssetTable::get_material_thumbnails_path(int material_id){
    return String(thumbnails_dir) + "material_" + itos(material_id) + String(".dat");
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

PackedInt32Array MAssetTable::tags_get_collections_any(const PackedInt32Array& search_collections,const PackedInt32Array& tags,const PackedInt32Array& exclude_tags) const{
    Tag mtag;
    Tag etag;
    for(int32_t t : tags){
        mtag.add_tag(t);
    }
    for(int32_t t : exclude_tags){
        etag.add_tag(t);
    }
    PackedInt32Array out;
    for(int i=0; i < search_collections.size(); i++){
        int cid = search_collections[i];
        if(collections_tags[cid].has_match(mtag)){
            if(collections_tags.size()==0 || !collections_tags[cid].has_match(etag)){
                out.push_back(cid);   
            }
        }
    }
    return out;
}

PackedInt32Array MAssetTable::tags_get_collections_all(const PackedInt32Array& search_collections,const PackedInt32Array& tags,const PackedInt32Array& exclude_tags) const{
    Tag mtag;
    Tag etag;
    for(int32_t t : tags){
        mtag.add_tag(t);
    }
    for(int32_t t : exclude_tags){
        etag.add_tag(t);
    }
    PackedInt32Array out;
    for(int i=0; i < search_collections.size(); i++){
        int cid = search_collections[i];
        if(collections_tags[cid].has_all(mtag)){
            if(collections_tags.size()==0 || !collections_tags[cid].has_match(etag)){
                out.push_back(cid);
            }
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
    last_free_item_id = biggest_id + MAX_MESH_LOD;
    last_free_item_id = last_free_item_id - (last_free_item_id%MAX_MESH_LOD);
}

int MAssetTable::mesh_item_get_max_lod(){
    return MAX_MESH_LOD;
}

int32_t MAssetTable::get_last_free_mesh_id_and_increase(){
    ERR_FAIL_COND_V_MSG(last_free_item_id<0,-1,"Please call update_last_free_item_id before each import");
    ERR_FAIL_COND_V(last_free_item_id%MAX_MESH_LOD!=0,-1);
    int id = last_free_item_id;
    last_free_item_id += MAX_MESH_LOD;
    return id;
}

int32_t MAssetTable::mesh_item_get_first_lod(int item_id){
    ERR_FAIL_COND_V(item_id<0,-1);
    return item_id - item_id%MAX_MESH_LOD;
}

int32_t MAssetTable::mesh_item_get_first_valid_id(int item_id){
    item_id = mesh_item_get_first_lod(item_id);
    for(int i=0; i < MAX_MESH_LOD; i++){
        String mpath = MHlod::get_mesh_path(i + item_id);
        if(FileAccess::file_exists(mpath)){
            return i + item_id;
        }
    }
    return -1;
}

int32_t MAssetTable::mesh_item_get_stop_lod(int item_id){
    int32_t _first_id = mesh_item_get_first_lod(item_id);
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

PackedInt32Array MAssetTable::mesh_item_ids_no_replace(int item_id){
    int32_t _first_id = mesh_item_get_first_lod(item_id);
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

TypedArray<MMesh> MAssetTable::mesh_item_meshes_no_replace(int item_id){
    PackedInt32Array ids = mesh_item_ids_no_replace(item_id);
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

PackedInt32Array MAssetTable::mesh_item_ids(int item_id){
    int32_t _first_id = mesh_item_get_first_lod(item_id);
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

TypedArray<MMesh> MAssetTable::mesh_item_meshes(int item_id){
    Array out;
    PackedInt32Array item_ids = mesh_item_ids(item_id);
    for(int i=0; i < item_ids.size(); i++){
        if(item_ids[i]<0){
            if(i == item_ids.size()-1){
                return out;
            } else {
                out.push_back(Ref<MMesh>());
                continue;
            }
        }
        Ref<MMesh> _m = ResourceLoader::get_singleton()->load(MHlod::get_mesh_path(item_ids[i]));
        out.push_back(_m);
    }
    return out;
}

bool MAssetTable::mesh_item_is_valid(int item_id){
    PackedInt32Array item_ids = mesh_item_ids(item_id);
    for(int i=0; i < item_ids.size(); i++){
        if(item_ids[i]>=0){
            return true;
        }
    }
    return false;
}

int32_t MAssetTable::mesh_join_get_first_lod(int item_id){
    return item_id - (item_id % MAX_MESH_LOD);
}

int32_t MAssetTable::get_last_free_mesh_join_id(){
    int32_t smallest_id = -10;
    Ref<DirAccess> dir = DirAccess::open(MHlod::get_mesh_root_dir());
    PackedStringArray files = dir->get_files();
    for(const String& file : files){
        int32_t id = file.get_basename().to_int();
        if(smallest_id > id){
            smallest_id = id;
        }
    }
    smallest_id -= MAX_MESH_LOD;
    return mesh_join_get_first_lod(smallest_id);
}

int32_t MAssetTable::mesh_join_get_stop_lod(int item_id){
    ERR_FAIL_COND_V(item_id > 0,-1);
    for(int i=0; i < MAX_MESH_LOD; i++){
        int mesh_lod_id = item_id - i;
        String stop_path = MHlod::get_mesh_path(mesh_lod_id).get_basename() + String(".stop");
        if(FileAccess::file_exists(stop_path)){
            return i;
        }
    }
    return -1;
}

PackedInt32Array MAssetTable::mesh_join_ids_no_replace(int item_id){
    PackedInt32Array out;
    ERR_FAIL_COND_V(item_id > 0,out);
    for(int i=0; i < MAX_MESH_LOD; i++){
        int mesh_lod_id = item_id - i;
        String path = MHlod::get_mesh_path(mesh_lod_id);
        if(FileAccess::file_exists(path)){
            out.push_back(mesh_lod_id);
        } else {
            out.push_back(-1);
        }
    }
    return out;
}

TypedArray<MMesh> MAssetTable::mesh_join_meshes_no_replace(int item_id){
    item_id = mesh_join_get_first_lod(item_id);
    PackedInt32Array ids = mesh_join_ids_no_replace(item_id);
    TypedArray<MMesh> out;
    for(int32_t id : ids){
        if(id!=-1){
            out.push_back(ResourceLoader::get_singleton()->load(MHlod::get_mesh_path(id)));
        } else{
            out.push_back(Ref<MMesh>());
        }
    }
    return out;
}

PackedInt32Array MAssetTable::mesh_join_ids(int item_id){
    if(item_id==-1){
        return PackedInt32Array();
    }
    item_id = mesh_join_get_first_lod(item_id);
    PackedInt32Array out;
    int last_valid_id = -1;
    for(int i=0; i < MAX_MESH_LOD; i++){
        int lod_id = item_id - i;
        String path = MHlod::get_mesh_path(lod_id);
        String stop_path = path.get_basename() + String(".stop");
        if(FileAccess::file_exists(stop_path)){
            break;
        }
        if(FileAccess::file_exists(path)){
            last_valid_id = lod_id;
        }
        out.push_back(last_valid_id);
    }
    return out;
}

TypedArray<MMesh> MAssetTable::mesh_join_meshes(int item_id){
    PackedInt32Array ids = mesh_join_ids(item_id);
    TypedArray<MMesh> out;
    for(int32_t id : ids){
        if(id!=-1){
            String path = MHlod::get_mesh_path(id);
            out.push_back(ResourceLoader::get_singleton()->load(path));
        } else {
            out.push_back(Ref<MMesh>());
        }
    }
    return out;
}

bool MAssetTable::mesh_join_is_valid(int item_id){
    PackedInt32Array ids = mesh_join_ids(item_id);
    for(int32_t id : ids){
        if(id!=-1){
            return true;
        }
    }
    return false;
}

int32_t MAssetTable::mesh_join_start_lod(int item_id){
    PackedInt32Array ids = mesh_join_ids(item_id);
    for(int i=0; i < ids.size(); i++){
        if(ids[i] != -1){
            return i;
        }
    }
    return -1;
}

int32_t MAssetTable::get_last_id_in_dir(const String dir_path){
    Ref<DirAccess> dir = DirAccess::open(dir_path);
    PackedStringArray files = dir->get_files();
    int32_t biggest_id = 0;
    for (const String& file_name : files){
        int32_t val = file_name.get_basename().to_int();
        if(val > biggest_id){
            biggest_id = val;
        }
    }
    biggest_id++;
    return biggest_id;
}

int32_t MAssetTable::get_last_free_decal_id(){
    return get_last_id_in_dir(MHlod::get_decal_root_dir());
}

int32_t MAssetTable::get_last_free_packed_scene_id(){
    return get_last_id_in_dir(MHlod::get_packed_scene_root_dir());
}

int32_t MAssetTable::get_last_free_hlod_id(){
    return get_last_id_in_dir(MHlod::get_hlod_root_dir());
}


MAssetTable::CollectionIdentifier MAssetTable::collection_get_identifier(int collection_id) const{
    if(!has_collection(collection_id)){
        return CollectionIdentifier();
    }
    return CollectionIdentifier(collections[collection_id].glb_id,collections_names[collection_id]);
}

int32_t MAssetTable::collection_get_id_by_identifier(const CollectionIdentifier& identifier) const{
    if(identifier.is_null()){
        return -1;
    }
    for(int id=0; id < collections.size(); id++){
        CollectionIdentifier ii = CollectionIdentifier(collections[id].glb_id,collections_names[id]);
        if(ii==identifier){
            return id;
        }
    }
    return -1;
}

MAssetTable::CollisionData MAssetTable::collection_get_collision_data(int collection_id) const{
    if(collisions_data.has(collection_id)){
        return collisions_data[collection_id];
    }
    return CollisionData();
}

int MAssetTable::physics_id_get_add(const String& physics_name){
    int index = physics_names.find(physics_name);
    if(index!=-1){
        return index;
    }
    // check if we have empty one
    for(int i=0; i < physics_names.size(); i++){
        if(physics_names.is_empty()){
            physics_names.set(i,physics_name);
            return i;
        }
    }
    //Add new
    ERR_FAIL_COND_V_MSG(physics_names.size()>=std::numeric_limits<int16_t>::max(),-1,"physics_names can not be bigger than "+itos(std::numeric_limits<int16_t>::max()));
    physics_names.push_back(physics_name);
    return physics_names.size() - 1;
}

int MAssetTable::collection_create(const String& _name,int32_t item_id,MAssetTable::ItemType type,int32_t glb_id){
    ERR_FAIL_COND_V(_name.length()==0,-1);
    int index = -1;
    if(type != ItemType::MESH){ // for mesh bellow should not happen, it has a seperated system of importing
        index = collection_find_with_item_type_item_id(type,item_id);
    }
    if(index==-1){
        index = _get_free_collection_index();
    }
    ERR_FAIL_COND_V(index==-1,-1);
    collections_names.set(index,_name);
    collections.ptrw()[index].type = type;
    collections.ptrw()[index].glb_id = glb_id;
    collections.ptrw()[index].item_id = item_id;
    collections.ptrw()[index].modify_time = Time::get_singleton()->get_unix_time_from_system();
    return index;
}

void MAssetTable::collection_update_item_id(int collection_id, int32_t new_item_id){
    ERR_FAIL_COND(!has_collection(collection_id));
    collections.ptrw()[collection_id].item_id = new_item_id;    
}

void MAssetTable::collection_update_modify_time(int collection_id){
    ERR_FAIL_COND(!has_collection(collection_id));
    collections.ptrw()[collection_id].modify_time = Time::get_singleton()->get_unix_time_from_system();
}

int64_t MAssetTable::collection_get_modify_time(int collection_id) const{
    ERR_FAIL_COND_V(!has_collection(collection_id),0);
    return collections[collection_id].modify_time;
}

void MAssetTable::collection_set_physics_setting(int collection_id,const String& physics_name){
    ERR_FAIL_COND(physics_name.length()==0);
    ERR_FAIL_COND(!has_collection(collection_id));
    collections.ptrw()[collection_id].physics_name = physics_id_get_add(physics_name);
}

String MAssetTable::collection_get_physics_setting(int collection_id) const{
    ERR_FAIL_COND_V(!has_collection(collection_id),"");
    int pid = collections[collection_id].physics_name;
    if(pid < 0){
        return "";
    }
    ERR_FAIL_INDEX_V(pid,physics_names.size(),"");
    return physics_names[pid];
}

void MAssetTable::collection_set_colcutoff(int collection_id,int value){
    ERR_FAIL_COND(!has_collection(collection_id));
    ERR_FAIL_COND(value>std::numeric_limits<int8_t>::max()-1);
    collections.ptrw()[collection_id].colcutoff = value;
}

int8_t MAssetTable::collection_get_colcutoff(int collection_id) const{
    ERR_FAIL_COND_V(!has_collection(collection_id),-1);
    return collections[collection_id].colcutoff;
}

void MAssetTable::collection_clear_unused_physics_settings(){
    HashSet<int16_t> used_physics_id;
    for(int i=0; i < collections.size(); i++){
        if(collections[i].physics_name!=-1){
            used_physics_id.insert(collections[i].physics_name);
        }
    }
    for(int i=0; i < physics_names.size(); i++){
        if(!used_physics_id.has(i)){
            physics_names.set(i,"");
        }
    }
}

MAssetTable::ItemType MAssetTable::collection_get_type(int collection_id) const{
    ERR_FAIL_COND_V(!has_collection(collection_id),NONE);
    return collections[collection_id].type;
}

int32_t MAssetTable::collection_get_glb_id(int collection_id) const{
    ERR_FAIL_COND_V(!has_collection(collection_id),-1);
    return collections[collection_id].glb_id;
}

int32_t MAssetTable::collection_find_with_item_type_item_id(ItemType type, int32_t item_id) const {
    for(int i=0; i < collections.size(); i++){
        if(collections[i].type == type && collections[i].item_id == item_id && has_collection(i)){
            return i;
        }
    }
    return -1;
}

int32_t MAssetTable::collection_find_with_glb_id_collection_name(int32_t glb_id,const String collection_name) const{
    for(int i=0; i < collections.size(); i++){
        if(collections[i].glb_id==glb_id&&collections_names[i]==collection_name){
            return i;
        }
    }
    return -1;
}

int32_t MAssetTable::collection_get_item_id(int collection_id){
    ERR_FAIL_COND_V(!has_collection(collection_id),-1);
    return collections[collection_id].item_id;
}

void MAssetTable::collection_clear_sub_and_col(int id){
    ERR_FAIL_COND(!has_collection(id));
    sub_collections.erase(id);
    collisions_data.erase(id);
}

void MAssetTable::collection_remove(int id){
    ERR_FAIL_COND(!has_collection(id));
    collection_clear_sub_and_col(id);
    collections.ptrw()[id].glb_id = -1;
    collections.ptrw()[id].item_id = -1;
    collections.ptrw()[id].type = ItemType::NONE;
    collections_names.set(id,"");
    collections_tags.ptrw()[id].clear();
    free_collections.push_back(id);
    {
        using PaireType = decltype(sub_collections)::Pair;
        PaireType* pair_arr = sub_collections.get_array();
        for(int i=0; i < sub_collections.size(); i++){
            PackedInt32Array& _sub_ids = pair_arr[i].value.sub_collections;
            Vector<Transform3D>& _sub_t = pair_arr[i].value.sub_collections_transforms;
            int find_index = _sub_ids.find(id);
            while (find_index !=-1){
                _sub_ids.remove_at(find_index);
                _sub_t.remove_at(find_index);
                find_index = _sub_ids.find(id);
            }
        }
    }
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

PackedInt32Array MAssetTable::collections_get_by_type(int item_types) const{
    PackedInt32Array out;
    for(int i=0; i < collections.size(); i++){
        if((collections[i].type & item_types) != 0){
            out.push_back(i);
        }
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
    if(sub_collections.has(collection_id)){
        proc_collections.append_array(sub_collections[collection_id].sub_collections);
    }
    while (proc_collections.size()!=0)
    {
        int cur_collection = proc_collections[proc_collections.size() - 1];
        proc_collections.remove_at(proc_collections.size() - 1);
        ERR_FAIL_COND_V_MSG(cur_collection==collection_id,false,"Recursive Collection");
        proc_collections.append_array(sub_collections[cur_collection].sub_collections);
    }
    // So we are cool to continue
    if(!sub_collections.has(collection_id)){
        sub_collections.insert(collection_id,SubCollectionData());
    }
    int index = sub_collections.find(collection_id);
    sub_collections.get_array()[index].value.sub_collections.push_back(sub_collection_id);
    sub_collections.get_array()[index].value.sub_collections_transforms.push_back(transform);
    return true;
}

void MAssetTable::collection_add_collision(int collection_id,CollisionType col_type,Transform3D col_transform,const Transform3D& base_transform){
    ERR_FAIL_COND(!has_collection(collection_id));
    // Getting sign with correct sing
    // Godot Basis class does not have this so we have to write it by outself
    float det = col_transform.basis.determinant();
    ERR_FAIL_COND_MSG(UtilityFunctions::is_equal_approx(det,0.0f),"Can not add collision shape determinant is zero");
    det = det < 0 ? -1.0f : 1.0f;
    Vector3 size_signs;
    if(det < 0){
        Basis bx = col_transform.basis;
        bx.set_column(0,Vector3(1,1,1));
        Basis by = col_transform.basis;
        by.set_column(1,Vector3(1,1,1));
        Basis bz = col_transform.basis;
        bz.set_column(2,Vector3(1,1,1));
        size_signs.x = det * bx.determinant();
        size_signs.y = det * by.determinant();
        size_signs.z = det * bz.determinant();
        // -----
        size_signs.x = size_signs.x < 0 ? -1.0f : 1.0f;
        size_signs.y = size_signs.y < 0 ? -1.0f : 1.0f;
        size_signs.z = size_signs.z < 0 ? -1.0f : 1.0f;
    }
    Vector3 size;
    {
        size.x = col_transform.basis.get_column(0).length();
        size.y = col_transform.basis.get_column(1).length();
        size.z = col_transform.basis.get_column(2).length();
    }
    if(det < 0){
        if(size_signs.x < 0){
            col_transform.basis.scale(Vector3(-1,1,1));
        }
        if(size_signs.y < 0){
            col_transform.basis.scale(Vector3(1,-1,1));
        }
        if(size_signs.z < 0){
            col_transform.basis.scale(Vector3(1,1,-1));
        }
    }
    size = col_transform.get_basis().get_scale();
    size.x = std::abs(size.x);
    size.y = std::abs(size.y);
    size.z = std::abs(size.z);
    Transform3D t = base_transform.inverse() * col_transform;
    t.orthonormalize();
    // Shape
    CollisionShape shape;
    shape.type = col_type;
    shape.param_1 = size.x;
    shape.param_2 = size.y;
    shape.param_3 = size.z;
    if(col_type==CollisionType::SHPERE){
        shape.param_1 = MAX(shape.param_1,shape.param_2);
        shape.param_1 = MAX(shape.param_1,shape.param_3);
    } else if(col_type==CollisionType::CAPSULE || col_type==CollisionType::CYLINDER){
        shape.param_1 = MAX(shape.param_1,shape.param_3);
        shape.param_2 *= 2.0;
    } else if(col_type==CollisionType::BOX){
        shape.param_1 *= 2.0f;
        shape.param_2 *= 2.0f;
        shape.param_3 *= 2.0f;
    }
    
    int index=-1;
    if(!collisions_data.has(collection_id)){
        index = collisions_data.insert(collection_id,CollisionData());
    } else {
        index = collisions_data.find(collection_id);
    }
    ERR_FAIL_COND(index==-1);
    CollisionData& col_data = collisions_data.get_array()[index].value;
    col_data.collision_shapes.push_back(shape);
    col_data.collision_shapes_transforms.push_back(t);
}

PackedInt32Array MAssetTable::collection_get_sub_collections(int collection_id) const{
    ERR_FAIL_COND_V(!has_collection(collection_id),PackedInt32Array());
    if(!sub_collections.has(collection_id)){
        return PackedInt32Array();
    }
    return sub_collections[collection_id].sub_collections;
}

int MAssetTable::collection_get_collision_count(int collection_id) const{
    int cindex = collisions_data.find(collection_id);
    if(cindex==-1){
        return 0;
    }
    return collisions_data.getv(cindex).collision_shapes.size();
}

void MAssetTable::collection_remove_tag(int collection_id,int tag){
    ERR_FAIL_COND(!has_collection(collection_id));
    ERR_FAIL_COND(tag > M_MAX_TAG);
    collections_tags.ptrw()[collection_id].remove_tag(tag);
}

void MAssetTable::collection_set_name(int collection_id,ItemType expected_type,const String& new_name){
    ERR_FAIL_COND(!has_collection(collection_id));
    ERR_FAIL_COND(expected_type==MESH);
    ERR_FAIL_COND(collections[collection_id].type!=expected_type);
    collections_names.set(collection_id,new_name);
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

Vector<Pair<int,Transform3D>> MAssetTable::collection_get_sub_collection_id_transform(int collection_id) const{
    Vector<Pair<int,Transform3D>> out;
    int cindex = sub_collections.find(collection_id);
    if(cindex==-1){
        return out;
    }
    ERR_FAIL_COND_V(!has_collection(collection_id),out);
    const PackedInt32Array& _ids = sub_collections.get_array()[cindex].value.sub_collections;
    const Vector<Transform3D>& _ts = sub_collections.get_array()[cindex].value.sub_collections_transforms;
    for(int i=0; i < _ids.size(); i++) {
        out.push_back({_ids[i],_ts[i]});
    }
    return out;
}

bool MAssetTable::group_exist(const String& name) const{
    return group_names.find(name) >= 0;
}

bool MAssetTable::group_create(const String& name){
    ERR_FAIL_COND_V(name.length()==0,false);
    group_names.push_back(name);
    groups.push_back(Tag());
    return true;
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

/*
    data structure:
    4byte (uint32_t) -> sub_collection_count -> 0
    4byte (uint32_t) -> collision_shapes count -> 4
    subs
    cols
    Total size = COLLECTION_DATA_HEADER_SIZE + sizeof(MAssetTable::Collection) +  i_size + t_size
*/
#define COLLECTION_DATA_HEADER_SIZE 8
void MAssetTable::set_collection_data(int collection_id,const PackedByteArray& data) {
    ERR_FAIL_INDEX(collection_id,collections.size());
    //collection_clear(collection_id); // don't add this
    if(data.size()==0){
        return;
    }
    ERR_FAIL_COND(data.size() < COLLECTION_DATA_HEADER_SIZE + sizeof(Collection));
    int32_t sub_count = data.decode_s32(0);
    int32_t col_count = data.decode_s32(4);
    ERR_FAIL_COND(sub_count<0||col_count<0);
    int sub_id_total_size = sub_count * (sizeof(int32_t));
    int sub_t_total_size = sub_count * (sizeof(Transform3D));
    int col_s_total_size = col_count * (sizeof(CollisionShape));
    int col_t_total_size = col_count * (sizeof(Transform3D));
    ERR_FAIL_COND(data.size()!=COLLECTION_DATA_HEADER_SIZE+sizeof(Collection)+sub_id_total_size+sub_t_total_size+col_s_total_size+col_t_total_size);
    int head = COLLECTION_DATA_HEADER_SIZE;
    memcpy(collections.ptrw()+collection_id,data.ptr()+head,sizeof(Collection));
    head += sizeof(Collection);
    if(sub_count!=0){
        sub_collections.insert(collection_id,SubCollectionData());
        int c = sub_collections.find(collection_id);
        SubCollectionData& sd = sub_collections.getv(c);
        sd.sub_collections.resize(sub_count);
        sd.sub_collections_transforms.resize(sub_count);
        memcpy(sd.sub_collections.ptrw(),data.ptr()+head,sub_id_total_size);
        head += sub_id_total_size;
        memcpy(sd.sub_collections_transforms.ptrw(),data.ptr()+head,sub_t_total_size);
        head += sub_t_total_size;
    }
    if(col_count!=0){
        collisions_data.insert(collection_id,CollisionData());
        int c = collisions_data.find(collection_id);
        CollisionData& cd = collisions_data.getv(c);
        cd.collision_shapes.resize(col_count);
        cd.collision_shapes_transforms.resize(col_count);
        memcpy(cd.collision_shapes.ptrw(),data.ptr()+head,col_s_total_size);
        head += col_s_total_size;
        memcpy(cd.collision_shapes_transforms.ptrw(),data.ptr()+head,col_t_total_size);
        head += col_t_total_size;
    }
    //Done
}

PackedByteArray MAssetTable::get_collection_data(int collection_id) const {
    PackedByteArray data;
    if(!has_collection(collection_id)){
        return data;
    }
    data.resize(COLLECTION_DATA_HEADER_SIZE);
    const Collection& cl = collections[collection_id];
    int sub_count=0;
    const PackedInt32Array* sub_cl;
    const Vector<Transform3D>* sub_t;
    {
        int c = sub_collections.find(collection_id);
        if(c!=-1){
            sub_cl = &sub_collections.get_array()[c].value.sub_collections;
            sub_t = &sub_collections.get_array()[c].value.sub_collections_transforms;
            sub_count = sub_cl->size();
        }
    }
    int col_count=0;
    const Vector<CollisionShape>* col_shapes;
    const Vector<Transform3D>* col_t;
    {
        int c = collisions_data.find(collection_id);
        if(c!=-1){
            col_shapes = &collisions_data.get_array()[c].value.collision_shapes;
            col_t = &collisions_data.get_array()[c].value.collision_shapes_transforms;
            col_count = col_shapes->size();
        }
    }
    data.encode_s32(0,sub_count);
    data.encode_s32(4,col_count);
    
    int sub_id_total_size = sub_count * (sizeof(int32_t));
    int sub_t_total_size = sub_count * (sizeof(Transform3D));
    int col_s_total_size = col_count * (sizeof(CollisionShape));
    int col_t_total_size = col_count * (sizeof(Transform3D));
    data.resize(COLLECTION_DATA_HEADER_SIZE+sizeof(Collection)+sub_id_total_size+sub_t_total_size+col_s_total_size+col_t_total_size);
    int head = COLLECTION_DATA_HEADER_SIZE;
    memcpy(data.ptrw()+head,collections.ptr()+collection_id,sizeof(Collection));
    head += sizeof(Collection);
    if(sub_count!=0){
        memcpy(data.ptrw()+head,sub_cl->ptr(),sub_id_total_size);
        head += sub_id_total_size;
        memcpy(data.ptrw()+head,sub_t->ptr(),sub_t_total_size);
        head += sub_t_total_size;
    }
    if(col_count!=0){
        memcpy(data.ptrw()+head,col_shapes->ptr(),col_s_total_size);
        head += col_s_total_size;
        memcpy(data.ptrw()+head,col_t->ptr(),col_t_total_size);
        head += col_t_total_size;
    }
    return data;
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
        collections.resize(s_collections.size());
        for(int i=0; i < s_collections.size();i++){
            if(free_collections.has(i)){
                continue;
            }
            set_collection_data(i,s_collections[i]);
        }
    }

    collections_tags = MTool::packed_byte_array_to_vector<Tag>(data["collections_tags"]);
    groups = MTool::packed_byte_array_to_vector<Tag>(data["groups"]);
    physics_names = data["physics_names"];
    collections_names = data["collections_names"];
    tag_names = data["tag_names"];
    group_names = data["group_names"];
}

Dictionary MAssetTable::get_data(){
    Dictionary data;
    {
        Array s_collections;
        for(int i=0; i < collections.size(); i++){
            PackedByteArray __d = get_collection_data(i);
            s_collections.push_back(__d);
        }
        data["collections"] = s_collections;
    }
    data["free_collections"] = MTool::vector_to_packed_byte_array<int32_t>(free_collections);

    data["collections_tags"] = MTool::vector_to_packed_byte_array<Tag>(collections_tags);
    data["groups"] = MTool::vector_to_packed_byte_array<Tag>(groups);

    data["collections_names"] = collections_names;
    data["physics_names"] = physics_names;
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

void MAssetTable::clear_import_info_cache(){
    import_info.clear();
}

void MAssetTable::save_import_info(){
    if(import_info.is_empty()){
        return;
    }
    make_assets_dir();
    String imstr = JSON::stringify(import_info);
    Ref<FileAccess> f = FileAccess::open(import_info_path,FileAccess::WRITE);
    f->store_string(imstr);
    f->close();
}

void MAssetTable::load_import_info(){
    if(FileAccess::file_exists(import_info_path)){
        String imstr = FileAccess::get_file_as_string(import_info_path);
        import_info =  JSON::parse_string(imstr);
        Dictionary __materials;
        Dictionary __materials_final;
        if(import_info.has("__materials")){
            __materials = import_info["__materials"];
        }
        Array keys = __materials.keys();
        for(int i=0; i < keys.size(); i++){
            String skey = keys[i];
            int ikey = skey.to_int();
            __materials_final[ikey] = __materials[skey];
        }
        import_info["__materials"] = __materials_final;
    }
}

void MAssetTable::set_import_info(const Dictionary& input){
    if(import_info.is_empty()){
        load_import_info();
    }
    import_info = input;
}

Dictionary MAssetTable::get_import_info(){
    if(!import_info.is_empty()){
        return import_info;
    }
    load_import_info();
    return import_info;
}

void MAssetTable::auto_asset_update_from_dir(ItemType type){
    ERR_FAIL_COND_MSG(type==MESH,"Type mesh can not be update with directory checking!");
    HashMap<int32_t,String> found_item_id_names;
    String dir_path;
    String (*func_path)(int32_t) = nullptr;
    String default_name;
    switch (type)
    {
    case HLOD:
        dir_path = MHlod::get_hlod_root_dir();
        func_path = &MHlod::get_hlod_path;
        default_name = "HOLD_";
        break;
    case PACKEDSCENE:
        dir_path = MHlod::get_packed_scene_root_dir();
        func_path = &MHlod::get_packed_scene_path;
        default_name = "PACKEDSCENE_";
        break;
    case DECAL:
        dir_path = MHlod::get_decal_root_dir();
        func_path = &MHlod::get_decal_path;
        default_name = "DECAL_";
        break;
    default:
        ERR_FAIL_MSG("Invalid Item Type");
    }
    Ref<DirAccess> dir = DirAccess::open(dir_path);
    PackedStringArray file_names = dir->get_files();
    if(dir.is_valid()){
        PackedStringArray file_names = dir->get_files();
        dir.unref();
    }
    UtilityFunctions::print("File names ",file_names);
    for(const String& fname : file_names){
        String tmp = fname.get_basename();
        if(!tmp.is_valid_int()){
            continue;
        }
        int32_t item_id = tmp.to_int();
        Ref<Resource> res = RL->load(func_path(item_id));
        if(res.is_valid()){
            String rname;
            if(type==ItemType::PACKEDSCENE){
                Ref<PackedScene> pscene = res;
                if(pscene.is_valid()){
                    rname = pscene->get_state()->get_node_name(0);
                }
            } else {
                rname = res->get_name();
            }
            if(rname.is_empty()){
                rname = default_name + itos(item_id);
            }
            found_item_id_names.insert(item_id,rname);
        }
    }
    for(int i=0; i < collections.size(); i++){
        if(collections[i].type!=type || collections[i].item_id==-1){
            continue;
        }
        int32_t current_item_id = collections[i].item_id;
        if(found_item_id_names.has(current_item_id)){
            collection_set_name(i,type,found_item_id_names[current_item_id]);
            found_item_id_names.erase(current_item_id); // handled
        } else { // means it is removed
            UtilityFunctions::print("Removing ",collection_get_item_id(i));
            collection_remove(i);
        }
    }
    // What not handled is new
    for(HashMap<int32_t,String>::ConstIterator it=found_item_id_names.begin();it!=found_item_id_names.end();++it){
        int new_collection = collection_create(it->value,it->key,type,-1);
    }
    save();
}

void MAssetTable::reset(bool hard){

}


void MAssetTable::debug_test(){

}