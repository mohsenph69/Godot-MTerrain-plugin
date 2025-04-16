#include "mhlod_scene.h"

#include <godot_cpp/templates/hash_set.hpp>
#include <godot_cpp/classes/world3d.hpp>
#include <godot_cpp/classes/rendering_server.hpp>

#include "mhlod_node3d.h"

#define RS RenderingServer::get_singleton()


#ifdef DEBUG_ENABLED
#include "../editor/mmesh_joiner.h"
#include <godot_cpp/classes/triangle_mesh.hpp>
#endif


void MHlodScene::_bind_methods(){
    ClassDB::bind_method(D_METHOD("is_init_scene"), &MHlodScene::is_init_scene);

    ClassDB::bind_method(D_METHOD("set_hlod","input"), &MHlodScene::set_hlod);
    ClassDB::bind_method(D_METHOD("get_hlod"), &MHlodScene::get_hlod);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT,"hlod",PROPERTY_HINT_RESOURCE_TYPE,"MHlod"),"set_hlod","get_hlod");

    ClassDB::bind_method(D_METHOD("get_aabb"), &MHlodScene::get_aabb);

    ClassDB::bind_method(D_METHOD("set_scene_layers","input"), &MHlodScene::set_scene_layers);
    ClassDB::bind_method(D_METHOD("get_scene_layers"), &MHlodScene::get_scene_layers);
    ADD_PROPERTY(PropertyInfo(Variant::INT,"scene_layers"),"set_scene_layers","get_scene_layers");

    ClassDB::bind_method(D_METHOD("_update_visibility"), &MHlodScene::_update_visibility);
    ClassDB::bind_method(D_METHOD("get_last_lod_mesh_ids_transforms"), &MHlodScene::get_last_lod_mesh_ids_transforms);

    ClassDB::bind_static_method("MHlodScene",D_METHOD("sleep"), &MHlodScene::sleep);
    ClassDB::bind_static_method("MHlodScene",D_METHOD("awake"), &MHlodScene::awake);
    ClassDB::bind_static_method("MHlodScene",D_METHOD("get_hlod_users","hlod_path"), &MHlodScene::get_hlod_users);

    ClassDB::bind_static_method("MHlodScene",D_METHOD("get_debug_info"), &MHlodScene::get_debug_info);
    #ifdef DEBUG_ENABLED
    ClassDB::bind_method(D_METHOD("get_triangle_mesh"), &MHlodScene::get_triangle_mesh);
    #endif
}

MHlodScene::Proc::Proc(MHlodScene* _scene,Ref<MHlod> _hlod,int32_t _proc_id,int32_t _scene_layers,const Transform3D& _transform):
hlod(_hlod),scene(_scene),proc_id(_proc_id),scene_layers(_scene_layers),transform(_transform)
{

}

MHlodScene::Proc::~Proc(){
    if(oct_point_id!=-1){
        MHlodScene::remove_proc(oct_point_id);
    }
    #if DEBUG_ENABLED
    // if one of error bellow happen it means it did not cleaned well by deinit_proc()
    ERR_FAIL_COND_MSG(items_creation_info.size()!=0,"items_creation_info non zero on ~Proc(), size is: "+itos(items_creation_info.size()));
    ERR_FAIL_COND_MSG(ApplyInfoRendering::size()!=0,"ApplyInfoRendering non zero on ~Proc(), size is: "+itos(ApplyInfoRendering::size()));
    #endif
    // disable() will be called by deinit_proc
}

void MHlodScene::Proc::init_sub_proc(int32_t _sub_proc_index,uint64_t _sub_proc_size,int32_t _proc_id){
    sub_proc_index = _sub_proc_index;
    sub_procs_size = _sub_proc_size;
    proc_id = _proc_id;
}

