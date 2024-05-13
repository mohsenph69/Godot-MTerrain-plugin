#include "moctmesh.h"

#include <godot_cpp/classes/rendering_server.hpp>
#define RS RenderingServer::get_singleton()
#include <godot_cpp/classes/world3d.hpp>

#include <godot_cpp/variant/utility_functions.hpp>

void MOctMesh::_bind_methods(){
    ClassDB::bind_method(D_METHOD("get_active_mesh"), &MOctMesh::get_active_mesh);

    ClassDB::bind_method(D_METHOD("set_mesh_lod","input"), &MOctMesh::set_mesh_lod);
    ClassDB::bind_method(D_METHOD("get_mesh_lod"), &MOctMesh::get_mesh_lod);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT,"mesh_lod",PROPERTY_HINT_RESOURCE_TYPE,"MMeshLod"),"set_mesh_lod","get_mesh_lod");

    ClassDB::bind_method(D_METHOD("_lod_mesh_changed"), &MOctMesh::_lod_mesh_changed);
}


///STATIC PART
WorkerThreadPool::TaskID MOctMesh::thread_task_id;
std::mutex MOctMesh::update_mutex;
bool MOctMesh::is_octtree_inserted = false;
bool MOctMesh::is_updating = false;
uint16_t MOctMesh::oct_id = 0;
int32_t MOctMesh::last_oct_point_id = OCT_POINT_ID_START;
HashMap<int32_t,MOctMesh*> MOctMesh::octpoint_to_octmesh;
MOctTree* MOctMesh::octtree = nullptr;


bool MOctMesh::is_my_octtree(MOctTree* input){
    return input == MOctMesh::octtree;
}

uint16_t MOctMesh::get_oct_id(){
    return oct_id;
}


bool MOctMesh::set_octtree(MOctTree* input){
    ERR_FAIL_COND_V(input==nullptr,false);
    UtilityFunctions::print("set oc tree ");
    if(octtree){
        WARN_PRINT("OctTree "+octtree->get_name()+" is already assigned! Only one OctTree can be assing to update MOctMesh!");
        return false;
    }
    octtree = input;
    if(octtree!=nullptr){
        oct_id = octtree->get_oct_id();
        // Here we insert all points
    }
    return true;
}

void MOctMesh::remove_octtree(MOctTree* input){
    if(input){
        UtilityFunctions::print("removing ocTtree");
    }
    if(input == octtree){
        octtree->remove_oct_id(oct_id);
        octtree = nullptr;
    }
}

void MOctMesh::insert_points(){
    ERR_FAIL_COND(octtree==nullptr);
    is_octtree_inserted = true;
    PackedVector3Array points_pos;
    PackedInt32Array points_ids;
    for(HashMap<int32_t,MOctMesh*>::Iterator it=octpoint_to_octmesh.begin();it!=octpoint_to_octmesh.end();++it){
        points_ids.push_back(it->key);
        points_pos.push_back(it->value->get_global_position());
        it->value->oct_position = it->value->get_global_position();
    }
    octtree->insert_points(points_pos,points_ids,oct_id);
}

int32_t MOctMesh::add_octmesh(MOctMesh* input){
    std::lock_guard<std::mutex> lock(update_mutex);
    last_oct_point_id++;
    if(octtree!=nullptr && is_octtree_inserted){
        bool res = octtree->insert_point(input->get_global_position(),last_oct_point_id,oct_id);
        ERR_FAIL_COND_V_MSG(!res,INVALID_OCT_POINT_ID,"Single point can't be inserted!");
    }
    input->oct_position = input->get_global_position();
    octpoint_to_octmesh.insert(last_oct_point_id,input);
    return last_oct_point_id;
}

void MOctMesh::remove_octmesh(int32_t id){
    std::lock_guard<std::mutex> lock(update_mutex);
    ERR_FAIL_COND(!octpoint_to_octmesh.has(id));
    MOctMesh* m = octpoint_to_octmesh[id];
    m->oct_point_id = INVALID_OCT_POINT_ID;
    octpoint_to_octmesh.erase(id);
    if(octtree!=nullptr && is_octtree_inserted){
        octtree->remove_point(id,m->oct_position,oct_id);
    }
}

void MOctMesh::move_octmesh(int32_t id,Vector3 old_pos,Vector3 new_pos){
    if(octtree && is_octtree_inserted){
        octtree->add_move_req(MOctTree::PointMoveReq(id,oct_id,old_pos,new_pos));
    }
}

void MOctMesh::octtree_update(const Vector<MOctTree::PointUpdate>* update_info){
    if(update_info->size() > 0) {
        is_updating = true;
        thread_task_id = WorkerThreadPool::get_singleton()->add_native_task(&MOctMesh::octtree_thread_update,(void*)update_info,true);
    } else {
        octtree->point_process_finished(oct_id);
    }
}

