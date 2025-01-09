#include "masset_table.h"

#include "mtool.h"

#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/resource_saver.hpp>
#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

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

    ClassDB::bind_method(D_METHOD("has_mesh_item","mesh_id"), &MAssetTable::has_mesh_item);
    ClassDB::bind_method(D_METHOD("has_collection","collection_id"), &MAssetTable::has_collection);
    ClassDB::bind_method(D_METHOD("remove_mesh_item","mesh_id"), &MAssetTable::remove_mesh_item);
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
    ClassDB::bind_method(D_METHOD("mesh_item_add","mesh","material"), &MAssetTable::mesh_item_add);
    ClassDB::bind_method(D_METHOD("mesh_item_update","mesh_id","mesh","material"), &MAssetTable::mesh_item_update);
    ClassDB::bind_method(D_METHOD("mesh_item_remove","mesh_id"), &MAssetTable::mesh_item_remove);
    ClassDB::bind_method(D_METHOD("mesh_item_find_by_info","mesh","material"), &MAssetTable::mesh_item_find_by_info);
    ClassDB::bind_method(D_METHOD("mesh_item_find_collections","mesh_id"), &MAssetTable::mesh_item_find_collections);
    ClassDB::bind_method(D_METHOD("mesh_item_find_collections_with_tag","mesh_id","tag_id"), &MAssetTable::mesh_item_find_collections_with_tag);
    ClassDB::bind_method(D_METHOD("mesh_item_get_info","mesh_id"), &MAssetTable::mesh_item_get_info);
    ClassDB::bind_method(D_METHOD("mesh_item_get_list"), &MAssetTable::mesh_item_get_list);
    ClassDB::bind_method(D_METHOD("collection_create","name"), &MAssetTable::collection_create);
    ClassDB::bind_method(D_METHOD("collection_set_glb_id","collection_id","glb_id"), &MAssetTable::collection_set_glb_id);
    ClassDB::bind_method(D_METHOD("collection_get_glb_id","collection_id"), &MAssetTable::collection_get_glb_id);
    ClassDB::bind_method(D_METHOD("collection_set_cache_thumbnail","collection_id","tex","creation_time"), &MAssetTable::collection_set_cache_thumbnail);
    ClassDB::bind_method(D_METHOD("collection_get_cache_thumbnail","collection_id"), &MAssetTable::collection_get_cache_thumbnail);
    ClassDB::bind_method(D_METHOD("collection_get_thumbnail_creation_time","collection_id"), &MAssetTable::collection_get_thumbnail_creation_time);
    ClassDB::bind_method(D_METHOD("collection_add_item","collection_id","item_type","item_id","transform"), &MAssetTable::collection_add_item);
    ClassDB::bind_method(D_METHOD("collection_clear","collection_id"), &MAssetTable::collection_clear);
    ClassDB::bind_method(D_METHOD("collection_remove","collection_id"), &MAssetTable::collection_remove);
    ClassDB::bind_method(D_METHOD("collection_remove_item","collection_id","item_type","item_id"), &MAssetTable::collection_remove_item);
    ClassDB::bind_method(D_METHOD("collection_remove_all_items","collection_id"), &MAssetTable::collection_remove_all_items);
    ClassDB::bind_method(D_METHOD("collection_get_list"), &MAssetTable::collection_get_list);
    ClassDB::bind_method(D_METHOD("collection_get_item_transform","collection_id","type","item_id"), &MAssetTable::collection_get_item_transform);
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
    ClassDB::bind_method(D_METHOD("collection_get_mesh_items_info","collection_id"), &MAssetTable::collection_get_mesh_items_info);
    ClassDB::bind_method(D_METHOD("collection_get_mesh_items_ids","collection_id"), &MAssetTable::collection_get_mesh_items_ids);

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

    BIND_ENUM_CONSTANT(NONE);
    BIND_ENUM_CONSTANT(MESH);
    BIND_ENUM_CONSTANT(COLLISION);

    ClassDB::bind_method(D_METHOD("get_data"), &MAssetTable::get_data);
    ClassDB::bind_method(D_METHOD("set_data","data"), &MAssetTable::set_data);
    ADD_PROPERTY(PropertyInfo(Variant::DICTIONARY,"data"),"set_data","get_data");

    ClassDB::bind_method(D_METHOD("get_import_info"), &MAssetTable::get_import_info);
    ClassDB::bind_method(D_METHOD("set_import_info","input"), &MAssetTable::set_import_info);
    ADD_PROPERTY(PropertyInfo(Variant::DICTIONARY,"import_info"),"set_import_info","get_import_info");

    ClassDB::bind_method(D_METHOD("mesh_get_id","mesh"), &MAssetTable::mesh_get_id);
    ClassDB::bind_method(D_METHOD("mesh_get_path","mesh"), &MAssetTable::mesh_get_path);
    ClassDB::bind_method(D_METHOD("mesh_get_mesh_items_users","mesh_id"), &MAssetTable::mesh_get_mesh_items_users);
    ClassDB::bind_method(D_METHOD("mesh_exist","mesh"), &MAssetTable::mesh_exist);
    ClassDB::bind_method(D_METHOD("mesh_update","old_mesh","new_mesh"), &MAssetTable::mesh_update);
    ClassDB::bind_method(D_METHOD("initialize_mesh_hashes"), &MAssetTable::initialize_mesh_hashes);
    ClassDB::bind_method(D_METHOD("mesh_add","mesh"), &MAssetTable::mesh_add);
    ClassDB::bind_method(D_METHOD("mesh_remove","mesh_id"), &MAssetTable::mesh_remove);

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

