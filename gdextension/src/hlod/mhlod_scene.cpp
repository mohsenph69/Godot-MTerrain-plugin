#include "mhlod_scene.h"

#include <godot_cpp/templates/hash_set.hpp>
#include <godot_cpp/classes/world3d.hpp>
#include <godot_cpp/classes/rendering_server.hpp>

#include "mhlod_node3d.h"

#define RS RenderingServer::get_singleton()



void MHlodScene::_bind_methods(){
    ClassDB::bind_method(D_METHOD("set_hlod","input"), &MHlodScene::set_hlod);
    ClassDB::bind_method(D_METHOD("get_hlod"), &MHlodScene::get_hlod);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT,"hlod",PROPERTY_HINT_RESOURCE_TYPE,"MHlod"),"set_hlod","get_hlod");

    ClassDB::bind_method(D_METHOD("set_scene_layers","input"), &MHlodScene::set_scene_layers);
    ClassDB::bind_method(D_METHOD("get_scene_layers"), &MHlodScene::get_scene_layers);
    ADD_PROPERTY(PropertyInfo(Variant::INT,"scene_layers"),"set_scene_layers","get_scene_layers");

    ClassDB::bind_method(D_METHOD("_update_visibility"), &MHlodScene::_update_visibility);
    ClassDB::bind_method(D_METHOD("get_last_lod_mesh_ids_transforms"), &MHlodScene::get_last_lod_mesh_ids_transforms);
    ClassDB::bind_method(D_METHOD("get_triangle_meshes"), &MHlodScene::get_triangle_meshes);

    ClassDB::bind_static_method("MHlodScene",D_METHOD("sleep"), &MHlodScene::sleep);
    ClassDB::bind_static_method("MHlodScene",D_METHOD("awake"), &MHlodScene::awake);
    ClassDB::bind_static_method("MHlodScene",D_METHOD("get_hlod_users","hlod_path"), &MHlodScene::get_hlod_users);

    ClassDB::bind_static_method("MHlodScene",D_METHOD("get_debug_info"), &MHlodScene::get_debug_info);
}

MHlodScene::ApplyInfo::ApplyInfo(MHlod::Type _type,bool _remove): type(_type) , remove(_remove)
{
}

void MHlodScene::ApplyInfo::set_instance(const RID input){
    instance = input.get_id();
}

RID MHlodScene::ApplyInfo::get_instance() const{
    RID out;
    memcpy(&out,&instance,sizeof(RID));
    return out;
}

MHlodScene::Proc::Proc(MHlodScene* _scene,Ref<MHlod> _hlod,int32_t _proc_id,int32_t _scene_layers,const Transform3D& _transform):
hlod(_hlod),scene(_scene),proc_id(_proc_id),scene_layers(scene_layers),transform(_transform)
{

}

MHlodScene::Proc::~Proc(){
    disable();
}

void MHlodScene::Proc::init_sub_proc(int32_t _sub_proc_index,uint64_t _sub_proc_size,int32_t _proc_id){
    sub_proc_index = _sub_proc_index;
    sub_procs_size = _sub_proc_size;
    proc_id = _proc_id;
}

void MHlodScene::Proc::change_transform(const Transform3D& new_transform){
    is_transform_changed = true;
    if(MHlodScene::octree!=nullptr && oct_point_id!=-1 && is_octree_inserted){
        MOctree::PointMoveReq mv_req(oct_point_id,MHlodScene::oct_id,transform.origin,new_transform.origin);
        MHlodScene::octree->add_move_req(mv_req);
    }
    transform = new_transform;
    update_all_transform();
    for(int i=0; i < sub_procs_size; i++){
        get_subprocs_ptrw()[i].change_transform(new_transform*hlod->sub_hlods_transforms[i]);
    }
}

void MHlodScene::Proc::enable(const bool recursive){
    if(is_enable){
        return;
    }
    is_enable = true;
    is_sub_proc_enable = true;
    oct_point_id = MHlodScene::add_proc(this,oct_point_id);
    if(recursive){
        for(int i=0; i < sub_procs_size; i++){
            get_subprocs_ptrw()[i].enable();
        }
    }
}

void MHlodScene::Proc::disable(const bool recursive,const bool immediate,const bool is_destruction){
    if(!is_enable){
        return;
    }
    is_enable = false;
    is_sub_proc_enable = false;
    remove_all_items(immediate,is_destruction);
    MHlodScene::remove_proc(oct_point_id);
    if(recursive){
        for(int i=0; i < sub_procs_size; i++){
            get_subprocs_ptrw()[i].disable(recursive,immediate,is_destruction);
        }
    }
}

