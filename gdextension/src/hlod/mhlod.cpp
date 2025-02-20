#include "mhlod.h"

#include <godot_cpp/classes/resource_loader.hpp>
#include "../mtool.h"
#ifdef DEBUG_ENABLED
#include "../editor/masset_table.h"
#include "../editor/mmesh_joiner.h"
#endif


void MHlod::_bind_methods(){

    ClassDB::bind_static_method("MHlod",D_METHOD("get_mesh_root_dir"), &MHlod::get_mesh_root_dir);
    ClassDB::bind_static_method("MHlod",D_METHOD("get_physics_settings_dir"), &MHlod::get_physics_settings_dir);
    ClassDB::bind_static_method("MHlod",D_METHOD("get_physic_setting_path","id"), &MHlod::get_physic_setting_path);
    ClassDB::bind_static_method("MHlod",D_METHOD("get_mesh_path","mesh_id"), &MHlod::get_mesh_path);

    ClassDB::bind_static_method("MHlod",D_METHOD("get_decal_root_dir"), &MHlod::get_decal_root_dir);
    ClassDB::bind_static_method("MHlod",D_METHOD("get_decal_path","id"), &MHlod::get_decal_path);

    ClassDB::bind_static_method("MHlod",D_METHOD("get_packed_scene_root_dir"), &MHlod::get_packed_scene_root_dir);
    ClassDB::bind_static_method("MHlod",D_METHOD("get_packed_scene_path","id"), &MHlod::get_packed_scene_path);

    ClassDB::bind_static_method("MHlod",D_METHOD("get_collision_root_dir"), &MHlod::get_collision_root_dir);
    ClassDB::bind_static_method("MHlod",D_METHOD("get_collsion_path","id"), &MHlod::get_collsion_path);

    ClassDB::bind_static_method("MHlod",D_METHOD("get_hlod_root_dir"), &MHlod::get_hlod_root_dir);
    ClassDB::bind_static_method("MHlod",D_METHOD("get_hlod_path","id"), &MHlod::get_hlod_path);

    ClassDB::bind_method(D_METHOD("get_item_type","item_id"), &MHlod::get_item_type);

    ClassDB::bind_method(D_METHOD("set_aabb","aabb"), &MHlod::set_aabb);
    ClassDB::bind_method(D_METHOD("get_aabb"), &MHlod::get_aabb);
    ADD_PROPERTY(PropertyInfo(Variant::AABB,"aabb",PROPERTY_HINT_NONE,"",PROPERTY_USAGE_STORAGE),"set_aabb","get_aabb");

    ClassDB::bind_method(D_METHOD("get_item_count"), &MHlod::get_item_count);

    ClassDB::bind_method(D_METHOD("set_join_at_lod","input"), &MHlod::set_join_at_lod);
    ClassDB::bind_method(D_METHOD("get_join_at_lod"), &MHlod::get_join_at_lod);
    ADD_PROPERTY(PropertyInfo(Variant::INT,"join_at_lod",PROPERTY_HINT_NONE,"",PROPERTY_USAGE_STORAGE),"set_join_at_lod","get_join_at_lod");

    ClassDB::bind_method(D_METHOD("add_mesh_item","transform","mesh","material","shadow_settings","gi_mode","render_layers","hlod_layers"),&MHlod::add_mesh_item);
    ClassDB::bind_method(D_METHOD("add_sub_hlod","transform","hlod","scene_layers"), &MHlod::add_sub_hlod);
    ClassDB::bind_method(D_METHOD("get_mesh_items_ids"), &MHlod::get_mesh_items_ids);
    ClassDB::bind_method(D_METHOD("get_last_lod_with_mesh"), &MHlod::get_last_lod_with_mesh);
    ClassDB::bind_method(D_METHOD("insert_item_in_lod_table","item_id","lod"), &MHlod::insert_item_in_lod_table);
    ClassDB::bind_method(D_METHOD("get_lod_table"), &MHlod::get_lod_table);

    ClassDB::bind_method(D_METHOD("shape_add_sphere","transform","radius","layers","body_id"), &MHlod::shape_add_sphere);
    ClassDB::bind_method(D_METHOD("shape_add_box","transform","size","layers","body_id"), &MHlod::shape_add_box);
    ClassDB::bind_method(D_METHOD("shape_add_capsule","transform","radius","height","layers","body_id"), &MHlod::shape_add_capsule);
    ClassDB::bind_method(D_METHOD("shape_add_cylinder","transform","radius","height","layers","body_id"), &MHlod::shape_add_cylinder);
    ClassDB::bind_method(D_METHOD("shape_add_complex","id","transform","layers","body_id"), &MHlod::shape_add_complex);

    ClassDB::bind_method(D_METHOD("packed_scene_add","transform","id","arg0","arg0","arg2","layers"), &MHlod::packed_scene_add);
    ClassDB::bind_method(D_METHOD("packed_scene_set_bind_items","packed_scene_item_id","bind0","bind1"), &MHlod::packed_scene_set_bind_items);

    ClassDB::bind_method(D_METHOD("light_add","light_node","transform","layers"), &MHlod::light_add);
    ClassDB::bind_method(D_METHOD("decal_add","decal_id","transform","render_layer","variation_layer"), &MHlod::decal_add);

    ClassDB::bind_method(D_METHOD("_set_data","input"), &MHlod::_set_data);
    ClassDB::bind_method(D_METHOD("_get_data"), &MHlod::_get_data);
    ADD_PROPERTY(PropertyInfo(Variant::DICTIONARY,"_data",PROPERTY_HINT_NONE,""),"_set_data","_get_data");


    ClassDB::bind_method(D_METHOD("set_baker_path","input"), &MHlod::set_baker_path);
    ClassDB::bind_method(D_METHOD("get_baker_path"), &MHlod::get_baker_path);
    ADD_PROPERTY(PropertyInfo(Variant::STRING,"baker_path"),"set_baker_path","get_baker_path");
    #ifdef DEBUG_ENABLED
    ClassDB::bind_method(D_METHOD("get_used_mesh_ids"), &MHlod::get_used_mesh_ids);
    ClassDB::bind_method(D_METHOD("get_joined_mesh","for_triangle_mesh","best_mesh_quality"), &MHlod::get_joined_mesh);
    #endif

    ClassDB::bind_method(D_METHOD("start_test"), &MHlod::start_test);

    BIND_ENUM_CONSTANT(NONE);
    BIND_ENUM_CONSTANT(MESH);
    BIND_ENUM_CONSTANT(COLLISION);
    BIND_ENUM_CONSTANT(COLLISION_COMPLEX);
    BIND_ENUM_CONSTANT(LIGHT);
    BIND_ENUM_CONSTANT(PACKED_SCENE);
    BIND_ENUM_CONSTANT(DECAL);

    BIND_ENUM_CONSTANT(GI_MODE_DISABLED);
    BIND_ENUM_CONSTANT(GI_MODE_STATIC);
    BIND_ENUM_CONSTANT(GI_MODE_DYNAMIC);
    BIND_ENUM_CONSTANT(GI_MODE_STATIC_DYNAMIC);
}