bool MAssetTable::MeshItem::insert_data(const PackedInt64Array& mesh,int _material_set_id){
    // Checking if exist

    int _lod_count = mesh.size();
    ERR_FAIL_COND_V(_lod_count > 126,false);
    ERR_FAIL_COND_V(_lod_count == 0,false);
    ERR_FAIL_COND_V(_material_set_id > MAX_MATERIAL_SET_ID,false);
    /// We are Ok to go
    path = mesh;
    material_set_id = _material_set_id;
    return true;
}

int MAssetTable::MeshItem::get_lod_count() const{
    return path.size();
}

bool MAssetTable::MeshItem::has_mesh(int64_t mesh_id) const{
    int lod_count = get_lod_count();
    for(int i=0; i < lod_count; i++){
        if(mesh_id == path[i]){
            return true;
        }
    }
    return false;
}

bool MAssetTable::MeshItem::has_material(int32_t m) const{
    return material_set_id == m;
}

int64_t MAssetTable::MeshItem::hash(){
    String s = UtilityFunctions::var_to_str(path);
    return s.hash();
}

void MAssetTable::MeshItem::clear(){
    path.clear();
    material_set_id = -1;
}

Dictionary MAssetTable::MeshItem::get_creation_data() const{
    Dictionary data;
    data["mesh"] = path;
    data["material"] = material_set_id;
    return data;
}

/*
    data structure:
    1Byte uint8_t -> lod_count
    1Byte int8_t -> mesh_set_id
    Total Size -> 2byte + lod_count*sizeof(int64_t)
*/
void MAssetTable::MeshItem::set_save_data(const PackedByteArray& data){
    if(data.size()==0){
        return;
    }
    ERR_FAIL_COND(data.size() < 2);
    int lod_count = (int)data[0];
    int total_size = 2 + lod_count*sizeof(int64_t);
    ERR_FAIL_COND(data.size()!=total_size);
    material_set_id = data[1];
    path.resize(lod_count);
    memcpy(path.ptrw(),data.ptr()+2,lod_count*sizeof(int64_t));
}

PackedByteArray MAssetTable::MeshItem::get_save_data() const {
    PackedByteArray data;
    int lod_count = get_lod_count();
    if(lod_count==0){
        return data;
    }
    int total_size = 2 + lod_count*sizeof(int64_t);
    data.resize(total_size);
    data.set(0,(uint8_t)lod_count);
    data.set(1, material_set_id);
    memcpy(data.ptrw()+2,path.ptr(),lod_count*sizeof(int64_t));
    return data;
}

bool MAssetTable::MeshItem::operator==(const MeshItem& other) const{
    return path == other.path;
}

void MAssetTable::Collection::set_glb_id(int32_t input){
    glb_id = input;
}

int32_t MAssetTable::Collection::get_glb_id() const{
    return glb_id;
}

void MAssetTable::Collection::clear(){
    items.clear();
    transforms.clear();
    sub_collections.clear();
    sub_collections_transforms.clear();
}