void MHlodScene::Proc::change_transform(const Transform3D& new_transform){
    is_transform_changed = true;
    if(MHlodScene::octree!=nullptr && is_enable && is_octree_inserted){
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
    ERR_FAIL_COND(oct_point_id==-1);
    is_enable = true;
    // oct_point_id is defined in init_proc function
    // oct_point_id should not be changed in lifetime of proc
    if(lod!=-1){
        update_lod(lod); // Upper importnat don't move this down, upper to lower
    }
    if(recursive){
        for(int i=0; i < sub_procs_size; i++){
            get_subprocs_ptrw()[i].enable();
        }
    }
}

void MHlodScene::Proc::disable(const bool recursive,const bool is_destruction){
    if(!is_enable){
        return;
    }
    ERR_FAIL_COND(hlod.is_null());
    is_enable = false;
    remove_all_items(false,is_destruction);
    if(recursive){
        for(int i=0; i < sub_procs_size; i++){
            get_subprocs_ptrw()[i].disable(recursive,is_destruction);
        }
    }
}

void MHlodScene::Proc::enable_sub_proc(){
    for(int i=0; i < sub_procs_size; i++){
        get_subprocs_ptrw()[i].enable();
    }
}

void MHlodScene::Proc::disable_sub_proc(){
    for(int i=0; i < sub_procs_size; i++){
        get_subprocs_ptrw()[i].disable(true,false);
    }
}

void MHlodScene::Proc::add_item(MHlod::Item* item,const int item_id){
    if(item->type==MHlod::Type::DECAL || item->type==MHlod::Type::LIGHT){
        return;
    }
    #if MHLODSCENE_DISABLE_RENDERING
    if(item->type==MHlod::Type::DECAL || item->type==MHlod::Type::LIGHT || item->type==MHlod::Type::MESH){
        return;
    }
    #endif
    #if MHLODSCENE_DISABLE_PHYSICS
    if(item->type==MHlod::Type::COLLISION || item->type==MHlod::Type::COLLISION_COMPLEX){
        return;
    }
    #endif
    item->add_user(); // will load in thread and has time until apply_update
    GlobalItemID gitem_id(oct_point_id,item->transform_index);
    // Item transform will be our transform * item_transform
    bool item_exist = false;
    CreationInfo ci;
    if(items_creation_info.has(item->transform_index)){
        ci = items_creation_info[item->transform_index];
        item_exist = true;
        ERR_FAIL_COND(ci.item_id==-1);
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
            RID instance;
            if(!item_exist){
                instance = RS->instance_create();
                #if MHLODSCENE_DEBUG_COUNT
                total_rendering_instance_count++;
                #endif
                RS->instance_set_scenario(instance,octree->get_scenario());
                RS->instance_geometry_set_cast_shadows_setting(instance,(RenderingServer::ShadowCastingSetting)item->mesh.shadow_setting);
                RS->instance_set_transform(instance,get_item_transform(item));
                switch (item->mesh.gi_mode)
                {
                case MHLOD_CONST_GI_MODE_DISABLED:
                    RS->instance_geometry_set_flag(instance,RenderingServer::INSTANCE_FLAG_USE_BAKED_LIGHT, false);
                    RS->instance_geometry_set_flag(instance,RenderingServer::INSTANCE_FLAG_USE_DYNAMIC_GI, false);
                    break;
                case MHLOD_CONST_GI_MODE_STATIC:
                    RS->instance_geometry_set_flag(instance,RenderingServer::INSTANCE_FLAG_USE_BAKED_LIGHT, true);
                    RS->instance_geometry_set_flag(instance,RenderingServer::INSTANCE_FLAG_USE_DYNAMIC_GI, false);
                    break;
                case MHLOD_CONST_GI_MODE_DYNAMIC:
                    RS->instance_geometry_set_flag(instance,RenderingServer::INSTANCE_FLAG_USE_BAKED_LIGHT, false);
                    RS->instance_geometry_set_flag(instance,RenderingServer::INSTANCE_FLAG_USE_DYNAMIC_GI, true);
                    break;
                case MHLOD_CONST_GI_MODE_STATIC_DYNAMIC:
                    RS->instance_geometry_set_flag(instance,RenderingServer::INSTANCE_FLAG_USE_BAKED_LIGHT, true);
                    RS->instance_geometry_set_flag(instance,RenderingServer::INSTANCE_FLAG_USE_DYNAMIC_GI, true);
                    break;
                default:
                    WARN_PRINT("Invalid GI Mode");
                }
                ci.set_rid(instance);
            } else {
                instance = ci.get_rid();
                removing_users.push_back(hlod->item_list.ptrw() + ci.item_id);
            }
            /// Setting material
            Vector<RID> surfaces_materials;
            item->mesh.get_material(surfaces_materials);
            for(int i=0; i < surfaces_materials.size(); i++){
                if(surfaces_materials[i].is_valid()){
                    RS->instance_set_surface_override_material(instance,i,surfaces_materials[i]);
                }
            }
            // creating apply info
            ApplyInfoRendering::add(instance,item,false);
        }
        break;
    case MHlod::Type::DECAL:
    case MHlod::Type::LIGHT:
        {
            RID instance = RS->instance_create();
            #if MHLODSCENE_DEBUG_COUNT
            total_rendering_instance_count++;
            #endif
            RS->instance_set_scenario(instance,octree->get_scenario());
            RS->instance_set_transform(instance,get_item_transform(item));
            ci.set_rid(instance);
            if(!is_visible || (item->is_bound && bind_item_get_disable(gitem_id))){
                RS->instance_set_visible(instance,false);
            }
            if(item->has_cache()){ // this should not be done for Mesh type for flickring issue
                RS->instance_set_base(instance,item->get_rid());
            } else {
                ApplyInfoRendering::add(instance,item,false);
            }
        }
        break;
    case MHlod::Type::COLLISION:
    case MHlod::Type::COLLISION_COMPLEX:
        {
            ci.body_id = item->get_physics_body();
            if(item->has_cache()){
                MHlod::PhysicBodyInfo& body_info = MHlod::get_physic_body(ci.body_id);
                PhysicsServer3D::get_singleton()->body_add_shape(body_info.rid,item->get_rid());
                #if MHLODSCENE_DEBUG_COUNT
                total_shape_count++;
                #endif
                PhysicsServer3D::get_singleton()->body_set_shape_transform(body_info.rid,body_info.shapes.size(),get_item_transform(item));
                if(item->is_bound && bind_item_get_disable(gitem_id)){
                    PhysicsServer3D::get_singleton()->body_set_shape_disabled(body_info.rid,body_info.shapes.size(),true);
                }
                body_info.shapes.push_back(gitem_id.id); // should be at end
            } else {
                ApplyInfoPhysics::add(item,this,gitem_id);
            }
        }
        break;
    case MHlod::Type::PACKED_SCENE:
        if(item->has_cache() && false){
            MHlodNode3D* hlod_node = item->get_hlod_node3d();
            ERR_FAIL_COND(hlod_node==nullptr);
            // Setting Packed Scene Variables
            hlod_node->global_id = gitem_id;
            hlod_node->proc = this;
            for(int i=0;i<M_PACKED_SCENE_BIND_COUNT;i++){
                hlod_node->bind_items[i] = get_item_global_id(item->packed_scene.bind_items[i]);
            }
            // Done
            scene->call_deferred("add_child",hlod_node);
            hlod_node->call_deferred("set_global_transform",get_item_transform(item));
            hlod_node->call_deferred("_notify_update_lod",lod);
            ci.root_node = hlod_node;
        } else {
            ApplyInfoPackedScene::add(item,this,gitem_id);
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

// should clear creation_info afer calling this
void MHlodScene::Proc::remove_item(MHlod::Item* item,const int item_id,const bool is_destruction){
    ERR_FAIL_COND(!items_creation_info.has(item->transform_index));
    #if MHLODSCENE_DISABLE_RENDERING
    if(item->type==MHlod::Type::DECAL || item->type==MHlod::Type::LIGHT || item->type==MHlod::Type::MESH){
        return;
    }
    #endif
    #if MHLODSCENE_DISABLE_PHYSICS
    if(item->type==MHlod::Type::COLLISION || item->type==MHlod::Type::COLLISION_COMPLEX){
        return;
    }
    #endif
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
                ApplyInfoRendering::add(instance,item,true);
            } else {
                WARN_PRINT("removing item mesh instance is not valid!");
            }
        }
        break;
    case MHlod::Type::DECAL:
    case MHlod::Type::LIGHT:
        { // no apply info for these as there is no flickring issue with these
            RID instance = c_info.get_rid();
            if(instance.is_valid()){
                RS->free_rid(instance);
                #if MHLODSCENE_DEBUG_COUNT
                total_rendering_instance_count--;
                #endif
            }
        }
        break;
    case MHlod::Type::COLLISION:
    case MHlod::Type::COLLISION_COMPLEX:
        { // no apply info for these as there is no flickring issue with these
            MHlod::PhysicBodyInfo& body_info = MHlod::get_physic_body(c_info.body_id);
            int shape_index_in_body = body_info.shapes.find(gitem_id.id);
            ERR_FAIL_COND(shape_index_in_body==-1);
            PhysicsServer3D::get_singleton()->body_remove_shape(body_info.rid,shape_index_in_body);
            #if MHLODSCENE_DEBUG_COUNT
            total_shape_count--;
            #endif
            body_info.shapes.remove_at(shape_index_in_body);
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
    removing_users.push_back(item);
    // items_creation_info erase(__item->transform_index); should be called from outside after this
    // otherwise memory segementation issue occure as sometimes  items_creation_info is loop with its items
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
    if(!is_enable || lod<0 || lod >= hlod->lods.size() || hlod->lods[lod].size() == 0){
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
    update_lod(__cur_lod);
    // Applying for sub proc
    if(recursive){
        for(int i=0; i < sub_procs_size; i++){
            get_subprocs_ptrw()[i].reload_meshes();
        }
    }
}

void MHlodScene::Proc::remove_all_items(const bool immediate,const bool is_destruction){
    for(HashMap<int32_t,CreationInfo>::Iterator it=items_creation_info.begin();it!=items_creation_info.end();++it){
        remove_item(hlod->item_list.ptrw() + it->value.item_id,it->value.item_id,is_destruction);
    }
    items_creation_info.clear();
}

// Will return if it is diry or not (has something to apply in the main game loop)
void MHlodScene::Proc::update_lod(int8_t c_lod){
    ERR_FAIL_COND(oct_point_id==-1);
    ERR_FAIL_COND(octree==nullptr);
    ERR_FAIL_COND(hlod.is_null());
    int8_t last_lod = lod;
    lod = c_lod;
    if(!is_enable){
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
        remove_all_items(true);
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
            add_item(item,(*lod_table)[i]);
            exist_transform_index.insert(item->transform_index);
        }
    }
    // Checking the last lod table
    // and remove items if needed
    if(last_lod<0 || last_lod >= hlod->lods.size() || hlod->lods[c_lod].size() == 0){
        // nothing to do just update lod and go out
        return;
    }
    Vector<int32_t> removed_trasform_indices;
    for(HashMap<int32_t,CreationInfo>::Iterator it=items_creation_info.begin();it!=items_creation_info.end();++it){
        if(!exist_transform_index.has(it->key)){
            remove_item(hlod->item_list.ptrw()+it->value.item_id, it->value.item_id,false);
            removed_trasform_indices.push_back(it->key);
        }
    }
    for(int32_t rm_t : removed_trasform_indices){
        items_creation_info.erase(rm_t);
    }
}

void MHlodScene::Proc::set_visibility(bool visibility){
    is_visible = visibility;
    for(HashMap<int32_t,CreationInfo>::ConstIterator it=items_creation_info.begin();it!=items_creation_info.end();++it){
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
MHlodScene::UpdateState MHlodScene::update_state = MHlodScene::UpdateState::OCTREE;
bool MHlodScene::is_octree_inserted = false;
uint16_t MHlodScene::oct_id;
int32_t MHlodScene::last_oct_point_id = -1;
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
int32_t MHlodScene::get_free_oct_point_id(){
    last_oct_point_id++;
    return last_oct_point_id;
}

int32_t MHlodScene::add_proc(Proc* _proc,int oct_point_id){
    if(octree!=nullptr && is_octree_inserted){
        bool res = octree->insert_point(_proc->transform.origin,oct_point_id,oct_id);
        ERR_FAIL_COND_V_MSG(!res,INVALID_OCT_POINT_ID,"Single Proc point can't be inserted!");
    }
    octpoints_to_proc.insert(oct_point_id,_proc);
    return oct_point_id;
}

void MHlodScene::remove_proc(int32_t octpoint_id){
    ERR_FAIL_COND(!octpoints_to_proc.has(octpoint_id));
    Proc* _proc = octpoints_to_proc[octpoint_id];
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

void MHlodScene::first_octree_update(Vector<MOctree::PointUpdate>* update_info){
    // more close to root proc has smaller ID!
    // if not sorted some proc can create items and diable later in same update which is a waste
    std::lock_guard<std::mutex> lock(MHlodScene::update_mutex);
    update_info->sort();
    for(int i=0; i < update_info->size(); i++){
        MOctree::PointUpdate p = update_info->get(i);
        if(!octpoints_to_proc.has(p.id)){
            continue;
        }
        Proc* _proc = octpoints_to_proc.get(p.id);
        _proc->update_lod(p.lod);
    }
    // applying update manually
    update_state = get_next_update_state(UpdateState::LOAD_REST);
    while (update_state!=UpdateState::UPDATE_STATE_MAX)
    {
        apply_update(update_state);
        update_state = get_next_update_state(update_state);
    }
    update_state = UpdateState::OCTREE;
    // sending finish process signal
    octree->point_process_finished(oct_id);
}

void MHlodScene::octree_update(Vector<MOctree::PointUpdate>* update_info){
    if(update_info->size() > 0) {
        update_state = UpdateState::LOAD;
        #if MHLODSCENE_THREAD_RENDERING
        MHlodScene::octree_thread_update((void*)update_info);
        update_state = UpdateState::LOAD_REST;
        #else
        thread_task_id = WorkerThreadPool::get_singleton()->add_native_task(&MHlodScene::octree_thread_update,(void*)update_info,true);
        #endif
    } else {
        octree->point_process_finished(oct_id);
    }
}

void MHlodScene::octree_thread_update(void* input){
    std::lock_guard<std::mutex> lock(MHlodScene::update_mutex);
    for(int i=0; i < all_hlod_scenes.size() ;++i){
        all_hlod_scenes[i]->procs_update_state.fill_false(); // set it to false and if then updated we set it back to true
    }
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
}

void MHlodScene::update_tick(double delta){
    if(update_state==UpdateState::OCTREE){
        return;
    }
    static double wait_time = 0;
    if(update_state==UpdateState::LOAD){
        #if !MHLODSCENE_THREAD_RENDERING
        if(WorkerThreadPool::get_singleton()->is_task_completed(thread_task_id)){
            wait_time = 0;
            WorkerThreadPool::get_singleton()->wait_for_task_completion(thread_task_id);
            update_state = UpdateState::LOAD_REST;
        }
        #endif
    } else if(update_state==UpdateState::LOAD_REST){
        wait_time += delta;
        if(wait_time >= load_rest_timeout){
            update_state = get_next_update_state(update_state);
        }
    } else if(update_state==UpdateState::UPDATE_STATE_MAX) {
        octree->point_process_finished(oct_id);
        update_state = UpdateState::OCTREE;
        #if MHLODSCENE_DEBUG_COUNT
        UtilityFunctions::print("--------- Count ------- ");
        UtilityFunctions::print("total_rendering_instance_count ",total_rendering_instance_count.load());
        UtilityFunctions::print("total_shape_count ",total_shape_count.load());
        UtilityFunctions::print("total_packed_scene_count ",total_packed_scene_count.load());
        #endif
    } else {
        apply_update(update_state);
        update_state = get_next_update_state(update_state);
    }
}

void MHlodScene::apply_update(UpdateState u_state){
    if(is_update_state_rendering(u_state)){
        if(ApplyInfoRendering::size()==0){
            return;
        }
        for(int i=0; i < ApplyInfoRendering::size(); i++){
            const ApplyInfoRendering& ainfo = ApplyInfoRendering::get(i);
            const MHlod::Type itype = ainfo.get_item()->type;
            if( (itype==MHlod::MESH && u_state!=UpdateState::APPLY_MESH) ||
                (itype==MHlod::DECAL && u_state!=UpdateState::APPLY_DECAL) ||
                (itype==MHlod::LIGHT && u_state!=UpdateState::APPLY_LIGHT)
                ) {
                    continue;
                }
            if(ainfo.is_remove()){
                RS->free_rid(ainfo.get_instance());
                #if MHLODSCENE_DEBUG_COUNT
                total_rendering_instance_count--;
                #endif
            } else {
                RS->instance_set_base(ainfo.get_instance(),ainfo.get_item()->get_rid());
            }
        }
        return;
    }
    if(is_update_state_physics(u_state)){
        for(int i=0; i < ApplyInfoPhysics::size(); i++){
            const ApplyInfoPhysics& ainfo = ApplyInfoPhysics::get(i);
            const MHlod::Type itype = ainfo.get_item()->type;
            if( (itype==MHlod::COLLISION && u_state!=UpdateState::APPLY_COLLISION) ||
                (itype==MHlod::COLLISION_COMPLEX && u_state!=UpdateState::APPLY_COLLISION_COMPLEX) ) {
                    continue;
            }
            MHlod::PhysicBodyInfo& body_info = MHlod::get_physic_body(ainfo.get_item()->get_physics_body());
            ERR_CONTINUE(!body_info.rid.is_valid());
            RID shape_rid = ainfo.get_item()->get_rid();
            ERR_CONTINUE(!shape_rid.is_valid());
            MHlod::Item* item = ainfo.get_item();
            Proc* proc = ainfo.get_proc();
            PhysicsServer3D::get_singleton()->body_add_shape(body_info.rid,shape_rid);
            #if MHLODSCENE_DEBUG_COUNT
            total_shape_count++;
            #endif
            PhysicsServer3D::get_singleton()->body_set_shape_transform(body_info.rid,body_info.shapes.size(),proc->get_item_transform(item));
            if(item->is_bound && proc->bind_item_get_disable(ainfo.get_gitem_id())){
                PhysicsServer3D::get_singleton()->body_set_shape_disabled(body_info.rid,body_info.shapes.size(),true);
            }
            body_info.shapes.push_back(ainfo.get_gitem_id().id); // should be at end
        }
    }
    if(u_state==UpdateState::APPLY_PACKED_SCENE){
        for(int i=0; i < ApplyInfoPackedScene::size(); i++){
            const ApplyInfoPackedScene& ainfo = ApplyInfoPackedScene::get(i);
            MHlod::Item* item = ainfo.get_item();
            Proc* proc = ainfo.get_proc();
            ERR_FAIL_COND(!proc->items_creation_info.has(item->transform_index));
            CreationInfo ci = proc->items_creation_info[item->transform_index];
            MHlodNode3D* hlod_node = item->get_hlod_node3d();
            ERR_FAIL_COND(hlod_node==nullptr);
            // Setting Packed Scene Variables
            hlod_node->global_id = ainfo.get_gitem_id();
            hlod_node->proc = ainfo.get_proc();
            for(int i=0;i<M_PACKED_SCENE_BIND_COUNT;i++){
                hlod_node->bind_items[i] = proc->get_item_global_id(item->packed_scene.bind_items[i]);
            }
            MHlodScene* scene = ainfo.get_proc()->scene;
            ci.root_node = hlod_node;
            proc->items_creation_info.insert(item->transform_index,ci);
            // Done
            scene->call_deferred("add_child",hlod_node);
            hlod_node->call_deferred("set_global_transform",proc->get_item_transform(item));
            hlod_node->call_deferred("_notify_update_lod",proc->lod);
        }
    }
    if(u_state==UpdateState::APPLY_CLEAR){
        ApplyInfoRendering::clear();
        ApplyInfoPhysics::clear();
        ApplyInfoPackedScene::clear();
        return;
    }
    if(u_state==UpdateState::REMOVE_USER){
        for(int i=0; i < removing_users.size(); i++){
            removing_users.ptrw()[i]->remove_user();
        }
        removing_users.clear();
        return;
    }
}

void MHlodScene::sleep(){
    std::lock_guard<std::mutex> lock(MHlodScene::update_mutex);
    if(is_sleep){
        return;
    }
    is_sleep = true;
    for(int i=0; i < all_hlod_scenes.size() ;++i){
        all_hlod_scenes[i]->deinit_proc();
    }
}

void MHlodScene::awake(){
    std::lock_guard<std::mutex> lock(MHlodScene::update_mutex);
    if(!is_sleep){
        return;
    }
    is_sleep = false;
    for(int i=0; i < all_hlod_scenes.size() ;++i){
        all_hlod_scenes[i]->init_proc();
    }
}

Array MHlodScene::get_hlod_users(const String& hlod_path){
    std::lock_guard<std::mutex> lock(MHlodScene::update_mutex);
    Array out;
    for(int i=0; i < all_hlod_scenes.size() ;++i){
        if( all_hlod_scenes[i]->main_hlod.is_valid() && all_hlod_scenes[i]->main_hlod->get_path() == hlod_path ){
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
        if(!pit->value->is_enable || !pit->value->is_visible){
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
    std::lock_guard<std::mutex> lock(update_mutex);
    all_hlod_scenes.insert(this);
    set_notify_transform(true);
}

MHlodScene::~MHlodScene(){
    std::lock_guard<std::mutex> mlock(update_mutex);
    deinit_proc();
    all_hlod_scenes.erase(this);
    if(all_hlod_scenes.size()==0){
        MHlod::clear_physic_body();
    }
}

void MHlodScene::set_is_hidden(bool input){
    if(input==is_hidden){
        return;
    }
    is_hidden = input;
    _update_visibility();
}

bool MHlodScene::is_init_scene() const {
    return is_init;
}

void MHlodScene::set_hlod(Ref<MHlod> input){
    std::lock_guard<std::mutex> mlock(update_mutex);
    if(is_init_procs()){
        deinit_proc();
    }
    procs.clear();
    main_hlod = input;
    if(main_hlod.is_valid() && !is_sleep && is_inside_tree()){
        init_proc();
    }
}

Ref<MHlod> MHlodScene::get_hlod() const {
    return main_hlod;
}

AABB MHlodScene::get_aabb() const{
    if(procs.size()==0 || procs[0].hlod.is_null()){
        return AABB();
    }
    return procs[0].hlod->get_aabb();
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
    {
        std::lock_guard<std::mutex> mlock(update_mutex);
        _update_visibility();
        if(main_hlod.is_valid()){
            init_proc();
        }
    }
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
    bool v = is_visible_in_tree() && is_inside_tree() && !is_hidden;
    get_root_proc()->set_visibility(v);
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

void MHlodScene::init_proc(){
    ERR_FAIL_COND(main_hlod.is_null());
    if(!is_inside_tree() || is_init_procs() || is_sleep){
        return;
    }
    get_root_proc()->hlod = main_hlod;
    procs.clear();
    Transform3D gtransform = get_global_transform();
    int checked_children_to_add_index = -1;
    // Adding root proc
    procs.push_back(Proc(this,main_hlod,0,scene_layers,gtransform));
    while (checked_children_to_add_index != procs.size() - 1)
    {
        ++checked_children_to_add_index;
        Ref<MHlod> current_hlod = procs.ptrw()[checked_children_to_add_index].hlod;
        ERR_CONTINUE(current_hlod.is_null());
        int sub_proc_size = current_hlod->sub_hlods.size();
        int sub_proc_index = procs.size();
        procs.ptrw()[checked_children_to_add_index].init_sub_proc(sub_proc_index,sub_proc_size,checked_children_to_add_index);
        // pushing back childrens
        for(int i=0; i < sub_proc_size; i++){
            Ref<MHlod> s = current_hlod->sub_hlods[i];
            ERR_FAIL_COND(s.is_null());
            uint16_t s_layers = current_hlod->sub_hlods_scene_layers[i];
            Transform3D s_transform = procs.ptrw()[checked_children_to_add_index].transform * current_hlod->sub_hlods_transforms[i];
            int32_t proc_id = sub_proc_index + i;
            procs.push_back(Proc(this,s,proc_id,s_layers,s_transform));
        }
    }
    // enabling procs, don't use recursive, important for ordering!
    for(int i=0; i < procs.size(); i++){
        procs.ptrw()[i].oct_point_id = get_free_oct_point_id();
        add_proc(procs.ptrw() + i,procs.ptrw()[i].oct_point_id);
        procs.ptrw()[i].enable(false);
    }
    // other stuff
    is_init = true;
}

void MHlodScene::deinit_proc(){
    #ifdef DEBUG_ENABLED
    if(cached_triangled_mesh.is_valid()){
        cached_triangled_mesh.unref();
    }
    #endif
    if(!is_init_procs()){
        return;
    }
    is_init = false;
    UpdateState _current_state = update_state;
    if(_current_state!=UpdateState::OCTREE){
        // only state above does not need a flush for apply update!
        while (_current_state!=UpdateState::UPDATE_STATE_MAX)
        {
            apply_update(_current_state);
            _current_state = get_next_update_state(_current_state);
        }
    }
    get_root_proc()->disable(true,true);
    // will remove eveything caused by get_root_proc()->disable(true,true);
    _current_state = get_next_update_state(UpdateState::LOAD_REST);
    while (_current_state!=UpdateState::UPDATE_STATE_MAX)
    {
        apply_update(_current_state);
        _current_state = get_next_update_state(_current_state);
    }
    if(update_state!=UpdateState::OCTREE){
        ERR_FAIL_COND(octree==nullptr);
        octree->point_process_finished(oct_id);
    }
    update_state = UpdateState::OCTREE;
    procs.clear();
}

#ifdef DEBUG_ENABLED
Ref<TriangleMesh> MHlodScene::get_triangle_mesh(){
    ERR_FAIL_COND_V(procs.size()==0,Ref<TriangleMesh>());
    ERR_FAIL_COND_V(procs[0].hlod.is_null(),Ref<TriangleMesh>());

    if(cached_triangled_mesh.is_valid()){
        return cached_triangled_mesh;
    }
    Ref<ArrayMesh> jmesh = procs[0].hlod->get_joined_mesh(false,false);
    ERR_FAIL_COND_V(jmesh.is_null(),Ref<TriangleMesh>());
    cached_triangled_mesh = jmesh->generate_triangle_mesh();
    return cached_triangled_mesh;
}
#endif