void MHlodScene::Proc::enable_sub_proc(){
    if(is_sub_proc_enable){
        return;
    }
    is_sub_proc_enable = true;
    for(int i=0; i < sub_procs_size; i++){
        get_subprocs_ptrw()[i].enable();
    }
}

void MHlodScene::Proc::disable_sub_proc(){
    if(!is_sub_proc_enable){
        return;
    }
    is_sub_proc_enable = false;
    for(int i=0; i < sub_procs_size; i++){
        get_subprocs_ptrw()[i].disable();
    }
}

void MHlodScene::Proc::add_item(MHlod::Item* item,const int item_id,const bool immediate){
    MHlod::ItemResource item_res = item->get_res_and_add_user(); // must be called here, this will load if it is not loaded
    GlobalItemID gitem_id(oct_point_id,item->transform_index);
    // Item transform will be our transform * item_transform
    bool item_exist = false;
    CreationInfo ci;
    if(items_creation_info.has(item->transform_index)){
        ci = items_creation_info[item->transform_index];
        item_exist = true;
        if(ci.item_id==item_id){
            // nothing to do already exist
            // only norify packed scene about new update!
            if(item->type==MHlod::Type::PACKED_SCENE){
                if(ci.root_node!=nullptr){
                    ci.root_node->call_deferred("_notify_update_lod",lod);
                }
            }
            return;
        }
    }
    switch (item->type)
    {
    case MHlod::Type::MESH:
        {
            if(item_res.rid.is_valid()){
                RID instance;
                if(!item_exist){
                    instance = RS->instance_create();
                    RS->instance_set_scenario(instance,octree->get_scenario());
                    RS->instance_set_transform(instance,get_item_transform(item));
                    // in this case we need to insert this inside creation info as it changed
                    ci.set_rid(instance);
                    // Generating apply info
                    if(!is_visible || (item->is_bound && bind_item_get_disable(gitem_id))){
                        RS->instance_set_visible(instance,false);
                    } else if(!immediate){
                        ApplyInfo ainfo(MHlod::Type::MESH,false);
                        ainfo.set_instance(instance);
                        apply_info.push_back(ainfo);
                        RS->instance_set_visible(instance,false);
                    }
                    RS->instance_set_base(instance,item_res.rid);
                } else {
                    // changing one instance mesh should not result in flickering
                    // if this happen later we should consider a change here
                    instance = ci.get_rid();
                    RS->instance_set_base(instance,item_res.rid);
                    ERR_FAIL_COND(ci.item_id==-1);
                    hlod->item_list.ptrw()[ci.item_id].remove_user();
                }
                /// Setting material
                Vector<RID> surfaces_materials;
                item->mesh.get_material(surfaces_materials);
                for(int i=0; i < surfaces_materials.size(); i++){
                    if(surfaces_materials[i].is_valid()){
                        RS->instance_set_surface_override_material(instance,i,surfaces_materials[i]);
                    }
                }
            } else {
                // Basically this should not happen
                remove_item(item,item_id);
                ERR_FAIL_MSG("Item empty mesh");
            }
        }
        break;
    case MHlod::Type::DECAL:
    case MHlod::Type::LIGHT:
        if(item_res.rid.is_valid()){
            RID instance = RS->instance_create();
            RS->instance_set_scenario(instance,octree->get_scenario());
            RS->instance_set_transform(instance,get_item_transform(item));
            ci.set_rid(instance);
            RS->instance_set_base(instance,item_res.rid);
            if(!is_visible || (item->is_bound && bind_item_get_disable(gitem_id))){
                RS->instance_set_visible(instance,false);
            }
        } else {
            // Basically this should not happen
            remove_item(item,item_id);
            ERR_FAIL_MSG("Item empty light or decal");
        }
        break;
    case MHlod::Type::COLLISION:
    case MHlod::Type::COLLISION_COMPLEX:
        if(item_res.rid.is_valid()){
            ci.body_id = item->get_physics_body();
            MHlod::PhysicBodyInfo& body_info = MHlod::get_physic_body(ci.body_id);
            PhysicsServer3D::get_singleton()->body_add_shape(body_info.rid,item_res.rid);
            PhysicsServer3D::get_singleton()->body_set_shape_transform(body_info.rid,body_info.shapes.size(),get_item_transform(item));
            if(item->is_bound && bind_item_get_disable(gitem_id)){
                PhysicsServer3D::get_singleton()->body_set_shape_disabled(body_info.rid,body_info.shapes.size(),true);
            }
            body_info.shapes.push_back(gitem_id.id); // should be at end
        } else {
            // Basically this should not happen
            remove_item(item,item_id);
            ERR_FAIL_MSG("Item empty Shape");
        }
        break;
    case MHlod::Type::PACKED_SCENE:
        if(item_res.packed_scene!=nullptr){
            Node* node = item_res.packed_scene->instantiate();
            ERR_FAIL_COND(node==nullptr);
            MHlodNode3D* hlod_node = Object::cast_to<MHlodNode3D>(node);
            if(hlod_node==nullptr){
                WARN_PRINT(node->get_name()+String(" Can not cast to MHlodNode3D"));
                node->queue_free();
                return;
            }
            // Setting Packed Scene Variables
            hlod_node->global_id = GlobalItemID(oct_point_id,item->transform_index);
            hlod_node->permanent_id = PermanentItemID(proc_id,item_id);
            hlod_node->proc = this;
            hlod_node->set_transform(hlod->transforms[item->transform_index]); // PackeScene transform is different from above
            for(int i=0;i<M_PACKED_SCENE_ARG_COUNT;i++){hlod_node->args[i] = item->packed_scene.args[i];}
            for(int i=0;i<M_PACKED_SCENE_BIND_COUNT;i++){hlod_node->bind_items[i] = get_item_global_id(item->packed_scene.bind_items[i]);}
            // Done
            scene->call_deferred("add_child",hlod_node);
            ci.root_node = hlod_node;
            ci.root_node->call_deferred("_notify_update_lod",lod);
        } else {
            // Basically this should not happen
            remove_item(item,item_id);
            ERR_FAIL_MSG("Item empty Packed Scene");
        }
        break;
    default:
        break;
    }
    // Setting Creation info
    ci.type = item->type;
    ci.item_id = item_id;
    items_creation_info.insert(item->transform_index,ci);
    if(item->is_bound){
        std::lock_guard<std::mutex> plock(packed_scene_mutex);
        GlobalItemID igid(oct_point_id,item->transform_index);
        bound_items_creation_info.insert(igid.id,ci);
    }
}

