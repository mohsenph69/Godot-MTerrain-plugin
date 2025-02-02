#include "mhlod_node3d.h"
#include <mutex>


void MHlodNode3D::_bind_methods(){
    ClassDB::bind_method(D_METHOD("_notify_update_lod","lod"), &MHlodNode3D::_notify_update_lod);
    ClassDB::bind_method(D_METHOD("get_current_lod"), &MHlodNode3D::get_current_lod);
    ClassDB::bind_method(D_METHOD("get_arg","idx"), &MHlodNode3D::get_arg);
    ClassDB::bind_method(D_METHOD("get_global_id"), &MHlodNode3D::get_global_id);
    ClassDB::bind_method(D_METHOD("get_permanent_id"), &MHlodNode3D::get_permanent_id);
    // bind items
    ClassDB::bind_method(D_METHOD("bind_item_get_global_id","idx"), &MHlodNode3D::bind_item_get_global_id);
    ClassDB::bind_method(D_METHOD("bind_item_get_transform","idx"), &MHlodNode3D::bind_item_get_transform);
    ClassDB::bind_method(D_METHOD("bind_item_set_transform","idx","new_transform"), &MHlodNode3D::bind_item_set_transform);
    ClassDB::bind_method(D_METHOD("bind_item_get_disabled","idx"), &MHlodNode3D::bind_item_get_disabled);
    ClassDB::bind_method(D_METHOD("bind_item_set_disabled","idx","disabled"), &MHlodNode3D::bind_item_set_disabled);

    ClassDB::bind_method(D_METHOD("_set_args","input"), &MHlodNode3D::_set_args);
    ClassDB::bind_method(D_METHOD("_get_args"), &MHlodNode3D::_get_args);
    ADD_PROPERTY(PropertyInfo(Variant::PACKED_INT32_ARRAY,"_args",PROPERTY_HINT_NONE,"",PROPERTY_USAGE_STORAGE),"_set_args","_get_args");

    GDVIRTUAL_BIND(_update_lod,"lod");
}

MHlodNode3D::MHlodNode3D(){

}

MHlodNode3D::~MHlodNode3D(){
    std::lock_guard<std::mutex> lock(MHlodScene::packed_scene_mutex);
    if(proc!=nullptr){
        for(int i=0; i < M_PACKED_SCENE_BIND_COUNT; i++){
            if(bind_items[i].is_valid()){
                proc->bind_item_clear(bind_items[i]);
            }
        }
        MHlodScene::removed_packed_scenes.insert(this);
    }
}
// only called by MHlodScene
void MHlodNode3D::_notify_update_lod(int _lod){
    lod = _lod;
    GDVIRTUAL_CALL(_update_lod,lod);
}

int MHlodNode3D::get_current_lod() const{
    return lod;
}
int32_t MHlodNode3D::get_arg(int idx) const{
    ERR_FAIL_INDEX_V_MSG(idx,M_PACKED_SCENE_ARG_COUNT,0,"MHlodNode3D arg idx shoud be between 0 and "+itos(M_PACKED_SCENE_ARG_COUNT));
    return args[idx];
}
int64_t MHlodNode3D::get_global_id() const{
    return global_id.id;
}
int64_t MHlodNode3D::get_permanent_id() const{
    return permanent_id.id;
}

// Bid Items
int64_t MHlodNode3D::bind_item_get_global_id(int idx) const{
    ERR_FAIL_INDEX_V_MSG(idx,M_PACKED_SCENE_BIND_COUNT,0,"MHlodNode3D bind idx shoud be between 0 and "+itos(M_PACKED_SCENE_BIND_COUNT));
    return bind_items[idx].id;
}

Transform3D MHlodNode3D::bind_item_get_transform(int idx) const{
    ERR_FAIL_INDEX_V(idx,M_PACKED_SCENE_BIND_COUNT,Transform3D());
    ERR_FAIL_COND_V(!bind_items[idx].is_valid(),Transform3D());
    return proc->get_item_transform(bind_items[idx].transform_index);
}

void MHlodNode3D::bind_item_set_transform(int idx, const Transform3D& transform){
    ERR_FAIL_INDEX(idx,M_PACKED_SCENE_BIND_COUNT);
    ERR_FAIL_COND(!bind_items[idx].is_valid());
    std::lock_guard<std::mutex> lock(MHlodScene::packed_scene_mutex);
    if(proc!=nullptr){
        proc->bind_item_modify_transform(bind_items[idx],transform);
    }
}

bool MHlodNode3D::bind_item_get_disabled(int idx) const {
    ERR_FAIL_INDEX_V(idx,M_PACKED_SCENE_BIND_COUNT,true);
    ERR_FAIL_COND_V(!bind_items[idx].is_valid(),true);
    std::lock_guard<std::mutex> lock(MHlodScene::packed_scene_mutex);
    if(proc==nullptr){
        return true;
    }
    return proc->bind_item_get_disable(bind_items[idx]);
}