String MHlod::get_asset_root_dir(){
    return String(M_ASSET_ROOT_DIR);
}

String MHlod::get_mesh_root_dir(){
    return String(M_MESH_ROOT_DIR);
}

String MHlod::get_physics_settings_dir(){
    return String(M_PHYSICS_SETTINGS_DIR);
}

String MHlod::get_physic_setting_path(int id){
    return M_GET_PHYSIC_SETTING_PATH(id);
}

String MHlod::get_mesh_path(int64_t mesh_id){
    return M_GET_MESH_PATH(mesh_id);
}

String MHlod::get_packed_scene_root_dir(){
    return M_PACKEDSCENE_ROOT_DIR;
}

String MHlod::get_packed_scene_path(int id){
    return M_GET_PACKEDSCENE_PATH(id);
}

String MHlod::get_decal_root_dir(){
    return M_DECAL_ROOT_DIR;
}

String MHlod::get_decal_path(int id){
    return M_GET_DECAL_PATH(id);
}

String MHlod::get_collision_root_dir(){
    return M_COLLISION_ROOT_DIR;
}

String MHlod::get_collsion_path(int id){
    return M_GET_COLLISION_PATH(id);
}

String MHlod::get_hlod_root_dir(){
    return M_HLOD_ROOT_DIR;
}