void MHlodScene::Proc::remove_item(MHlod::Item* item,const int item_id,const bool immediate,const bool is_destruction){
    if(!items_creation_info.has(item->transform_index)){
        return;
    }
    GlobalItemID gitem_id(oct_point_id,item->transform_index);
    if(item->is_bound){
        std::lock_guard<std::mutex> plock(packed_scene_mutex);
        bound_items_creation_info.erase(gitem_id.id);
    }
    if(item->is_bound){
        std::lock_guard<std::mutex> plock(packed_scene_mutex);
        GlobalItemID igid(oct_point_id,item->transform_index);
        bound_items_creation_info.erase(igid.id);
    }
    CreationInfo c_info = items_creation_info[item->transform_index];
    switch (item->type)
    {
    case MHlod::Type::MESH:
        {
            RID instance = c_info.get_rid();
            if(instance.is_valid()){
                CreationInfo apply_creation_info;
                if(immediate){
                    RS->free_rid(instance);
                    item->remove_user();
                } else{
                    ApplyInfo ainfo(MHlod::Type::MESH,true);
                    ainfo.set_instance(instance);
                    apply_info.push_back(ainfo);
                }
            }
        }
        break;
    case MHlod::Type::DECAL:
    case MHlod::Type::LIGHT:
        {
            RID instance = c_info.get_rid();
            if(instance.is_valid()){
                RS->free_rid(instance);
                item->remove_user();
            }
        }
        break;
    case MHlod::Type::COLLISION:
    case MHlod::Type::COLLISION_COMPLEX:
        {
            MHlod::PhysicBodyInfo& body_info = MHlod::get_physic_body(c_info.body_id);
            int shape_index_in_body = body_info.shapes.find(gitem_id.id);
            ERR_FAIL_COND(shape_index_in_body==-1);
            PhysicsServer3D::get_singleton()->body_remove_shape(body_info.rid,shape_index_in_body);
            body_info.shapes.remove_at(shape_index_in_body);
            item->remove_user();
        }
        break;
    case MHlod::Type::PACKED_SCENE:
        {
            std::lock_guard<std::mutex> lock(packed_scene_mutex);
            if(removed_packed_scenes.has(c_info.root_node)){
                removed_packed_scenes.erase(c_info.root_node);
            } else if(c_info.root_node!=nullptr){
                if(is_destruction){
                    c_info.root_node->proc = nullptr;
                }
                c_info.root_node->hlod_remove_me = true; // realy important otherwise you will see the most wierd bug in your life
                c_info.root_node->call_deferred("_notify_before_remove");
                c_info.root_node->call_deferred("queue_free");
            }
        }
        break;
    default:
        break;
    }
    items_creation_info.erase(item->transform_index);
}
// Must be protect with packed_scene_mutex if Item is_bound = true
void MHlodScene::Proc::update_item_transform(const int32_t transform_index,const Transform3D& new_transform){
    if(!items_creation_info.has(transform_index)){
        return;
    }
    CreationInfo c_info = items_creation_info[transform_index];
    switch (c_info.type)
    {
    case MHlod::Type::MESH:
    case MHlod::Type::DECAL:
    case MHlod::Type::LIGHT:
        {
            RID instance = c_info.get_rid();
            if(instance.is_valid()){
                RS->instance_set_transform(instance,new_transform);
            }
        }
        break;
    case MHlod::Type::COLLISION:
    case MHlod::Type::COLLISION_COMPLEX:
        {
            GlobalItemID gid(oct_point_id,transform_index);
            MHlod::PhysicBodyInfo& b = MHlod::get_physic_body(c_info.body_id);
            int findex = b.shapes.find(gid.id);
            if(findex!=-1){
                PhysicsServer3D::get_singleton()->body_set_shape_transform(b.rid,findex,new_transform);
            }
        }
        break;
    default:
        break;
    }
}

