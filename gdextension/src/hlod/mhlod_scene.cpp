#include "mhlod_scene.h"

#include <godot_cpp/templates/hash_set.hpp>
#include <godot_cpp/classes/world3d.hpp>
#include <godot_cpp/classes/rendering_server.hpp>
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

    ClassDB::bind_static_method("MHlodScene",D_METHOD("sleep"), &MHlodScene::sleep);
    ClassDB::bind_static_method("MHlodScene",D_METHOD("awake"), &MHlodScene::awake);
    ClassDB::bind_static_method("MHlodScene",D_METHOD("get_hlod_users","hlod_path"), &MHlodScene::get_hlod_users);
}


void MHlodScene::CreationInfo::set_rid(const RID input){
    rid = input.get_id();
}

RID MHlodScene::CreationInfo::get_rid() const{
    /// As there is no way to set a RID value by integer we do this
    RID out;
    memcpy(&out,&rid,sizeof(RID));
    return out;
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

MHlodScene::Proc::Proc(){

}

MHlodScene::Proc::~Proc(){
    deinit();
    MHlodScene::remove_proc(oct_point_id);
}

void MHlodScene::Proc::change_transform(const Transform3D& new_transform){
    if(MHlodScene::octree!=nullptr && oct_point_id!=-1){
        MOctree::PointMoveReq mv_req(oct_point_id,MHlodScene::oct_id,transform.origin,new_transform.origin);
        MHlodScene::octree->add_move_req(mv_req);
    }
    transform = new_transform;
    update_all_transform();
    for(int i=0; i < sub_procs_size; i++){
        sub_proc_ptr[i].change_transform(new_transform*hlod->sub_hlods_transforms[i]);
    }
}

void MHlodScene::Proc::init(Vector<Proc>& sub_procs_arr,int& sub_proc_index,const Transform3D& _transform,uint16_t _scene_layers){
    if(is_init){
        return;
    }
    ERR_FAIL_COND(hlod.is_null());
    ERR_FAIL_COND(sub_proc_index+hlod->sub_hlods.size()>sub_procs_arr.size());
    scene_layers = _scene_layers;
    sub_proc_ptr = sub_procs_arr.ptrw() + sub_proc_index;
    sub_procs_size = hlod->sub_hlods.size();
    transform = _transform;
    oct_point_id = MHlodScene::add_proc(this,oct_point_id);
    // sub procs
    sub_proc_index += sub_procs_size;
    for(int i=0; i < sub_procs_size; i++){
        sub_proc_ptr[i].hlod = hlod->sub_hlods[i];
        sub_proc_ptr[i].hlod = hlod->sub_hlods_scene_layers[i];
        sub_proc_ptr[i].init(sub_procs_arr,sub_proc_index,transform*hlod->sub_hlods_transforms[i]);
    }
    is_init = true;
    // For now we ignore sub_hlod! later we will add them!
    if(hlod->sub_hlods.size()==0){
        return;
    }
}

void MHlodScene::Proc::deinit(){
    if(!is_init){
        return;
    }
    for(int i=0; i < sub_procs_size; i++){
        sub_proc_ptr[i].deinit();
    }
    remove_all_items(true); // this must come first
    is_init = false;
    sub_procs_size = 0;
    sub_proc_ptr = nullptr;
    MHlodScene::remove_proc(oct_point_id);
    items_creation_info.clear();
}

void MHlodScene::Proc::enable(){
    ERR_FAIL_COND(!is_init);
    if(is_enable){
        return;
    }
    is_enable = true;
    is_sub_proc_enable = true;
    oct_point_id = MHlodScene::add_proc(this,oct_point_id);
    for(int i=0; i < sub_procs_size; i++){
        sub_proc_ptr[i].enable();
    }
}

void MHlodScene::Proc::disable(){
    ERR_FAIL_COND(!is_init);
    if(!is_enable){
        return;
    }
    is_enable = false;
    is_sub_proc_enable = false;
    remove_all_items(false);
    MHlodScene::remove_proc(oct_point_id);
    for(int i=0; i < sub_procs_size; i++){
        sub_proc_ptr[i].disable();
    }
}

void MHlodScene::Proc::enable_sub_proc(){
    if(is_sub_proc_enable){
        return;
    }
    is_sub_proc_enable = true;
    for(int i=0; i < sub_procs_size; i++){
        sub_proc_ptr[i].enable();
    }
}

void MHlodScene::Proc::disable_sub_proc(){
    if(!is_sub_proc_enable){
        return;
    }
    is_sub_proc_enable = false;
    for(int i=0; i < sub_procs_size; i++){
        sub_proc_ptr[i].disable();
    }
}

void MHlodScene::Proc::add_item(MHlod::Item* item,const int item_id,const bool immediate){
    item->add_user(); // must be called here, this will load if it is not loaded
    // Item transform will be our transform * item_transform
    bool item_exist = false;
    CreationInfo ci;
    if(items_creation_info.has(item->transform_index)){
        ci = items_creation_info[item->transform_index];
        item_exist = true;
        if(ci.item_id==item_id){
            // nothing to do already exist
            return;
        }
    }
    switch (item->type)
    {
    case MHlod::Type::MESH:
        {
            RID mesh_rid = item->mesh.get_mesh();
            if(mesh_rid.is_valid()){
                RID instance;
                if(!item_exist){
                    instance = RS->instance_create();
                    RS->instance_set_scenario(instance,octree->get_scenario());
                    RS->instance_set_transform(instance,transform * hlod->transforms[item->transform_index]);
                    // in this case we need to insert this inside creation info as it changed
                    ci.set_rid(instance);
                    // Generating apply info
                    if(!is_visible){
                        RS->instance_set_visible(instance,false);
                    } else if(!immediate){
                        ApplyInfo ainfo(MHlod::Type::MESH,false);
                        ainfo.set_instance(instance);
                        apply_info.push_back(ainfo);
                        RS->instance_set_visible(instance,false);
                    }
                    RS->instance_set_base(instance,mesh_rid);
                } else {
                    // changing one instance mesh should not result in flickering
                    // if this happen later we should consider a change here
                    instance = ci.get_rid();
                    RS->instance_set_base(instance,mesh_rid);
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
    default:
        break;
    }
    ci.type = item->type;
    ci.item_id = item_id;
    items_creation_info.insert(item->transform_index,ci);
}

void MHlodScene::Proc::remove_item(MHlod::Item* item,const int item_id,const bool immediate){
    if(!items_creation_info.has(item->transform_index)){
        return;
    }
    CreationInfo c_info = items_creation_info[item->transform_index];
    switch (item->type)
    {
    case MHlod::Type::MESH:
        {
            RID instance = c_info.get_rid();
            ERR_FAIL_COND(!instance.is_valid());
            CreationInfo apply_creation_info;
            if(immediate){
                RS->free_rid(instance);
                item->remove_user();
            } else{
                ApplyInfo ainfo(MHlod::Type::MESH,true);
                ainfo.set_instance(instance);
                apply_info.push_back(ainfo);
            }
            items_creation_info.erase(item->transform_index);
        }
        break;
    default:
        break;
    }
}

_FORCE_INLINE_ void MHlodScene::Proc::update_item_transform(MHlod::Item* item){
    switch (item->type)
    {
    case MHlod::Type::MESH:
        {
            CreationInfo c_info = items_creation_info[item->transform_index];
            RID instance = c_info.get_rid();
            RS->instance_set_transform(instance,transform * hlod->transforms[item->transform_index]);
        }
        break;
    default:
        break;
    }
}

void MHlodScene::Proc::update_all_transform(){
    if(lod<0 || lod >= hlod->lods.size() || hlod->lods[lod].size() == 0){
        return; // Nothing to remove
    }
    VSet<int32_t> lod_table = hlod->lods[lod];
    for(int i=0; i < lod_table.size(); i++){
        ERR_FAIL_INDEX(lod_table[i],hlod->item_list.size());
        MHlod::Item* item = hlod->item_list.ptrw() + lod_table[i];
        update_item_transform(item);
    }
}

void MHlodScene::Proc::reload_meshes(const bool recursive){
    remove_all_items(true,false);
    int8_t __cur_lod = lod;
    lod = -1; // because update_lod function should know we don't have any mesh from before
    update_lod(__cur_lod, true);
    // Applying for sub proc
    if(recursive){
        for(int i=0; i < sub_procs_size; i++){
            sub_proc_ptr[i].reload_meshes();
        }
    }
}

void MHlodScene::Proc::remove_all_items(const bool immediate,const bool recursive){
    if(hlod.is_null()){
        return;
    }
    if(lod<0 || lod >= hlod->lods.size() || hlod->lods[lod].size() == 0){
        return; // Nothing to remove
    }
    VSet<int32_t> lod_table = hlod->lods[lod];
    for(int i=0; i < lod_table.size(); i++){
        ERR_FAIL_INDEX(lod_table[i],hlod->item_list.size());
        MHlod::Item* item = hlod->item_list.ptrw() + lod_table[i];
        remove_item(item,lod_table[i],immediate);
    }
    //sub procs
    if(recursive){
        for(int i=0; i < sub_procs_size; i++){
            sub_proc_ptr[i].remove_all_items(immediate);
        }
    }
}

// Will return if it is diry or not (has something to apply in the main game loop)
void MHlodScene::Proc::update_lod(int8_t c_lod,const bool immediate){
    ERR_FAIL_COND(oct_point_id==-1);
    ERR_FAIL_COND(octree==nullptr);
    if(hlod.is_null()){
        lod = c_lod;
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
        remove_all_items();
        lod = c_lod;
        return; // we don't consider this dirty as there is nothing to be appllied later
    }
    const VSet<int32_t>* lod_table = hlod->lods.ptr() + c_lod;
    VSet<int32_t> exist_transform_index;
    for(int i=0; i < (*lod_table).size(); i++){
        ERR_FAIL_INDEX(lod_table->operator[](i),hlod->item_list.size()); // maybe remove this check later
        MHlod::Item* item = hlod->item_list.ptrw() + (*lod_table)[i];
        if(item->item_layers!=0){
            bool lres = (item->item_layers & scene_layers)!=0;
            UtilityFunctions::print(item->item_layers," & ",scene_layers," -> ",lres);
        }
        if(item->item_layers==0 || (item->item_layers & scene_layers)!=0){ // Layers filter
            add_item(item,(*lod_table)[i],immediate);
            exist_transform_index.insert(item->transform_index);
        }
    }
    // Checking the last lod table
    // and remove items if needed
    if(lod<0 || lod >= hlod->lods.size() || hlod->lods[c_lod].size() == 0){
        // nothing to do just update lod and go out
        lod = c_lod;
        return;
    }
    const VSet<int32_t>* last_lod_table = hlod->lods.ptr() + lod;    
    for(int i=0; i < (*last_lod_table).size(); i++){
        MHlod::Item* last_item = hlod->item_list.ptrw() + (*last_lod_table)[i];
        if(last_item->item_layers==0 || (last_item->item_layers & scene_layers)!=0){ // Layers filter
            if(!exist_transform_index.has(last_item->transform_index)){
                remove_item(last_item,(*last_lod_table)[i],immediate);
            }
        }
    }
    lod = c_lod;
}

void MHlodScene::Proc::set_visibility(bool visibility){
    is_visible = visibility;
    for(HashMap<int32_t,CreationInfo>::Iterator it=items_creation_info.begin();it!=items_creation_info.end();++it){
        if(it->value.type == MHlod::Type::MESH){
            RS->instance_set_visible(it->value.get_rid(),visibility);
        }
    }
    for(int i=0; i < sub_procs_size; i++){
        sub_proc_ptr[i].set_visibility(visibility);
    }
}

/////////////////////////////////////////////////////
/// Static --> Proc Manager
/////////////////////////////////////////////////////
bool MHlodScene::is_sleep = false;
HashSet<MHlodScene*> MHlodScene::all_hlod_scenes;
HashMap<int32_t,MHlodScene::Proc*> MHlodScene::octpoints_to_proc;
MOctree* MHlodScene::octree = nullptr;
WorkerThreadPool::TaskID MHlodScene::thread_task_id;
std::mutex MHlodScene::update_mutex;
bool MHlodScene::is_updating = false;
bool MHlodScene::is_octree_inserted = false;
uint16_t MHlodScene::oct_id;
int32_t MHlodScene::last_oct_point_id = -1;
Vector<MHlodScene::ApplyInfo> MHlodScene::apply_info;
Vector<MHlod::Item*> MHlodScene::removing_users;


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

void MHlodScene::octree_update(const Vector<MOctree::PointUpdate>* update_info){
    if(update_info->size() > 0) {
        is_updating = true;
        thread_task_id = WorkerThreadPool::get_singleton()->add_native_task(&MHlodScene::octree_thread_update,(void*)update_info,true);
    } else {
        octree->point_process_finished(oct_id);
    }
}

void MHlodScene::octree_thread_update(void* input){
    std::lock_guard<std::mutex> lock(MHlodScene::update_mutex);
    apply_remove_item_users();
    const Vector<MOctree::PointUpdate>* update_info = (const Vector<MOctree::PointUpdate>*)input;
    for(int i=0; i < update_info->size(); i++){
        MOctree::PointUpdate p = update_info->get(i);
        if(!octpoints_to_proc.has(p.id)){
            continue;
        }
        Proc* _proc = octpoints_to_proc.get(p.id);
        _proc->update_lod(p.lod);
    }
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
    for(HashSet<MHlodScene*>::Iterator it=all_hlod_scenes.begin();it!=all_hlod_scenes.end();++it){
        (*it)->deinit_proc_no_lock();
    }
}

void MHlodScene::awake(){
    std::lock_guard<std::mutex> lock(MHlodScene::update_mutex);
    if(!is_sleep){
        return;
    }
    is_sleep = false;
    for(HashSet<MHlodScene*>::Iterator it=all_hlod_scenes.begin();it!=all_hlod_scenes.end();++it){
        (*it)->init_proc_no_lock();
    }
}

Array MHlodScene::get_hlod_users(const String& hlod_path){
    std::lock_guard<std::mutex> lock(MHlodScene::update_mutex);
    Array out;
    for(HashSet<MHlodScene*>::Iterator it=all_hlod_scenes.begin();it!=all_hlod_scenes.end();++it){
        if( (*it)->proc.hlod.is_valid() && (*it)->proc.hlod->get_path() == hlod_path ){
            out.push_back((*it));
        }
    }
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
    deinit_proc();
}

void MHlodScene::init_proc(){
    if(is_init_proc() || proc.hlod.is_null()){
        return;
    }
    std::lock_guard<std::mutex> lock(MHlodScene::update_mutex);
    if(is_sleep){
        return;
    }
    sub_procs.clear();
    sub_procs.clear();
    int sub_hlod_count = proc.hlod->get_sub_hlod_size_rec();
    sub_procs.resize(sub_hlod_count);
    UtilityFunctions::print("Sub hlod count ",sub_hlod_count);
    int sub_proc_index = 0;
    proc.init(sub_procs,sub_proc_index,get_global_transform(),scene_layers);
}

void MHlodScene::init_proc_no_lock(){
    if(is_init_proc() || proc.hlod.is_null()){
        return;
    }
    sub_procs.clear();
    sub_procs.clear();
    int sub_hlod_count = proc.hlod->get_sub_hlod_size_rec();
    sub_procs.resize(sub_hlod_count);
    UtilityFunctions::print("Sub hlod count ",sub_hlod_count);
    int sub_proc_index = 0;
    proc.init(sub_procs,sub_proc_index,get_global_transform());
}

void MHlodScene::deinit_proc(){
    if(!is_init_proc()){
        return;
    }
    std::lock_guard<std::mutex> lock(MHlodScene::update_mutex);
    flush();
    proc.deinit();
}

void MHlodScene::deinit_proc_no_lock(){
    if(!is_init_proc()){
        return;
    }
    flush();
    proc.deinit();
}

bool MHlodScene::is_init_proc(){
    return proc.is_init;
}

void MHlodScene::set_hlod(Ref<MHlod> input){
    if(proc.hlod.is_valid()){
        deinit_proc();
    }
    proc.hlod = input;
    if(proc.hlod.is_valid()){
        init_proc();
    }
}

Ref<MHlod> MHlodScene::get_hlod(){
    return proc.hlod;
}

void MHlodScene::set_scene_layers(int64_t input){
    scene_layers = input;
    if(is_init_proc()){
        std::lock_guard<std::mutex> lock(MHlodScene::update_mutex);
        proc.scene_layers = scene_layers;
        proc.reload_meshes(false);
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
            if(proc.is_init){
                std::lock_guard<std::mutex> lock(MHlodScene::update_mutex);
                proc.change_transform(get_global_transform());
            }
        }
        break;
    case NOTIFICATION_VISIBILITY_CHANGED:
        _update_visibility();
        break;
    case NOTIFICATION_READY:
        proc.hlod->start_test();
        break;
    case NOTIFICATION_ENTER_TREE:
        _update_visibility();
        if(is_inside_tree() && proc.hlod.is_valid()){
            std::lock_guard<std::mutex> lock(MHlodScene::update_mutex);
            init_proc();
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
    bool v = is_visible_in_tree() && is_inside_tree();
    proc.set_visibility(v);
}


Array MHlodScene::get_last_lod_mesh_ids_transforms(){
    Array out;
    ERR_FAIL_COND_V(!proc.is_init,out);
    for(int i=-1; i < sub_procs.size(); i++){
        const Proc* current_proc = i == -1 ? &proc : (sub_procs.ptr() + i);
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