/*
    data structure:
    4byte (uint32_t) -> item_count
    4byte (uint32_t) -> sub_collection_count
    4byte (uint32_t) -> glb_id_byte_size
    sizeof(Pair<ItemType,int>) * items.size()
    sizeof(Transform3D) * transforms.size()
    Total size = 8 + i_size + t_size
*/
void MAssetTable::Collection::set_save_data(const PackedByteArray& data){
    if(data.size()==0){
        clear();
        return;
    }
    ERR_FAIL_COND(data.size() < 12);
    uint32_t item_count = data.decode_u32(0);
    uint32_t sub_collections_count = data.decode_u32(4);
    glb_id = data.decode_s32(8);
    ERR_FAIL_COND(item_count < 0 || sub_collections_count < 0);
    int i_size = sizeof(Pair<ItemType,int>) * item_count;
    int t_size = sizeof(Transform3D) * item_count;

    int c_size = sizeof(int) * sub_collections_count;
    int ct_size = sizeof(Transform3D) * sub_collections_count;

    ERR_FAIL_COND(data.size() != 12 + i_size + t_size + c_size + ct_size);
    items.resize(item_count);
    transforms.resize(item_count);

    sub_collections.resize(sub_collections_count);
    sub_collections_transforms.resize(sub_collections_count);

    int header = 12;
    memcpy(items.ptrw(),data.ptr()+header,i_size);
    header += i_size;
    memcpy(transforms.ptrw(),data.ptr()+header,t_size);
    header += t_size;
    memcpy(sub_collections.ptrw(),data.ptr()+header,c_size);
    header += c_size;
    memcpy(sub_collections_transforms.ptrw(),data.ptr()+header,ct_size);
}

PackedByteArray MAssetTable::Collection::get_save_data() const {
    PackedByteArray data;
    ERR_FAIL_COND_V(items.size()!=transforms.size(),data);
    ERR_FAIL_COND_V(sub_collections.size()!=sub_collections_transforms.size(),data);
    if(items.size()==0 && sub_collections.size() == 0){
        return data;
    }
    int i_size = sizeof(Pair<ItemType,int>) * items.size();
    int t_size = sizeof(Transform3D) * transforms.size();

    int c_size = sizeof(int) * sub_collections.size();
    int ct_size = sizeof(Transform3D) * sub_collections_transforms.size();

    data.resize(12 + i_size + t_size + c_size + ct_size);
    data.encode_u32(0,items.size());
    data.encode_u32(4,sub_collections.size());
    data.encode_s32(8,glb_id);
    int header = 12;
    memcpy(data.ptrw()+header,items.ptr(),i_size);
    header += i_size;
    memcpy(data.ptrw()+header,transforms.ptr(),t_size);
    header += t_size;
    memcpy(data.ptrw()+header,sub_collections.ptr(),c_size);
    header += c_size;
    memcpy(data.ptrw()+header,sub_collections_transforms.ptr(),ct_size);
    return data;
}

void MAssetTable::_increase_mesh_item_buffer_size(int q){
    if(q<=0){
        return;
    }
    int64_t lsize = mesh_items.size();
    godot::Error err = mesh_items.resize(lsize + q);
    ERR_FAIL_COND_MSG(err!=godot::Error::OK,"Can't increase mesh item buffer size, possible fragmentation error!");
    err = mesh_items_hashes.resize(lsize + q);
    ERR_FAIL_COND_MSG(err!=godot::Error::OK,"Can't increase mesh item hash buffer size, possible fragmentation error!");
    for(int64_t i=mesh_items.size() - 1; i >= lsize ; i--){
        free_mesh_items.push_back(i);
    }
}

int MAssetTable::_get_free_mesh_item_index(){
    if(free_mesh_items.size() == 0){
        _increase_mesh_item_buffer_size(10);
    }
    ERR_FAIL_COND_V(free_mesh_items.size()==0,-1);
    int index = free_mesh_items[free_mesh_items.size() - 1];
    free_mesh_items.remove_at(free_mesh_items.size() - 1);
    return index;
}