void MHlodScene::Proc::update_all_transform(){
    if(lod<0 || lod >= hlod->lods.size() || hlod->lods[lod].size() == 0){
        return;
    }
    VSet<int32_t> lod_table = hlod->lods[lod];
    for(int i=0; i < lod_table.size(); i++){
        ERR_FAIL_INDEX(lod_table[i],hlod->item_list.size());
        MHlod::Item* item = hlod->item_list.ptrw() + lod_table[i];
        Transform3D t = get_item_transform(item);
        if(item->is_bound){
            std::lock_guard<std::mutex> plock(packed_scene_mutex);
            update_item_transform(item->transform_index,t);
        } else {
            update_item_transform(item->transform_index,t);
        }
    }
}

void MHlodScene::Proc::reload_meshes(const bool recursive){
    remove_all_items(true);
    int8_t __cur_lod = lod;
    lod = -1; // because update_lod function should know we don't have any mesh from before
    update_lod(__cur_lod, true);
    // Applying for sub proc
    if(recursive){
        for(int i=0; i < sub_procs_size; i++){
            get_subprocs_ptrw()[i].reload_meshes();
        }
    }
}

void MHlodScene::Proc::remove_all_items(const bool immediate,const bool is_destruction){
    if(hlod.is_null()){
        return;
    }
    if(lod<0 || lod >= hlod->lods.size() || hlod->lods[lod].size() == 0){
        return; // Nothing to remove
    }
    VSet<int32_t> lod_table = hlod->lods[lod];
    for(HashMap<int32_t,CreationInfo>::Iterator it=items_creation_info.begin();it!=items_creation_info.end();++it){
        remove_item(hlod->item_list.ptrw() + it->value.item_id,it->value.item_id,immediate,is_destruction);
    }
}