void MHlodNode3D::bind_item_set_disabled(int idx,bool disabled){
    ERR_FAIL_INDEX(idx,M_PACKED_SCENE_BIND_COUNT);
    ERR_FAIL_COND(!bind_items[idx].is_valid());
    std::lock_guard<std::mutex> lock(MHlodScene::packed_scene_mutex);
    if(proc!=nullptr){
        proc->bind_item_set_disable(bind_items[idx],disabled);
    }
}

void MHlodNode3D::_set_args(const PackedInt32Array& input){
    if(is_inside_hlod_scene){
        return;
    }
    ERR_FAIL_COND(input.size()!=M_PACKED_SCENE_ARG_COUNT);
    for(int i=0; i < M_PACKED_SCENE_ARG_COUNT; i++){
        args[i] = input[i];
    }
}

PackedInt32Array MHlodNode3D::MHlodNode3D::_get_args(){
    PackedInt32Array out;
    out.resize(M_PACKED_SCENE_ARG_COUNT);
    for(int i=0; i < M_PACKED_SCENE_ARG_COUNT; i++){
        out[i] = args[i];
    }
    return out;
}

void MHlodNode3D::_notification(int32_t what){

}

void MHlodNode3D::_get_property_list(List<PropertyInfo> *p_list) const{
    if(is_inside_hlod_scene){
        return;
    }
    for(int i=0; i < M_PACKED_SCENE_ARG_COUNT; i++){
        String pn = String("HLOD_Aurgements/arg_") + itos(i);
        p_list->push_back(PropertyInfo(Variant::INT,pn,PROPERTY_HINT_NONE,"",PROPERTY_USAGE_EDITOR));
    }
    for(int i=0; i < M_PACKED_SCENE_BIND_COUNT; i++){
        String pn = String("Bind_Items/item_") + itos(i);
        p_list->push_back(PropertyInfo(Variant::STRING,pn,PROPERTY_HINT_NONE,"",PROPERTY_USAGE_EDITOR));
        pn = String("Bind_Items/item_hint_") + itos(i);
        p_list->push_back(PropertyInfo(Variant::INT,pn,PROPERTY_HINT_ENUM,MHlod::type_string,PROPERTY_USAGE_EDITOR));
    }
}

bool MHlodNode3D::_get(const StringName &p_name, Variant &r_ret) const{
    if(is_inside_hlod_scene){
        return false;
    }
    if(p_name.begins_with("HLOD_Aurgements/arg_")){
        int idx = p_name.to_int();
        ERR_FAIL_INDEX_V(idx,M_PACKED_SCENE_ARG_COUNT,false);
        r_ret = args[idx];
        return true;
    }
    if(p_name.begins_with("Bind_Items/item_hint_")){
        int idx = p_name.to_int();
        ERR_FAIL_INDEX_V(idx,M_PACKED_SCENE_BIND_COUNT,false);
        String g = "bind_item_hint_"+itos(idx);
        if(has_meta(g)){
            r_ret = get_meta(g);
        } else {
            r_ret = (int)MHlod::Type::NONE;
        }
        return true;
    }
    if(p_name.begins_with("Bind_Items/item_")){
        int idx = p_name.to_int();
        ERR_FAIL_INDEX_V(idx,M_PACKED_SCENE_BIND_COUNT,false);
        String g = "bind_item_"+itos(idx);
        if(has_meta(g)){
            r_ret = get_meta(g);
        } else {
            r_ret = String();
        }
        return true;
    }
    return false;
}

bool MHlodNode3D::_set(const StringName &p_name, const Variant &p_value){
    if(is_inside_hlod_scene){
        return false;
    }
    if(p_name.begins_with("HLOD_Aurgements/arg_")){
        int idx = p_name.to_int();
        ERR_FAIL_INDEX_V(idx,M_PACKED_SCENE_ARG_COUNT,false);
        args[idx] = p_value;
        return true;
    }
    if(p_name.begins_with("Bind_Items/item_hint_")){
        int idx = p_name.to_int();
        ERR_FAIL_INDEX_V(idx,M_PACKED_SCENE_BIND_COUNT,false);
        String g = "bind_item_hint_"+itos(idx);
        set_meta(g,p_value);
        return true;
    }
    if(p_name.begins_with("Bind_Items/item_")){
        int idx = p_name.to_int();
        ERR_FAIL_INDEX_V(idx,M_PACKED_SCENE_BIND_COUNT,false);
        String g = "bind_item_"+itos(idx);
        set_meta(g,p_value);
        return true;
    }
    return false;
}