void MAssetTable::_increase_collection_buffer_size(int q){
    if(q<=0){
        return;
    }
    ERR_FAIL_COND(collections_tags.size() != collections.size());
    ERR_FAIL_COND(collections_tags.size() != collections_names->size());
    int64_t lsize = collections.size();
    godot::Error err = collections.resize(lsize + q);
    ERR_FAIL_COND_MSG(err!=godot::Error::OK,"Can't increase collection item buffer size, possible fragmentation error!");
    err = collections_tags.resize(lsize + q);
    ERR_FAIL_COND_MSG(err!=godot::Error::OK,"Can't increase collection item buffer size, possible fragmentation error!");
    bool success = collections_names->resize(lsize + q);
    ERR_FAIL_COND_MSG(!success,"Can't increase collection names buffer size, possible fragmentation error!");
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

bool MAssetTable::has_mesh_item(int id) const{
    return id >= 0 && id < mesh_items.size() && !free_mesh_items.has(id);
}

bool MAssetTable::has_collection(int id) const{
    return id >= 0 && id < collections.size() && !free_collections.has(id);
}

void MAssetTable::remove_mesh_item(int id){
    ERR_FAIL_COND(!has_mesh_item(id));
    mesh_items.ptrw()[id].clear();
    free_mesh_items.push_back(id);
    for(int i=0; i < collections.size(); ++i){
        if(free_collections.has(i)){
            continue;
        }
        collection_remove_item(i,ItemType::MESH,id);
    }
}

void MAssetTable::remove_collection(int id){
    ERR_FAIL_COND(!has_collection(id));
    collections.ptrw()[id].clear();
    collections_tags.ptrw()[id].clear();
    collections_names->set_element(id,"");
    UtilityFunctions::print("Removing collection clearing id ",id, " name afer clear ",collections_names->get_element(id));
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
    collections_names.instantiate();
    tag_names.instantiate();
    group_names.instantiate();
    tag_names->resize(M_MAX_TAG);
}

int MAssetTable::tag_add(const String& name){
    ERR_FAIL_COND_V_MSG(tag_names->has(name),-1,"Tag \""+name+"\" already exist");
    for(int i=0; i < M_MAX_TAG; i++){
        UtilityFunctions::print(i, " -> ",tag_names->is_element_empty(i));
        if(tag_names->is_element_empty(i)){
            tag_names->set_element(i,name);
            return i;
        }
    }
    ERR_FAIL_V_MSG(-1,"No empty Tag");
}

void MAssetTable::tag_set_name(int tag_id,const String& name){
    ERR_FAIL_COND(tag_id > M_MAX_TAG || tag_id < 0);
    tag_names->set_element(tag_id,name);
}

String MAssetTable::tag_get_name(int tag_id) const {
    ERR_FAIL_COND_V(tag_id > M_MAX_TAG || tag_id < 0,String(""));
    if(tag_id > tag_names->size()){
        return "";
    }
    return tag_names->get_element(tag_id);
}

Dictionary MAssetTable::tag_get_names() const{
    Dictionary out;
    for(int i=0; i < M_MAX_TAG; i++){
        if(!tag_names->is_element_empty(i)){
            out[tag_names->get_element(i)] = i;
        }
    }
    return out;
}

int MAssetTable::tag_get_id(const String& tag_name){
    return tag_names->find(tag_name);
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
    return tag_names->begin_with(prefix);
}

int MAssetTable::mesh_item_add(const PackedInt64Array& mesh,int material_set_id){
    //int fid = mesh_item_find_by_info(mesh,material_set_id);
    //if(fid!=-1){
    //    return fid;
    //}
    MAssetTable::MeshItem mitem;
    if(mitem.insert_data(mesh,material_set_id)){
        int index = _get_free_mesh_item_index();
        if(index < 0){
            return index;
        }
        mesh_items.set(index,mitem);
        mesh_items_hashes.set(index,mitem.hash());
        return index;
    }
    return -1;
}

void MAssetTable::mesh_item_update(int mesh_id,const PackedInt64Array& mesh,int material_set_id){
    ERR_FAIL_COND(!has_mesh_item(mesh_id));
    MAssetTable::MeshItem mitem;
    if(mitem.insert_data(mesh,material_set_id)){
        mesh_items.set(mesh_id,mitem);
    }
}

void MAssetTable::mesh_item_remove(int mesh_id){
    ERR_FAIL_COND(!has_mesh_item(mesh_id));
    free_mesh_items.push_back(mesh_id);
    mesh_items.ptrw()[mesh_id].clear();
    //mesh_items_hashes.set(mesh_id,0);
}

int MAssetTable::mesh_item_find_by_info(const PackedInt64Array& mesh,int material) const{
    MAssetTable::MeshItem mitem;
    if(mitem.insert_data(mesh,material)){
        int64_t h = mitem.hash();
        int findex = mesh_items_hashes.find(h);
        if(findex==-1){
            return -1;
        }
        if(free_mesh_items.find(findex)==-1 && mitem == mesh_items[findex]){
            return findex;
        }
    }
    return -1;
}

PackedInt32Array MAssetTable::mesh_item_find_collections(int mesh_id) const{
    PackedInt32Array out;
    ERR_FAIL_COND_V(!has_mesh_item(mesh_id),out);
    Pair<ItemType,int> element(ItemType::MESH,mesh_id);
    for(int i=0; i < collections.size(); i++){
        if(free_collections.find(i)!=-1){
            continue;
        }
        if(collections[i].items.find(element)!=-1){
            out.push_back(i);
        }
    }
    return out;
}

PackedInt32Array MAssetTable::mesh_item_find_collections_with_tag(int mesh_id,int tag_id) const{
    PackedInt32Array out;
    ERR_FAIL_COND_V(!has_mesh_item(mesh_id),out);
    Pair<ItemType,int> element(ItemType::MESH,mesh_id);
    for(int i=0; i < collections.size(); i++){
        if(!collections_tags[i].has_tag(tag_id)){
            continue;
        }
        if(collections[i].items.find(element)!=-1){
            out.push_back(i);
        }
    }
    return out;
}

PackedInt64Array MAssetTable::mesh_item_get_mesh(int mesh_id) const {
    ERR_FAIL_COND_V(!has_mesh_item(mesh_id),PackedInt64Array());
    return mesh_items.ptr()[mesh_id].path;
}

int MAssetTable::mesh_item_get_material(int mesh_id) const {
    ERR_FAIL_COND_V(!has_mesh_item(mesh_id),-1);
    return mesh_items.ptr()[mesh_id].material_set_id;
}

Dictionary MAssetTable::mesh_item_get_info(int mesh_id){
    ERR_FAIL_COND_V(!has_mesh_item(mesh_id),Dictionary());
    return mesh_items[mesh_id].get_creation_data();
}

PackedInt32Array MAssetTable::mesh_item_get_list() const{
    PackedInt32Array out;
    for(int i=0; i < mesh_items.size(); i++){
        if(free_mesh_items.has(i)){
            continue;
        }
        out.push_back(i);
    }
    return out;
}

int MAssetTable::collection_create(String name){
    ERR_FAIL_COND_V(name.length()==0,-1);
    if(collections_names->has(name)){
        int lcount = 2;
        while (true)
        {
            String uname = name + itos(lcount);
            if(!collections_names->has(uname)){
                name = uname;
                break;
            }
            ERR_FAIL_COND_V_MSG(lcount > 10000,-1,"Can not find a unique name please try another name");
            lcount++;
        }
    }
    int index = _get_free_collection_index();
    ERR_FAIL_COND_V(index==-1,-1);
    collections_names->set_element(index,name);
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

bool MAssetTable::collection_rename(int collection_id,const String& new_name){
    ERR_FAIL_COND_V(!has_collection(collection_id),false);
    ERR_FAIL_COND_V(new_name.length()==0,false);
    return collections_names->set_element(collection_id,new_name);
}

void MAssetTable::collection_add_item(int collection_id,ItemType type, int item_id,const Transform3D& transform){
    ERR_FAIL_COND(!has_collection(collection_id));
    switch (type)
    {
    case ItemType::MESH:
        ERR_FAIL_COND(!has_mesh_item(item_id));
        break;    
    default:
        ERR_FAIL_MSG("uknow item type");
        break;
    }
    collections.ptrw()[collection_id].items.push_back({type,item_id});
    collections.ptrw()[collection_id].transforms.push_back(transform);
}

void MAssetTable::collection_clear(int collection_id){
    ERR_FAIL_COND(!has_collection(collection_id));
    collections.ptrw()[collection_id].clear();
}

void MAssetTable::collection_remove(int collection_id){
    ERR_FAIL_COND(!has_collection(collection_id));
    free_collections.push_back(collection_id);
    collections.ptrw()[collection_id].clear();
    collections_names->set_element(collection_id,"");
    collections_tags.ptrw()[collection_id].clear();
}

void MAssetTable::collection_remove_item(int collection_id,ItemType type, int item_id){
    ERR_FAIL_COND(!has_collection(collection_id));
    Collection* c = collections.ptrw() + collection_id;
    int index = c->items.find(Pair<ItemType,int>(type,item_id));
    if(index >= 0){
        c->items.remove_at(index);
        c->transforms.remove_at(index);
    }
}

void MAssetTable::collection_remove_all_items(int collection_id){
    ERR_FAIL_COND(!has_collection(collection_id));
    Collection* c = collections.ptrw() + collection_id;
    c->items.clear();
    c->transforms.clear();
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

Transform3D MAssetTable::collection_get_item_transform(int collection_id,ItemType type, int item_id) const{
    ERR_FAIL_COND_V(!has_collection(collection_id),Transform3D());
    const Collection* c = collections.ptr() + collection_id;
    int index = c->items.find(Pair<ItemType,int>(type,item_id));
    ERR_FAIL_COND_V_MSG(index < 0,Transform3D(),"Can not find item");
    return c->transforms[index];
}

void MAssetTable::collection_update_item_transform(int collection_id,ItemType type, int item_id,const Transform3D& transform){
    ERR_FAIL_COND(!has_collection(collection_id));
    Collection* c = collections.ptrw() + collection_id;
    int index = c->items.find(Pair<ItemType,int>(type,item_id));
    ERR_FAIL_COND_MSG(index < 0,"Can not find item");
    c->transforms.set(index,transform);
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
    if(collections_names->has(name)){
        int lcount = 2;
        while (true)
        {
            String uname = name + itos(lcount);
            if(!collections_names->has(uname)){
                name = uname;
                break;
            }
            ERR_FAIL_COND_MSG(lcount > 10000,"Can not find a unique name please try another name");
            lcount++;
        }
    }
    collections_names->set_element(collection_id,name);
}

String MAssetTable::collection_get_name(int collection_id) const{
    ERR_FAIL_COND_V(!has_collection(collection_id),"");
    return collections_names->get_element(collection_id);
}

int MAssetTable::collection_get_id(const String& name) const{
    return collections_names->find(name);
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
    return collections_names->begin_with(prefix);
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

Vector<Pair<int,Transform3D>> MAssetTable::collection_get_mesh_items_id_transform(int collection_id){
    Vector<Pair<int,Transform3D>> out;
    ERR_FAIL_COND_V(!has_collection(collection_id),out);
    const Pair<ItemType,int>* ptr = collections.ptr()[collection_id].items.ptr();
    int size = collections.ptr()[collection_id].items.size();
    for(int i=0; i < size; i++) {
        if(ptr[i].first == ItemType::MESH){
            out.push_back({ptr[i].second,collections.ptr()[collection_id].transforms[i]});
        }
    }
    return out;
}

Array MAssetTable::collection_get_mesh_items_info(int collection_id) const {
    Array out;
    ERR_FAIL_COND_V(!has_collection(collection_id),out);
    const Pair<ItemType,int>* ptr = collections.ptr()[collection_id].items.ptr();
    int size = collections.ptr()[collection_id].items.size();
    for(int i=0; i < size; i++) {
        if(ptr[i].first == ItemType::MESH){
            Dictionary data = mesh_items[ptr[i].second].get_creation_data();
            data["id"] = ptr[i].second;
            data["transform"] = collections[collection_id].transforms[i];
            out.push_back(data);
        }
    }
    return out;
}

PackedInt32Array MAssetTable::collection_get_mesh_items_ids(int collection_id) const{
    PackedInt32Array out;
    ERR_FAIL_COND_V(!has_collection(collection_id),out);
    const Pair<ItemType,int>* ptr = collections.ptr()[collection_id].items.ptr();
    int size = collections.ptr()[collection_id].items.size();
    for(int i=0; i < size; i++) {
        if(ptr[i].first == ItemType::MESH){
            out.push_back(ptr[i].second);
        }
    }
    return out;
}

bool MAssetTable::group_exist(const String& name) const{
    return group_names->find(name) >= 0;
}

bool MAssetTable::group_create(const String& name){
    ERR_FAIL_COND_V(name.length()==0,false);
    if(group_names->push_back(name)){
        groups.push_back(Tag());
        return true;
    }
    return false;
}

bool MAssetTable::group_rename(const String& name,const String& new_name){
    ERR_FAIL_COND_V(name.length()==0,false);
    ERR_FAIL_COND_V(new_name.length()==0,false);
    int index = group_names->find(name);
    if(index < 0){
        return false;
    }
    return group_names->set_element(index, new_name);
}

void MAssetTable::group_remove(const String& name){
    int index = group_names->find(name);
    if(index >= 0){
        group_names->remove_at(index);
        groups.remove_at(index);
    }
}

PackedStringArray MAssetTable::group_get_list() const{
    return group_names->to_packed_string_array();
}

int MAssetTable::group_count() const{
    return groups.size();
}

void MAssetTable::group_add_tag(const String& name,int tag){
    int index = group_names->find(name);
    ERR_FAIL_COND_MSG(index < 0,"Can not find group with name "+name);
    groups.ptrw()[index].add_tag(tag);
}

void MAssetTable::group_remove_tag(const String& name,int tag){
    int index = group_names->find(name);
    ERR_FAIL_COND_MSG(index < 0,"Can not find group with name "+name);
    groups.ptrw()[index].remove_tag(tag);
}

PackedInt32Array MAssetTable::group_get_tags(const String& gname) const {
    PackedInt32Array out;
    int gindex = group_names->find(gname);
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
    int index = group_names->find(name);
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
    int index = group_names->find(name);
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
    int index = group_names->find(gname);
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

void MAssetTable::set_data(const Dictionary& data){
    ERR_FAIL_COND(!data.has("mesh_items"));
    ERR_FAIL_COND(!data.has("collections"));
    ERR_FAIL_COND(!data.has("collections_tags"));
    ERR_FAIL_COND(!data.has("groups"));
    ERR_FAIL_COND(!data.has("collections_names"));
    ERR_FAIL_COND(!data.has("tag_names"));
    ERR_FAIL_COND(!data.has("group_names"));
    mesh_items.clear();
    free_mesh_items.clear();
    mesh_items_hashes.clear();
    collections.clear();
    collections_names->clear();
    collections_tags.clear();
    tag_names->clear();
    groups.clear();
    group_names->clear();
    {
        Array s_mesh_items = data["mesh_items"];
        for(int i=0; i < s_mesh_items.size();i++){
            MeshItem mi;
            mi.set_save_data(s_mesh_items[i]);
            mesh_items.push_back(mi);
            mesh_items_hashes.push_back(mi.hash());
        }
    }
    free_mesh_items = MTool::packed_byte_array_to_vector<int32_t>(data["free_mesh_items"]);
    {
        Array s_collections = data["collections"];
        for(int i=0; i < s_collections.size();i++){
            Collection c;
            c.set_save_data(s_collections[i]);
            collections.push_back(c);
        }
    }
    free_collections = MTool::packed_byte_array_to_vector<int32_t>(data["free_collections"]);

    collections_tags = MTool::packed_byte_array_to_vector<Tag>(data["collections_tags"]);
    groups = MTool::packed_byte_array_to_vector<Tag>(data["groups"]);

    collections_names->append_string_array(data["collections_names"]);
    tag_names->append_string_array(data["tag_names"]);
    group_names->append_string_array(data["group_names"]);
}

Dictionary MAssetTable::get_data(){
    Dictionary data;
    {
        Array s_mesh_items;
        for(int i=0; i < mesh_items.size();i++){
            s_mesh_items.push_back(mesh_items[i].get_save_data());
        }
        data["mesh_items"] = s_mesh_items;
    }
    data["free_mesh_items"] = MTool::vector_to_packed_byte_array<int32_t>(free_mesh_items);
    {
        Array s_collections;
        for(int i=0; i < collections.size(); i++){
            s_collections.push_back(collections[i].get_save_data());
        }
        data["collections"] = s_collections;
    }
    data["free_collections"] = MTool::vector_to_packed_byte_array<int32_t>(free_collections);

    data["collections_tags"] = MTool::vector_to_packed_byte_array<Tag>(collections_tags);
    data["groups"] = MTool::vector_to_packed_byte_array<Tag>(groups);

    data["collections_names"] = collections_names->to_packed_string_array();
    data["tag_names"] = tag_names->to_packed_string_array();
    data["group_names"] = group_names->to_packed_string_array();
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

int MAssetTable::mesh_get_id(Ref<MMesh> mesh){
    ERR_FAIL_COND_V(mesh.is_null(),-1);
    if(!mesh_hashes.has(mesh)){
        return -1;
    }
    return mesh_hashes[mesh];
}

String MAssetTable::mesh_get_path(Ref<MMesh> mesh){
    ERR_FAIL_COND_V(mesh.is_null(),"");
    int64_t mesh_id = 0;
    if(!mesh_hashes.has(mesh)){
        return String("");
    }
    mesh_id = mesh_hashes[mesh];
    return String(MHlod::mesh_root_dir) + itos(mesh_id) + String(".res");
}

PackedInt32Array MAssetTable::mesh_get_mesh_items_users(int64_t mesh_id) const{
    PackedInt32Array out;
    for(int i=0; i < mesh_items.size(); i++){
        if(free_mesh_items.find(i)!=-1){
            continue;
        }
        if(mesh_items[i].has_mesh(mesh_id)){
            out.push_back(i);
        }
    }
    return out;
}

bool MAssetTable::mesh_exist(Ref<MMesh> mesh){
    ERR_FAIL_COND_V(mesh.is_null(),false);
    return mesh_hashes.has(mesh);
}

bool MAssetTable::mesh_update(Ref<MMesh> old_mesh,Ref<MMesh> new_mesh){
    ERR_FAIL_COND_V(new_mesh.is_null() || old_mesh.is_null(),false);
    ERR_FAIL_COND_V(!mesh_hashes.has(old_mesh),false);
    int mesh_id = mesh_hashes[old_mesh];
    ERR_FAIL_COND_V(mesh_id<=0,false);
    bool res = mesh_hashes.erase(old_mesh);
    ERR_FAIL_COND_V(!res,false);
    mesh_hashes.insert(new_mesh,mesh_id);
    return true;
}

void MAssetTable::initialize_mesh_hashes(){
    mesh_hashes.clear();
    Ref<DirAccess> mdir = DirAccess::open(MHlod::mesh_root_dir);
    ERR_FAIL_COND_MSG(mdir.is_null(),"Can not open mesh root dir");
    if(mdir->list_dir_begin() != OK){
        ERR_FAIL_MSG("Can get file list");
    }
    String fname = mdir->get_next();
    while (fname!="")
    {
        int64_t mesh_id = fname.replace(".res","").to_int();
        String fpath = MHlod::mesh_root_dir + fname;
        fname = mdir->get_next();
        ERR_CONTINUE_MSG(mesh_id==0,fpath + " has not valid mesh integer id");
        Ref<MMesh> fmesh = ResourceLoader::get_singleton()->load(fpath);
        ERR_CONTINUE_MSG(fmesh.is_null(),fpath + " is not valid mesh");
        // updating 
        if(mesh_id >= last_mesh_id){
            last_mesh_id = mesh_id + 1;
        }
        mesh_hashes.insert(fmesh,mesh_id);
    }
}

int MAssetTable::mesh_add(Ref<MMesh> mesh){
    ERR_FAIL_COND_V(mesh.is_null(),-1);
    if(mesh_hashes.has(mesh)){
        return mesh_hashes[mesh];
    }
    int mesh_id = last_mesh_id;
    last_mesh_id++;
    String path = MHlod::get_mesh_path(mesh_id);
    mesh_hashes.insert(mesh,mesh_id);
    if(!DirAccess::dir_exists_absolute(MHlod::mesh_root_dir)){
        Error err = DirAccess::make_dir_recursive_absolute(MHlod::mesh_root_dir);
        ERR_FAIL_COND_V_MSG(err!=OK,-1,"Can't create mesh_root_dir "+String(MHlod::mesh_root_dir));
    }
    Error err = ResourceSaver::get_singleton()->save(mesh,path);
    ERR_FAIL_COND_V_MSG(err!=OK,mesh_id,"Can't save "+itos(mesh_id));
    return mesh_id;
}

void MAssetTable::mesh_remove(int id){
    String path = MHlod::get_mesh_path(id);
    if(!ResourceLoader::get_singleton()->exists(path)){
        return;
    }
    Ref<MMesh> mmesh = ResourceLoader::get_singleton()->load(path);
    ERR_FAIL_COND(mmesh.is_null());
    mesh_hashes.erase(mmesh);
    Error err = DirAccess::remove_absolute(path);
    ERR_FAIL_COND_MSG(err!=OK,"Can not remove file "+path+ " with error "+itos(err));
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