// Will return if it is diry or not (has something to apply in the main game loop)
void MHlodScene::Proc::update_lod(int8_t c_lod,const bool immediate){
    ERR_FAIL_COND(oct_point_id==-1);
    ERR_FAIL_COND(octree==nullptr);
    int8_t last_lod = lod;
    lod = c_lod;
    if(!is_enable || hlod.is_null()){
        return;
    }
    if(hlod->join_at_lod!=-1){
        if(c_lod >= hlod->join_at_lod){ // Disabling all sub_hlod if we use join mesh lod
            disable_sub_proc();
        } else {
            enable_sub_proc();
        }
    }
    if(c_lod<0 || c_lod >= hlod->lods.size() || hlod->lods[c_lod].size() == 0){
        remove_all_items(immediate);
        return; // we don't consider this dirty as there is nothing to be appllied later
    }
    const VSet<int32_t>* lod_table = hlod->lods.ptr() + c_lod;
    VSet<int32_t> exist_transform_index;
    for(int i=0; i < (*lod_table).size(); i++){
        ERR_FAIL_INDEX(lod_table->operator[](i),hlod->item_list.size()); // maybe remove this check later
        MHlod::Item* item = hlod->item_list.ptrw() + (*lod_table)[i];
        if(item->item_layers!=0){
            bool lres = (item->item_layers & scene_layers)!=0;
        }
        if(item->item_layers==0 || (item->item_layers & scene_layers)!=0){ // Layers filter
            add_item(item,(*lod_table)[i],immediate);
            exist_transform_index.insert(item->transform_index);
        }
    }
    // Checking the last lod table
    // and remove items if needed
    if(last_lod<0 || last_lod >= hlod->lods.size() || hlod->lods[c_lod].size() == 0){
        // nothing to do just update lod and go out
        return;
    }
    const VSet<int32_t>* last_lod_table = hlod->lods.ptr() + last_lod;
    for(int i=0; i < (*last_lod_table).size(); i++){
        MHlod::Item* last_item = hlod->item_list.ptrw() + (*last_lod_table)[i];
        if(last_item->item_layers==0 || (last_item->item_layers & scene_layers)!=0){ // Layers filter
            if(!exist_transform_index.has(last_item->transform_index)){
                remove_item(last_item,(*last_lod_table)[i],immediate);
            }
        }
    }
}

void MHlodScene::Proc::set_visibility(bool visibility){
    is_visible = visibility;
    for(HashMap<int32_t,CreationInfo>::Iterator it=items_creation_info.begin();it!=items_creation_info.end();++it){
        switch (it->value.type)
        {
        case MHlod::Type::MESH:
        case MHlod::Type::DECAL:
        case MHlod::Type::LIGHT:
            RS->instance_set_visible(it->value.get_rid(),visibility);
            break;
        default:
            break;
        }
    }
    for(int i=0; i < sub_procs_size; i++){
        get_subprocs_ptrw()[i].set_visibility(visibility);
    }
}

#ifdef DEBUG_ENABLED
void MHlodScene::Proc::_get_editor_tri_mesh_info(PackedVector3Array& vertices,PackedInt32Array& indices,const Transform3D& local_transform) const{
    if(hlod.is_valid()){
        for(HashMap<int32_t,CreationInfo>::ConstIterator it=items_creation_info.begin();it!=items_creation_info.end();++it){
            if(it->value.type == MHlod::Type::MESH){
                Ref<MMesh> _m = hlod->item_list[it->value.item_id].mesh.mesh;
                if(_m.is_valid()){
                    Transform3D t = local_transform * hlod->transforms[hlod->item_list[it->value.item_id].transform_index];
                    int s_count = _m->get_surface_count();
                    for(int s=0; s < s_count; s++){
                        PackedVector3Array _mv;
                        PackedInt32Array _mi;
                        {
                            Array sinfo = _m->surface_get_arrays(s);
                            _mv = sinfo[Mesh::ARRAY_VERTEX];
                            _mi = sinfo[Mesh::ARRAY_INDEX];
                            for(const Vector3& v : _mv){
                                vertices.push_back(t.xform(v));
                            }
                            int32_t offset = indices.size();
                            for(const int32_t index : _mi){
                                indices.push_back(index+offset);
                            }
                        }
                    }
                }
            }
        }
    }
    // Sub procs
    for(int i=0; i < sub_procs_size; i++){
    }
}
#endif

/////////////////////////////////////////////////////
/// Static --> Proc Manager
/////////////////////////////////////////////////////
bool MHlodScene::is_sleep = false;
Vector<MHlodScene::Proc*> MHlodScene::all_tmp_procs;
VSet<MHlodScene*> MHlodScene::all_hlod_scenes;
HashMap<int32_t,MHlodScene::Proc*> MHlodScene::octpoints_to_proc;
MOctree* MHlodScene::octree = nullptr;
WorkerThreadPool::TaskID MHlodScene::thread_task_id;
std::mutex MHlodScene::update_mutex;
std::mutex MHlodScene::packed_scene_mutex;
bool MHlodScene::is_updating = false;
bool MHlodScene::is_octree_inserted = false;
uint16_t MHlodScene::oct_id;
int32_t MHlodScene::last_oct_point_id = -1;
Vector<MHlodScene::ApplyInfo> MHlodScene::apply_info;
Vector<MHlod::Item*> MHlodScene::removing_users;
VSet<MHlodNode3D*> MHlodScene::removed_packed_scenes;
HashMap<int64_t,MHlodScene::CreationInfo> MHlodScene::bound_items_creation_info;
HashMap<int64_t,Transform3D> MHlodScene::bound_items_modified_transforms;
HashSet<int64_t> MHlodScene::bound_items_disabled;