void MOctMesh::octtree_thread_update(void* input){
    const Vector<MOctTree::PointUpdate>* update_info = (const Vector<MOctTree::PointUpdate>*)input;
    for(int i=0; i < update_info->size(); i++){
        std::lock_guard<std::mutex> lock(MOctMesh::update_mutex);
        MOctTree::PointUpdate p = update_info->get(i);
        if(!octpoint_to_octmesh.has(p.id)){
            continue;
        }
        MOctMesh* oct_mesh = octpoint_to_octmesh.get(p.id);
        ERR_CONTINUE(!UtilityFunctions::is_instance_valid(oct_mesh));
        oct_mesh->update_lod_mesh(p.lod);
    }
}

void MOctMesh::update_tick(){
    if(is_updating){
        if(WorkerThreadPool::get_singleton()->is_task_completed(thread_task_id)){
            ERR_FAIL_COND(octtree==nullptr);
            is_updating = false;
            octtree->point_process_finished(oct_id);
        }
    }
    
}

/////////////////////////////////////////////////////////////////
//FINISH STATIC PART
////////////////////////////////////////////////////////////////

void MOctMesh::_update_visibilty(){
    update_mutex.lock();
    if(!is_inside_tree()){
        update_mutex.unlock();
        return;
    }
    if(instance.is_valid()){
        RS->instance_set_visible(instance,is_visible_in_tree());
    }
    update_mutex.unlock();
}
#include <stdio.h>
MOctMesh::MOctMesh(){
    set_notify_transform(true);
}

MOctMesh::~MOctMesh(){
    MOctMesh::remove_octmesh(oct_point_id);
}

// -2 means update current mesh without changing LOD
void MOctMesh::update_lod_mesh(int8_t new_lod){
    if(new_lod!=-2){
        lod.store(new_lod,std::memory_order_relaxed);
    }
    RID new_mesh_rid ;
    if(mesh_lod.is_valid()){
        new_mesh_rid = mesh_lod->get_mesh_rid(lod);
    } else {
        new_mesh_rid = RID();
    }
    if(new_mesh_rid == current_mesh){
        return;
    }
    current_mesh = new_mesh_rid;
    if(current_mesh.is_valid()){
        if(!instance.is_valid()){
            RID created_instance = RS->instance_create();
            RS->instance_attach_object_instance_id(created_instance,get_instance_id());
            instance = created_instance;
            RID scenario = MOctMesh::octtree->get_scenario();
            RS->instance_set_scenario(instance,scenario);
            RS->instance_set_transform(instance, get_global_transform());
        }
        RS->instance_set_base(instance,current_mesh);
        
    } else {
        if(instance.is_valid()){
            RS->free_rid(instance);
            instance = RID();
        }
    }
    call_deferred("update_gizmos");
}

Ref<Mesh> MOctMesh::get_active_mesh(){
    if(mesh_lod.is_valid()){
        int8_t clod = lod.load(std::memory_order_relaxed);
        return mesh_lod->get_mesh(clod);
    }
    Ref<Mesh> out;
    return out;
}


void MOctMesh::set_mesh_lod(Ref<MMeshLod> input){
    if(mesh_lod.is_valid()){
        mesh_lod->disconnect("meshes_changed", Callable(this,"_lod_mesh_changed"));
    }
    if(input.is_valid()){
        input->connect("meshes_changed", Callable(this,"_lod_mesh_changed"));
    }
    mesh_lod = input;
    std::lock_guard<std::mutex> lock(MOctMesh::update_mutex);
    update_lod_mesh();
}

Ref<MMeshLod> MOctMesh::get_mesh_lod(){
    return mesh_lod;
}


bool MOctMesh::has_valid_oct_point_id(){
    return oct_point_id != INVALID_OCT_POINT_ID;
}

void MOctMesh::_notification(int p_what){
    switch (p_what)
    {
    case NOTIFICATION_TRANSFORM_CHANGED:
        update_mutex.lock();
        if(oct_position!=get_global_position()){
            MOctMesh::move_octmesh(oct_point_id,oct_position,get_global_position());
            oct_position = get_global_position();
        }
        if(instance.is_valid()){
            RS->instance_set_transform(instance, get_global_transform());
        }
        update_mutex.unlock();
        break;
    case NOTIFICATION_EXIT_WORLD:
        update_mutex.lock();
        if(is_inside_tree() && instance.is_valid()){
            RS->instance_set_visible(instance,false);
        }
        update_mutex.unlock();
        break;
    case NOTIFICATION_ENTER_WORLD:
        _update_visibilty();
        break;
    case NOTIFICATION_VISIBILITY_CHANGED:
        _update_visibilty();
        break;
    case NOTIFICATION_ENTER_TREE:
        if(!has_valid_oct_point_id()){
            oct_point_id = MOctMesh::add_octmesh(this);
        }
        break;
    case NOTIFICATION_EXIT_TREE:
        if(has_valid_oct_point_id()){
            MOctMesh::remove_octmesh(oct_point_id);
        }
    default:
        break;
    }
}

void MOctMesh::_lod_mesh_changed(){
    std::lock_guard<std::mutex> lock(MOctMesh::update_mutex);
    update_lod_mesh();
}