String MHlod::get_hlod_path(int id){
    return M_GET_HLODL_PATH(id);
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
    case Type::COLLISION_COMPLEX:
        new (&collision_complex) MHLodItemCollisionComplex();
        break;
    case Type::PACKED_SCENE:
        new (&packed_scene) MHLodItemPackedScene();
        break;
    case Type::LIGHT:
        new (&light) MHLodItemLight();
        break;
    case Type::DECAL:
        new (&decal) MHLodItemDecal();
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
    case Type::COLLISION_COMPLEX:
        collision_complex = other.collision_complex;
        break;
    case Type::PACKED_SCENE:
        packed_scene = other.packed_scene;
        break;
    case Type::LIGHT:
        light = other.light;
        break;
    case Type::DECAL:
        decal = other.decal;
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
    case Type::COLLISION_COMPLEX:
        collision_complex.~MHLodItemCollisionComplex();
        break;
    case Type::PACKED_SCENE:
        packed_scene.~MHLodItemPackedScene();
        break;
    case Type::LIGHT:
        light.~MHLodItemLight();
    case Type::DECAL:
        decal.~MHLodItemDecal();
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

void MHlod::Item::set_header_data(const PackedByteArray& data){
    ERR_FAIL_COND(data.size() < ITEM_DATA_MAX);
    type = (Type)data.decode_u8(ITEM_DATA_TYPE);
    ERR_FAIL_COND(type>=(uint8_t)Type::TYPE_MAX);
    is_bound = (bool)data.decode_u8(ITEM_DATA_IS_BOUND);
    lod = data.decode_s8(ITEM_DATA_LOD);
    item_layers = data.decode_u16(ITEM_DATA_LAYER);
    transform_index = data.decode_s32(ITEM_DATA_TRANSFORM_INDEX);
}

PackedByteArray MHlod::Item::get_header_data() const {
    PackedByteArray out;
    out.resize(ITEM_DATA_MAX);
    out.encode_u8(ITEM_DATA_TYPE,type);
    out.encode_u8(ITEM_DATA_IS_BOUND,is_bound);
    out.encode_s8(ITEM_DATA_LOD,lod);
    out.encode_u16(ITEM_DATA_LAYER,item_layers);
    out.encode_s32(ITEM_DATA_TRANSFORM_INDEX,transform_index);
    return out;
}

void MHlod::Item::set_data(const PackedByteArray& data){
    set_header_data(data);
    int head = ITEM_DATA_MAX;
    switch (type)
    {
    case Type::MESH:
        new (&mesh) MHLodItemMesh();
        mesh.set_data(data,head);
        break;
    case Type::COLLISION:
        new (&collision) MHLodItemCollision();
        collision.set_data(data,head);
        break;
    case Type::COLLISION_COMPLEX:
        new (&collision_complex) MHLodItemCollision();
        collision_complex.set_data(data,head);
        break;
    case Type::PACKED_SCENE:
        new (&packed_scene) MHLodItemPackedScene();
        packed_scene.set_data(data,head);
        break;
    case Type::LIGHT:
        new (&light) MHLodItemLight();
        light.set_data(data,head);
        break;
    case Type::DECAL:
        new (&decal) MHLodItemDecal();
        decal.set_data(data,head);
        break;
    default:
        ERR_FAIL_MSG("Undefine Item Type!"); 
        break;
    }
}

PackedByteArray MHlod::Item::get_data() const{
    PackedByteArray data = get_header_data();
    switch (type)
    {
    case Type::MESH:
        data.append_array(mesh.get_data());
        break;
    case Type::COLLISION:
        data.append_array(collision.get_data());
        break;
    case Type::COLLISION_COMPLEX:
        data.append_array(collision_complex.get_data());
        break;
    case Type::PACKED_SCENE:
        data.append_array(packed_scene.get_data());
        break;
    case Type::LIGHT:
        data.append_array(light.get_data());
        break;
    case Type::DECAL:
        data.append_array(decal.get_data());
        break;
    default:
        ERR_FAIL_V_MSG(PackedByteArray(),"Undefine Item Type!"); 
        break;
    }
    return data;
}

////////////////////////
//////////////////////////////////////////////
///////////////////////

bool MHlod::_is_data_healthy() const {
    for(const Item& item : item_list){
        ERR_FAIL_INDEX_V(item.transform_index,transforms.size(),false);
        ERR_FAIL_COND_V(item.type==NONE||item.type==TYPE_MAX,false);
    }
    ERR_FAIL_COND_V(sub_hlods.size()!=sub_hlods_transforms.size(),false);
    ERR_FAIL_COND_V(sub_hlods.size()!=sub_hlods_scene_layers.size(),false);
    for(const VSet<int32_t>& table_row : lods){
        for(int c=0; c < table_row.size(); c++){
            ERR_FAIL_INDEX_V(table_row[c],item_list.size(),false);
        }
    }
    return true;
}

bool MHlod::is_hlod_healthy() const {
    // or data is healthy or is empty
    return is_data_healthy || (item_list.is_empty() && sub_hlods.is_empty());
}

MHlod::Type MHlod::get_item_type(int32_t item_id) const{
    ERR_FAIL_INDEX_V(item_id,item_list.size(),Type::NONE);
    return item_list[item_id].type;
}

void MHlod::set_aabb(const AABB& _aabb){
    aabb = _aabb;
}

const AABB& MHlod::get_aabb() const{
    return aabb;
}

int MHlod::get_item_count() const{
    return item_list.size();
}

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

int MHlod::add_mesh_item(const Transform3D& transform,const PackedInt32Array& mesh,const PackedInt32Array& material,const PackedByteArray& shadow_settings,const PackedByteArray& gi_modes,int32_t render_layers,int32_t hlod_layers){
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
        if(mesh[i]==-1){
            continue;
        }
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
    ERR_FAIL_COND_V_MSG(item_index==item_list.size(),-1,"No mesh item has been added! Empty mesh array!");
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

void MHlod::get_last_valid_item_ids(Type type,PackedInt32Array& ids){
    ERR_FAIL_COND(ids.size()!=0);
    for(int i=lods.size()-1; i >=0 ; i--){
        for(int j=0; j < lods[i].size(); j++){
            int32_t iid = lods[i][j];
            if(item_list[iid].type==type){
                ids.push_back(iid);
            }
        }
        if(ids.size()!=0){ // found something
            break;
        }
    }
}

int32_t MHlod::get_mesh_id(int32_t item_id,bool current_lod,bool lowest_lod) const {
    ERR_FAIL_INDEX_V(item_id,item_list.size(),-1);
    ERR_FAIL_COND_V(item_list[item_id].type!=MESH,-1);
    int32_t current_mesh_id = item_list[item_id].mesh.mesh_id;
    if(current_lod){
        return current_mesh_id;
    }
    int32_t transform_index = item_list[item_id].transform_index;
    int32_t last_valid_item_id = item_id;
    int msign = current_mesh_id < 0 ? -1 : 1;
    while (true)
    {
        if(lowest_lod){
            item_id -= msign;
        } else {
            item_id += msign;
        }
        if(item_id<0 || item_id >= item_list.size()){
            break;
        }
        if(item_list[item_id].transform_index == transform_index){
            last_valid_item_id = item_id;
        } else {
            break;
        }
    }
    ERR_FAIL_COND_V(item_list[last_valid_item_id].type!=MESH,-1);
    return item_list[last_valid_item_id].mesh.mesh_id;
}

int MHlod::shape_add_sphere(const Transform3D& _transform,float radius,uint16_t layers,int body_id){
    ERR_FAIL_COND_V_MSG(body_id>std::numeric_limits<int16_t>::max(),-1,"Body Id can be bigger than "+std::numeric_limits<int16_t>::max());
    MHLodItemCollision mcol(MHLodItemCollision::Type::SHPERE);
    mcol.set_param(radius);
    mcol.set_body_id(body_id);
    Item _item(MHlod::Type::COLLISION);
    _item.collision = mcol;
    transforms.push_back(_transform);
    _item.transform_index = transforms.size() - 1;
    _item.item_layers = layers;
    item_list.push_back(_item);
    return item_list.size() - 1;
}
int MHlod::shape_add_box(const Transform3D& _transform,const Vector3& size,uint16_t layers,int body_id){
    ERR_FAIL_COND_V_MSG(body_id>std::numeric_limits<int16_t>::max(),-1,"Body Id can be bigger than "+std::numeric_limits<int16_t>::max());
    MHLodItemCollision mcol(MHLodItemCollision::Type::BOX);
    mcol.set_param(size.x/2,size.y/2,size.z/2);
    mcol.set_body_id(body_id);
    Item _item(MHlod::Type::COLLISION);
    _item.collision = mcol;
    transforms.push_back(_transform);
    _item.transform_index = transforms.size() - 1;
    _item.item_layers = layers;
    item_list.push_back(_item);
    return item_list.size() - 1;
}

int MHlod::shape_add_capsule(const Transform3D& _transform,float radius,float height,uint16_t layers,int body_id){
    ERR_FAIL_COND_V_MSG(body_id>std::numeric_limits<int16_t>::max(),-1,"Body Id can be bigger than "+std::numeric_limits<int16_t>::max());
    MHLodItemCollision mcol(MHLodItemCollision::Type::CAPSULE);
    mcol.set_param(radius,height);
    mcol.set_body_id(body_id);
    Item _item(MHlod::Type::COLLISION);
    _item.collision = mcol;
    transforms.push_back(_transform);
    _item.transform_index = transforms.size() - 1;
    _item.item_layers = layers;
    item_list.push_back(_item);
    return item_list.size() - 1;
}

int MHlod::shape_add_cylinder(const Transform3D& _transform,float radius,float height,uint16_t layers,int body_id){
    ERR_FAIL_COND_V_MSG(body_id>std::numeric_limits<int16_t>::max(),-1,"Body Id can be bigger than "+std::numeric_limits<int16_t>::max());
    MHLodItemCollision mcol(MHLodItemCollision::Type::CYLINDER);
    mcol.set_param(radius,height);
    mcol.set_body_id(body_id);
    Item _item(MHlod::Type::COLLISION);
    _item.collision = mcol;
    transforms.push_back(_transform);
    _item.transform_index = transforms.size() - 1;
    _item.item_layers = layers;
    item_list.push_back(_item);
    return item_list.size() - 1;
}

int MHlod::shape_add_complex(const int32_t id,const Transform3D& _transform,uint16_t layers,int body_id){
    ERR_FAIL_COND_V_MSG(body_id>std::numeric_limits<int16_t>::max(),-1,"Body Id can be bigger than "+std::numeric_limits<int16_t>::max());
    MHLodItemCollisionComplex mcol;
    mcol.id = id;
    mcol.static_body = body_id;
    Item _item(MHlod::Type::COLLISION_COMPLEX);
    _item.collision_complex = mcol;
    transforms.push_back(_transform);
    _item.transform_index = transforms.size() - 1;
    _item.item_layers = layers;
    item_list.push_back(_item);
    return item_list.size() - 1;
}

int MHlod::packed_scene_add(const Transform3D& _transform,int32_t id,int32_t arg0,int32_t arg1,int32_t arg2,uint16_t layers){
    MHLodItemPackedScene item_packed_scene;
    item_packed_scene.id = id;
    item_packed_scene.args[0] = arg0;
    item_packed_scene.args[1] = arg1;
    item_packed_scene.args[2] = arg2;
    Item _item(MHlod::Type::PACKED_SCENE);
    _item.packed_scene = item_packed_scene;
    transforms.push_back(_transform);
    _item.transform_index = transforms.size() - 1;
    _item.item_layers = layers;
    item_list.push_back(_item);
    return item_list.size() - 1;
}

void MHlod::packed_scene_set_bind_items(int32_t packed_scene_item_id,int32_t bind0,int32_t bind1){
    ERR_FAIL_INDEX(packed_scene_item_id,item_list.size());
    if(bind0>=0) ERR_FAIL_INDEX(bind0,item_list.size());
    if(bind1>=0) ERR_FAIL_INDEX(bind1,item_list.size());
    if(bind0>=0) item_list.ptrw()[bind0].is_bound = true;
    if(bind1>=0) item_list.ptrw()[bind1].is_bound = true;
    ERR_FAIL_COND(item_list[packed_scene_item_id].type!=MHlod::Type::PACKED_SCENE);
    item_list.ptrw()[packed_scene_item_id].packed_scene.bind_items[0] = bind0;
    item_list.ptrw()[packed_scene_item_id].packed_scene.bind_items[1] = bind1;
}

int MHlod::light_add(Object* light_node,const Transform3D transform,uint16_t layers){
    String cn = light_node->get_class();
    ERR_FAIL_COND_V(cn!=String("OmniLight3D")&&cn!=String("SpotLight3D"),-1);
    MHLodItemLight light_item;
    // booleans
    light_item.distance_fade_enabled = (int)light_node->get("distance_fade_enabled");
    light_item.shadow_enabled = (int)light_node->get("shadow_enabled");
    light_item.shadow_reverse_cull_face = (int)light_node->get("shadow_reverse_cull_face");
    light_item.negetive = (int)light_node->get("light_negative");
    // color
    Color col = light_node->get("light_color");
    light_item.red = col.r;
    light_item.green = col.g;
    light_item.blue = col.b;
    // param
    light_item.energy = light_node->get("light_energy");
    light_item.light_indirect_energy = light_node->get("light_indirect_energy");
    light_item.light_volumetric_fog_energy = light_node->get("light_volumetric_fog_energy");
    light_item.size = light_node->get("light_size");
    light_item.specular = light_node->get("light_specular");
    // shadow param
    light_item.shadow_bias = light_node->get("shadow_bias");
    light_item.shadow_normal_bias = light_node->get("shadow_normal_bias");
    light_item.shadow_opacity = light_node->get("shadow_opacity");
    light_item.shadow_blur = light_node->get("shadow_blur");
    // distance fade
    light_item.distance_fade_begin = light_node->get("distance_fade_begin");
    light_item.distance_fade_shadow = light_node->get("distance_fade_shadow");
    light_item.distance_fade_length = light_node->get("distance_fade_length");
    // cull mask
    light_item.cull_mask = ((int64_t)light_node->get("light_cull_mask"));
    if(cn==String("OmniLight3D")){
        light_item.type = MHLodItemLight::Type::OMNI;
        light_item.range = light_node->get("omni_range");
        light_item.attenuation = light_node->get("omni_attenuation");
        light_item.shadow_mode = (int)light_node->get("omni_shadow_mode");
    } else if(cn==String("SpotLight3D")) {
        light_item.type = MHLodItemLight::Type::SPOT;
        light_item.range = light_node->get("spot_range");
        light_item.attenuation = light_node->get("spot_attenuation");
        light_item.spot_angle = light_node->get("spot_angle");
        light_item.spot_attenuation = light_node->get("spot_angle_attenuation");
    }
    Item item(MHlod::Type::LIGHT);
    item.light = light_item;
    item.transform_index = transforms.size();
    item.item_layers = layers;
    transforms.push_back(transform);
    item_list.push_back(item);
    return item_list.size() - 1;
}

int MHlod::decal_add(int32_t decal_id,const Transform3D transform,int32_t render_layer,uint16_t variation_layer){
    MHLodItemDecal decal_item;
    decal_item.set_data(decal_id,render_layer);
    Item item(Type::DECAL);
    item.decal = decal_item;
    item.item_layers = variation_layer;
    item.transform_index = transforms.size();
    transforms.push_back(transform);
    item_list.push_back(item);
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

Ref<ArrayMesh> MHlod::get_joined_mesh(bool for_triangle_mesh,bool best_mesh_quality) const{
    Ref<ArrayMesh> out;
    Vector<Pair<Ref<MHlod>,Transform3D>> stack;
    stack.push_back({Ref<MHlod>(this),Transform3D()}); // is local so start from Transform3D()
    Array meshes;
    Array transforms;
    PackedInt32Array materials;
    while (stack.size()!=0)
    {
        Ref<MHlod> current_hlod = stack[stack.size()-1].first;
        Transform3D current_transform = stack[stack.size()-1].second;
        stack.remove_at(stack.size()-1);
        ERR_CONTINUE(current_hlod.is_null());
        PackedInt32Array item_ids;
        current_hlod->get_last_valid_item_ids(MHlod::MESH,item_ids);
        bool is_join_mesh=false;
        for(const int32_t item_id : item_ids){
            int mesh_id = current_hlod->get_mesh_id(item_id,false,best_mesh_quality);
            ERR_CONTINUE_MSG(mesh_id ==-1,vformat("Mesh id %d is not valid in item id %d in hlod %s",mesh_id,item_id,current_hlod->get_path()));
            if(mesh_id <= -10){
                is_join_mesh = true;
            }
            Transform3D item_transform = current_transform * current_hlod->transforms[current_hlod->item_list[item_id].transform_index];
            Ref<MMesh> mmesh = RL->load(MHlod::get_mesh_path(mesh_id));
            if(mmesh.is_valid()){
                meshes.push_back(mmesh);
                transforms.push_back(item_transform);
                if(!for_triangle_mesh){
                    int32_t mat_set = current_hlod->item_list[item_id].mesh.material_id;
                    // item id can be different than mesh id as we used get_mesh_id with lowest_lod=false
                    // different lod use same materal set
                    // if some lod does not have the set we use the material_set=0
                    // according the rule above we apply our method
                    mat_set = mat_set < mmesh->material_set_get_count() && mat_set>=0 ? mat_set : 0;
                    materials.push_back(mat_set);
                }
            }
        }
        // Sub Hlod
        if(is_join_mesh){ // the we cover inner layer
            continue;
        }
        for(int h=0; h < current_hlod->sub_hlods.size(); h++){
            Ref<MHlod> sub = current_hlod->sub_hlods[h];
            Transform3D sub_t = current_transform * current_hlod->sub_hlods_transforms[h];
            stack.push_back({sub,sub_t});
        }
    }
    // Finish gathering meshes
    if(!for_triangle_mesh){
        Ref<MMeshJoiner> mesh_joiner;
        mesh_joiner.instantiate();
        mesh_joiner->insert_mmesh_data(meshes,transforms,materials);
        out = mesh_joiner->join_meshes();
        return out;
    }
    // No for triangle mesh
    PackedVector3Array verticies;
    PackedInt32Array indices;
    for(int i=0; i < meshes.size(); i++){
        Ref<MMesh> mmesh = meshes[i];
        Transform3D t = transforms[i];
        for(int s=0; s < mmesh->get_surface_count(); s++){
            Array sinfo = mmesh->surface_get_arrays(s);
            int32_t index_offset = verticies.size();
            PackedVector3Array svert = sinfo[Mesh::ARRAY_VERTEX];
            PackedInt32Array sind = sinfo[Mesh::ARRAY_INDEX];
            for(const Vector3& v : svert){
                verticies.push_back(t.xform(v));
            }
            for(const int32_t index : sind){
                indices.push_back(index + index_offset);
            }
        }
    }
    Array sinfo;
    sinfo.resize(Mesh::ARRAY_MAX);
    sinfo[Mesh::ARRAY_VERTEX] = verticies;
    sinfo[Mesh::ARRAY_INDEX] = indices;
    out.instantiate();
    out->add_surface_from_arrays(Mesh::PRIMITIVE_TRIANGLES,sinfo);
    return out;
}
#endif

void MHlod::_set_data(const Array& data){
    ERR_FAIL_COND(data.size()!=ARRAY_DATA_MAX);
    item_list.clear();
    lods.clear();
    transforms.clear();
    sub_hlods.clear();
    sub_hlods_transforms.clear();
    Array __lods = data[ARRAY_DATA_LODS];
    for(int i=0; i < __lods.size();i++){
        PackedInt32Array __lod = __lods[i];
        VSet<int32_t> __l;
        for(int j=0; j < __lod.size(); j++){
            __l.insert(__lod[j]);
        }
        lods.push_back(__l);
    }
    /// Items
    Array __items = data[ARRAY_DATA_ITEM];
    item_list.resize(__items.size());
    for(int i=0; i < __items.size(); i++){
        item_list.ptrw()[i].set_data(__items[i]);
    }
    Array __transforms = data[ARRAY_DATA_TRANSFORMS];
    transforms.resize(__transforms.size());
    for(int i=0; i < __transforms.size(); i++){
        transforms.set(i,__transforms[i]);
    }
    Array __subhlods = data[ARRAY_DATA_SUBHLOD];
    Vector<Transform3D> __subhlods_transforms_tmp = MTool::packed_byte_array_to_vector<Transform3D>(data[ARRAY_DATA_SUBHLOD_TRANSFORM]);
    Vector<uint16_t> __sub_hlod_scene_layers_tmp = MTool::packed_byte_array_to_vector<uint16_t>(data[ARRAY_DATA_SUBHLOD_SCENE_LAYER]);
    ERR_FAIL_COND(__subhlods.size()!=__subhlods_transforms_tmp.size());
    ERR_FAIL_COND(__subhlods.size()!=__sub_hlod_scene_layers_tmp.size());
    for(int i=0; i < __subhlods.size(); i++){
        Ref<MHlod> __shlod = __subhlods[i];
        ERR_CONTINUE_MSG(__shlod.is_null(),"Null sub hlod");
        sub_hlods.push_back(__shlod);
        sub_hlods_transforms.push_back(__subhlods_transforms_tmp[i]);
        sub_hlods_scene_layers.push_back(__sub_hlod_scene_layers_tmp[i]);
    }
    // Check health
    is_data_healthy = _is_data_healthy();
}

Array MHlod::_get_data() const{
    Array out;
    out.resize(ARRAY_DATA_MAX);
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
    out[ARRAY_DATA_LODS] = __lods;
    /// Items
    Array __items;
    __items.resize(item_list.size());
    for(int i=0; i < item_list.size(); i++){
        __items[i] = item_list[i].get_data();
    }
    out[ARRAY_DATA_ITEM] = __items;
    Array __transforms;
    __transforms.resize(transforms.size());
    for(int i=0; i < transforms.size(); i++){
        __transforms[i] = transforms[i];
    }
    out[ARRAY_DATA_TRANSFORMS] = __transforms;
    Array __subhlods;
    __subhlods.resize(sub_hlods.size());
    for(int i=0; i < sub_hlods.size(); i++){
        __subhlods[i] = sub_hlods[i];
    }
    out[ARRAY_DATA_SUBHLOD] = __subhlods;
    out[ARRAY_DATA_SUBHLOD_TRANSFORM] = MTool::vector_to_packed_byte_array<Transform3D>(sub_hlods_transforms);
    out[ARRAY_DATA_SUBHLOD_SCENE_LAYER] = MTool::vector_to_packed_byte_array<uint16_t>(sub_hlods_scene_layers);
    return out;
}