bool MHlodScene::is_my_octree(MOctree* input){
    return input == octree;
}

bool MHlodScene::set_octree(MOctree* input){
    ERR_FAIL_COND_V(input==nullptr,false);
    if(octree){
        WARN_PRINT("octree "+octree->get_name()+" is already assigned to hlod! Only one octree can be assing to update MOctMesh!");
        return false;
    }
    octree = input;
    oct_id = octree->get_oct_id();
    // Octree will call us when we need to insert point or update
    return true;
}

MOctree* MHlodScene::get_octree(){
    return octree;
}

uint16_t MHlodScene::get_oct_id(){
    return oct_id;
}
// oct_point_id last avialable oct_point_id! if there was not oct_point_id you should pass -1
// in case the oct_point_id you are sending is aviable that will set this oct_point_id for you!
// otherwise it will set a new oct_point_id for you
// ther return oct_point_id is valid and final oct_point_id
int32_t MHlodScene::add_proc(Proc* _proc,int oct_point_id){
    if(oct_point_id < 0 || octpoints_to_proc.has(oct_point_id)){
        last_oct_point_id++;
        oct_point_id = last_oct_point_id;
    }
    if(octree!=nullptr && is_octree_inserted){
        bool res = octree->insert_point(_proc->transform.origin,oct_point_id,oct_id);
        ERR_FAIL_COND_V_MSG(!res,INVALID_OCT_POINT_ID,"Single Proc point can't be inserted!");
    }
    octpoints_to_proc.insert(oct_point_id,_proc);
    return oct_point_id;
}

void MHlodScene::remove_proc(int32_t octpoint_id){
    if(!octpoints_to_proc.has(octpoint_id)){
        return;
    }
    Proc* _proc = octpoints_to_proc[octpoint_id];
    _proc->oct_point_id = INVALID_OCT_POINT_ID;
    _proc->lod = -1;
    octpoints_to_proc.erase(octpoint_id);
    if(octree!=nullptr && is_octree_inserted){
        octree->remove_point(octpoint_id,_proc->transform.origin,oct_id);
    }
}

void MHlodScene::move_proc(int32_t octpoint_id,const Vector3& old_pos,const Vector3& new_pos){

}

void MHlodScene::insert_points(){
    ERR_FAIL_COND(octree==nullptr);
    is_octree_inserted = true;
    PackedVector3Array points_pos;
    PackedInt32Array points_ids;
    for(HashMap<int32_t,Proc*>::Iterator it=octpoints_to_proc.begin();it!=octpoints_to_proc.end();++it){
        points_ids.push_back(it->key);
        Vector3 oct_pos = it->value->transform.origin;
        points_pos.push_back(oct_pos);
    }
    octree->insert_points(points_pos,points_ids,oct_id);
}
#include <godot_cpp/classes/time.hpp>
void MHlodScene::first_octree_update(Vector<MOctree::PointUpdate>* update_info){
    // more close to root proc has smaller ID!
    // if not sorted some proc can create items and diable later in same update which is a waste
    update_info->sort();
    for(int i=0; i < update_info->size(); i++){
        MOctree::PointUpdate p = update_info->get(i);
        if(!octpoints_to_proc.has(p.id)){
            continue;
        }
        Proc* _proc = octpoints_to_proc.get(p.id);
        _proc->update_lod(p.lod,true);
    }
    octree->point_process_finished(oct_id);
}

void MHlodScene::octree_update(Vector<MOctree::PointUpdate>* update_info){
    if(update_info->size() > 0) {
        is_updating = true;
        thread_task_id = WorkerThreadPool::get_singleton()->add_native_task(&MHlodScene::octree_thread_update,(void*)update_info,true);
    } else {
        octree->point_process_finished(oct_id);
    }
}

void MHlodScene::octree_thread_update(void* input){
    std::lock_guard<std::mutex> lock(MHlodScene::update_mutex);
    for(int i=0; i < all_hlod_scenes.size() ;++i){
        all_hlod_scenes[i]->procs_update_state.fill_false(); // set it to false and if then updated we set it back to true
    }
    apply_remove_item_users();
    Vector<MOctree::PointUpdate>* update_info = (Vector<MOctree::PointUpdate>*)input;
    // more close to root proc has smaller ID!
    // if not sorted some proc can create items and diable later in same update which is a waste
    update_info->sort();
    for(int i=0; i < update_info->size(); i++){
        MOctree::PointUpdate p = update_info->get(i);
        if(!octpoints_to_proc.has(p.id)){
            continue;
        }
        Proc* _proc = octpoints_to_proc.get(p.id);
        _proc->update_lod(p.lod);
    }
    // Updating triangle collission mesh for editor
    #ifdef DEBUG_ENABLED
    //for(HashSet<MHlodScene*>::Iterator it=all_hlod_scenes.begin();it!=all_hlod_scenes.end();++it){
    //    (*it)->_update_editor_tri_mesh();
    //}
    #endif
}

void MHlodScene::update_tick(){
    if(is_updating){
        if(WorkerThreadPool::get_singleton()->is_task_completed(thread_task_id)){
            is_updating = false;
            WorkerThreadPool::get_singleton()->wait_for_task_completion(thread_task_id);
            ERR_FAIL_COND(octree==nullptr);
            octree->point_process_finished(oct_id);
            apply_update();
        }
    }
}

void MHlodScene::apply_remove_item_users(){
    for(MHlod::Item* item : removing_users){
        item->remove_user();
    }
    removing_users.clear();
}

void MHlodScene::apply_update(){
    for(const ApplyInfo& ainfo : apply_info){
        switch (ainfo.type)
        {
        case MHlod::Type::MESH:
            if(ainfo.remove){
                RS->free_rid(ainfo.get_instance());
            } else {
                RS->instance_set_visible(ainfo.get_instance(),true);
            }
            break;
        default:
            break;
        }
    }
    apply_info.clear();
}

void MHlodScene::flush(){
    apply_update();
    apply_remove_item_users();
}

void MHlodScene::sleep(){
    std::lock_guard<std::mutex> lock(MHlodScene::update_mutex);
    if(is_sleep){
        return;
    }
    is_sleep = true;
    for(int i=0; i < all_hlod_scenes.size() ;++i){
        all_hlod_scenes[i]->deinit_proc<false>();
    }
}

void MHlodScene::awake(){
    std::lock_guard<std::mutex> lock(MHlodScene::update_mutex);
    if(!is_sleep){
        return;
    }
    is_sleep = false;
    for(int i=0; i < all_hlod_scenes.size() ;++i){
        all_hlod_scenes[i]->init_proc<false>();
    }
}

Array MHlodScene::get_hlod_users(const String& hlod_path){
    std::lock_guard<std::mutex> lock(MHlodScene::update_mutex);
    Array out;
    for(int i=0; i < all_hlod_scenes.size() ;++i){
        if( all_hlod_scenes[i]->get_root_proc()->hlod.is_valid() && all_hlod_scenes[i]->get_root_proc()->hlod->get_path() == hlod_path ){
            out.push_back(all_hlod_scenes[i]);
        }
    }
    return out;
}
/////////////////////////////////////////////////////
/// Debug Info
/////////////////////////////////////////////////////
Dictionary MHlodScene::get_debug_info(){
    std::lock_guard<std::mutex> lock(update_mutex);
    int mesh_instance_count = 0;
    int light_count = 0;
    int decal_count = 0;
    int packed_scene_count = 0;
    int simple_shape_count = 0;
    int complex_shape_count = 0;
    for(HashMap<int32_t,Proc*>::ConstIterator pit=octpoints_to_proc.begin(); pit!=octpoints_to_proc.end();++pit){
        if(!pit->value->is_enable){
            continue;
        }
        const HashMap<int32_t,CreationInfo>& creation_info = pit->value->items_creation_info;
        for(HashMap<int32_t,CreationInfo>::ConstIterator cit=creation_info.begin();cit!=creation_info.end();++cit){
            const CreationInfo& ci = cit->value;
            switch (ci.type)
            {
            case MHlod::MESH:
                mesh_instance_count++;
                break;
            case MHlod::LIGHT:
                light_count++;
                break;
            case MHlod::DECAL:
                decal_count++;
                break;
            case MHlod::COLLISION:
                simple_shape_count++;
                break;
            case MHlod::COLLISION_COMPLEX:
                complex_shape_count++;
                break;
            default:
                break;
            }
        }
    }
    Dictionary out;
    out["mesh_instance_count"] = mesh_instance_count;
    out["light_count"] = light_count;
    out["decal_count"] = decal_count;
    out["packed_scene_count"] = packed_scene_count;
    out["simple_shape_count"] = simple_shape_count;
    out["complex_shape_count"] = complex_shape_count;
    return out;
}
/////////////////////////////////////////////////////
/// END Static --> Proc Manager
/////////////////////////////////////////////////////


MHlodScene::MHlodScene(){
    all_hlod_scenes.insert(this);
    set_notify_transform(true);
}

MHlodScene::~MHlodScene(){
    all_hlod_scenes.erase(this);
    deinit_proc<true>();
}

void MHlodScene::set_hlod(Ref<MHlod> input){
    if(is_init_procs()){
        deinit_proc<true>();
    }
    if(input.is_null()){
        procs.clear();
        return;
    }
    procs.resize(1);
    procs.ptrw()[0].hlod = input;
    if(get_root_proc()->hlod.is_valid() && !is_sleep && is_inside_tree()){
        init_proc<true>();
    }
}

Ref<MHlod> MHlodScene::get_hlod(){
    if(procs.size()==0){
        return Ref<MHlod>();
    }
    return get_root_proc()->hlod;
}

void MHlodScene::set_scene_layers(int64_t input){
    scene_layers = input;
    if(is_init_procs()){
        std::lock_guard<std::mutex> lock(MHlodScene::update_mutex);
        get_root_proc()->scene_layers = scene_layers;
        get_root_proc()->reload_meshes(false);
    }
}

int64_t MHlodScene::get_scene_layers(){
    return scene_layers;
}

void MHlodScene::_notification(int p_what){
    switch (p_what)
    {
    case NOTIFICATION_TRANSFORM_CHANGED:
        {
            if(is_init){
                std::lock_guard<std::mutex> lock(MHlodScene::update_mutex);
                get_root_proc()->change_transform(get_global_transform());
            }
        }
        break;
    case NOTIFICATION_VISIBILITY_CHANGED:
        _update_visibility();
        break;
    case NOTIFICATION_READY:
        MHlod::physic_space = get_world_3d()->get_space().get_id();
        break;
    case NOTIFICATION_ENTER_TREE:
        _update_visibility();
        init_proc<true>();
        break;
    case NOTIFICATION_EXIT_TREE:
        call_deferred("_update_visibility");
        break;
    default:
        break;
    }
}

void MHlodScene::_update_visibility(){
    if(!is_init){
        return;
    }
    bool v = is_visible_in_tree() && is_inside_tree();
    get_root_proc()->set_visibility(v);
}

#ifdef DEBUG_ENABLED
void MHlodScene::_update_editor_tri_mesh(){ // will be called in update thread
    PackedVector3Array vertices;
    PackedInt32Array indices;
    Transform3D t;
    get_root_proc()->_get_editor_tri_mesh_info(vertices,indices,t);
    if(vertices.size()==0){
        return;
    }
    Array joined_mesh_info;
    joined_mesh_info.resize(Mesh::ARRAY_MAX);
    joined_mesh_info[Mesh::ARRAY_VERTEX] = vertices;
    joined_mesh_info[Mesh::ARRAY_INDEX] = indices;
    Ref<ArrayMesh> arr_mesh;
    arr_mesh.instantiate();
    arr_mesh->add_surface_from_arrays(godot::Mesh::PrimitiveType::PRIMITIVE_TRIANGLES,joined_mesh_info);
    editor_tri_mesh = arr_mesh->generate_triangle_mesh();
}
#endif

Array MHlodScene::get_triangle_meshes(){
    #ifdef DEBUG_ENABLED
    Array out;
    return out;
    #else
    return Array();
    #endif
}


Array MHlodScene::get_last_lod_mesh_ids_transforms(){
    Array out;
    ERR_FAIL_COND_V(!is_init,out);
    for(int i=0; i < procs.size(); i++){
        const Proc* current_proc = procs.ptr();
        ERR_CONTINUE(current_proc->hlod.is_null());
        int last_lod = current_proc->hlod->get_last_lod_with_mesh();
        Transform3D current_global_transform = current_proc->transform;
        const VSet<int32_t>& item_ids = current_proc->hlod->lods.ptr()[last_lod];
        for(int j=0; j < item_ids.size(); j++){
            const MHlod::Item& item = current_proc->hlod->item_list[item_ids[j]];
            if(item.type != MHlod::Type::MESH){
                continue;
            }
            int mesh_id = item.mesh.mesh_id;
            Transform3D mesh_global_transform = current_global_transform * current_proc->hlod->transforms[item.transform_index];
            Array element;
            element.push_back(mesh_id);
            element.push_back(mesh_global_transform);
            element.push_back(item.mesh.material_id);
            out.push_back(element);
        }
    }
    return out;
}