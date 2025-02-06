#include "masset_mesh.h"

#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/world3d.hpp>
#include "../hlod/mhlod.h"
#include "mmesh_joiner.h"
#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/file_access.hpp>

#define RS RenderingServer::get_singleton()


void MAssetMeshData::_bind_methods(){
    ClassDB::bind_method(D_METHOD("get_material_set_id"), &MAssetMeshData::get_material_set_ids);
    ClassDB::bind_method(D_METHOD("get_transform"), &MAssetMeshData::get_transform);
    ClassDB::bind_method(D_METHOD("get_global_transform"), &MAssetMeshData::get_global_transform);
    ClassDB::bind_method(D_METHOD("get_mesh_lod"), &MAssetMeshData::get_mesh_lod);
    ClassDB::bind_method(D_METHOD("get_item_ids"), &MAssetMeshData::get_item_ids);
    ClassDB::bind_method(D_METHOD("get_complex_shape_id"), &MAssetMeshData::get_complex_shape_id);

    ClassDB::bind_method(D_METHOD("get_last_valid_lod"), &MAssetMeshData::get_last_valid_lod);
    ClassDB::bind_method(D_METHOD("get_last_valid_mesh"), &MAssetMeshData::get_last_valid_mesh);

    ClassDB::bind_method(D_METHOD("get_collision_count"), &MAssetMeshData::get_collision_count);
    ClassDB::bind_method(D_METHOD("get_collision_type","index"), &MAssetMeshData::get_collision_type);
    ClassDB::bind_method(D_METHOD("get_collision_params","index"), &MAssetMeshData::get_collision_params);
    ClassDB::bind_method(D_METHOD("get_collision_transform","index"), &MAssetMeshData::get_collision_transform);
}

PackedInt32Array MAssetMeshData::get_material_set_ids() const{
    // should be material_set_id just in case a mesh does not have the set we use 0 set_id for that
    PackedInt32Array out;
    for(int i=0; i < mesh_lod.size(); i++){
        int set_id = 0;
        Ref<MMesh> mm = mesh_lod[i];
        if(mm.is_valid() && material_set_id < mm->material_set_get_count()){
            set_id = material_set_id;
        }
        out.push_back(set_id);
    }
    return out;
}

Transform3D MAssetMeshData::get_transform() const{
    return transform;
}

Transform3D MAssetMeshData::get_global_transform() const{
    return global_transform;
}

TypedArray<MMesh> MAssetMeshData::get_mesh_lod() const{
    return mesh_lod;
}

PackedInt32Array MAssetMeshData::get_item_ids() const{
    return item_ids;
}

int32_t MAssetMeshData::get_complex_shape_id(){
    int32_t main_mesh_id = -1;
    PackedInt32Array ids = get_item_ids();
    for(int32_t id : ids){
        if (id!=-1){
            main_mesh_id = MAssetTable::mesh_item_get_first_lod(id);
        }
    }
    if(main_mesh_id==-1){
        return -1;
    }
    String shape_path = MHlod::get_collsion_path(main_mesh_id);
    if(FileAccess::file_exists(shape_path)){
        return main_mesh_id;
    }
    return -1;
}

int8_t MAssetMeshData::get_last_valid_lod() const{
    for(int i=mesh_lod.size()-1;i>=0;i--){
        Ref<MMesh> m = mesh_lod[i];
        if(m.is_valid()){
            return i;
        }
    }
    return -1;
}

Ref<MMesh> MAssetMeshData::get_last_valid_mesh() const{
    for(int i=mesh_lod.size()-1;i>=0;i--){
        Ref<MMesh> m = mesh_lod[i];
        if(m.is_valid()){
            return m;
        }
    }
    return Ref<MMesh>();
}

int MAssetMeshData::get_collision_count() const{
    return collision_data.collision_shapes.size();
}

MAssetTable::CollisionType MAssetMeshData::get_collision_type(int index) const{
    ERR_FAIL_INDEX_V(index,get_collision_count(),MAssetTable::CollisionType::UNDEF);
    return collision_data.collision_shapes[index].type;
}

Vector3 MAssetMeshData::get_collision_params(int index) const{
    ERR_FAIL_INDEX_V(index,get_collision_count(),Vector3());
    Vector3 params;
    params.x = collision_data.collision_shapes[index].param_1;
    params.y = collision_data.collision_shapes[index].param_2;
    params.z = collision_data.collision_shapes[index].param_3;
    return params;
}

Transform3D MAssetMeshData::get_collision_transform(int index) const{
    ERR_FAIL_INDEX_V(index,get_collision_count(),Transform3D());
    return global_transform * collision_data.collision_shapes_transforms[index];
}

void MAssetMesh::InstanceData::update_material(int set_id,int8_t _active_mesh_index){
    // No use of User in MMesh direct Material load
    material_set_id = set_id;
    materials.clear();
    active_mesh_index = _active_mesh_index;
    if(active_mesh_index < 0 || !instance_rid.is_valid()){
        return;
    }
    Ref<MMesh> active_mesh = meshes[active_mesh_index];
    if(active_mesh.is_null() || active_mesh->material_set_get_count()==1){
        return;
    }
    int new_set_id = 0;
    if(set_id < active_mesh->material_set_get_count()){
        new_set_id = set_id;
    }
    PackedStringArray material_sets_path = active_mesh->material_set_get(new_set_id);
    for(int s=0; s < material_sets_path.size(); s++){
        if(material_sets_path[s].is_empty()){
            continue;
        }
        Ref<Material> smat = ResourceLoader::get_singleton()->load(material_sets_path[s]);
        materials.push_back(smat);
        if(smat.is_valid()){
            RS->instance_set_surface_override_material(instance_rid,s,smat->get_rid());
        }
    }
}

Ref<MMesh> MAssetMesh::InstanceData::get_last_valid_mesh() const {
    for(int i=meshes.size()-1;i>=0;i--){
        Ref<MMesh> m = meshes[i];
        if(m.is_valid()){
            return m;
        }
    }
    return Ref<MMesh>();
}

Ref<MMesh> MAssetMesh::InstanceData::get_first_valid_mesh() const{
    for(int i=0;i<meshes.size();i++){
        Ref<MMesh> m = meshes[i];
        if(m.is_valid()){
            return m;
        }
    }
    return Ref<MMesh>();
}

int8_t MAssetMesh::InstanceData::get_mesh_index_last(int lod) const{
    if(lod < 0 || meshes.size()==0){
        return -1;
    }
    lod = lod >= meshes.size() ? meshes.size() - 1 : lod;
    return lod;
}

RID MAssetMesh::InstanceData::get_mesh_rid_last(int lod) const{
    if(lod < 0 || meshes.size()==0){
        return RID();
    }
    lod = lod >= meshes.size() ? meshes.size() - 1 : lod;
    Ref<MMesh> mmesh = meshes[lod];
    if(mmesh.is_valid()){
        return mmesh->get_mesh_rid();
    }
    return RID();
}

Ref<MMesh> MAssetMesh::InstanceData::get_mesh_last(int lod) const{
    if(lod < 0 || meshes.size()==0){
        return Ref<MMesh>();
    }
    lod = lod >= meshes.size() ? meshes.size() - 1 : lod;
    return meshes[lod];
}

VSet<MAssetMesh*> MAssetMesh::asset_mesh_node_list;

void MAssetMesh::_bind_methods(){
    ClassDB::bind_method(D_METHOD("update_instance_date"), &MAssetMesh::update_instance_date);
    ClassDB::bind_method(D_METHOD("update_lod","lod"), &MAssetMesh::update_lod);
    ClassDB::bind_method(D_METHOD("has_collsion"), &MAssetMesh::has_collsion);

    ClassDB::bind_method(D_METHOD("set_disable_collision","input"), &MAssetMesh::set_disable_collision);
    ClassDB::bind_method(D_METHOD("get_disable_collision"), &MAssetMesh::get_disable_collision);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL,"disable_collision"),"set_disable_collision","get_disable_collision");

    ClassDB::bind_method(D_METHOD("set_lod_cutoff","input"), &MAssetMesh::set_lod_cutoff);
    ClassDB::bind_method(D_METHOD("get_lod_cutoff"), &MAssetMesh::get_lod_cutoff);
    ADD_PROPERTY(PropertyInfo(Variant::INT,"lod_cutoff"),"set_lod_cutoff","get_lod_cutoff");

    ClassDB::bind_method(D_METHOD("set_hlod_layers","input"), &MAssetMesh::set_hlod_layers);
    ClassDB::bind_method(D_METHOD("get_hlod_layers"), &MAssetMesh::get_hlod_layers);
    ADD_PROPERTY(PropertyInfo(Variant::INT,"hlod_layers"),"set_hlod_layers","get_hlod_layers");

    ClassDB::bind_method(D_METHOD("get_collection_name"), &MAssetMesh::get_collection_name);
    ClassDB::bind_method(D_METHOD("set_collection_name","input"), &MAssetMesh::set_collection_name);

    ClassDB::bind_method(D_METHOD("get_glb_id"), &MAssetMesh::get_glb_id);
    ClassDB::bind_method(D_METHOD("set_glb_id","input"), &MAssetMesh::set_glb_id);
    
    ADD_PROPERTY(PropertyInfo(Variant::INT,"_glb_id"),"set_glb_id","get_glb_id");
    ADD_PROPERTY(PropertyInfo(Variant::STRING,"_collection_name"),"set_collection_name","get_collection_name");

    ClassDB::bind_method(D_METHOD("get_collection_id"), &MAssetMesh::get_collection_id);
    ClassDB::bind_method(D_METHOD("set_collection_id","input"), &MAssetMesh::set_collection_id);
    ADD_PROPERTY(PropertyInfo(Variant::INT,"collection_id",PROPERTY_HINT_NONE,"",PROPERTY_USAGE_EDITOR),"set_collection_id","get_collection_id");

    ClassDB::bind_method(D_METHOD("_get_collection_identifier"), &MAssetMesh::get_collection_identifier);
    ClassDB::bind_method(D_METHOD("_set_collection_identifier","input"), &MAssetMesh::set_collection_identifier);
    ADD_PROPERTY(PropertyInfo(Variant::ARRAY,"_collection_identifier",PROPERTY_HINT_NONE,"",PROPERTY_USAGE_STORAGE),"_set_collection_identifier","_get_collection_identifier");

    ClassDB::bind_method(D_METHOD("get_collections_material_set"), &MAssetMesh::get_collections_material_set);
    ClassDB::bind_method(D_METHOD("set_collections_material_set","input"), &MAssetMesh::set_collections_material_set);
    ADD_PROPERTY(PropertyInfo(Variant::DICTIONARY,"_collections_material_set",PROPERTY_HINT_NONE,"",PROPERTY_USAGE_STORAGE),"set_collections_material_set","get_collections_material_set");

    ClassDB::bind_method(D_METHOD("get_collection_material_set","collection_id"), &MAssetMesh::get_collection_material_set);
    ClassDB::bind_method(D_METHOD("set_collection_material_set","collection_id","set_id"), &MAssetMesh::set_collection_material_set);

    ClassDB::bind_method(D_METHOD("get_collection_ids"), &MAssetMesh::get_collection_ids);

    ClassDB::bind_method(D_METHOD("_update_visibility"), &MAssetMesh::_update_visibility);

    ClassDB::bind_method(D_METHOD("get_mesh_data"), &MAssetMesh::get_mesh_data);

    ClassDB::bind_method(D_METHOD("get_joined_aabb"), &MAssetMesh::get_joined_aabb);
    ClassDB::bind_method(D_METHOD("get_joined_triangle_mesh"), &MAssetMesh::get_joined_triangle_mesh);

    ClassDB::bind_method(D_METHOD("get_merged_mesh","lowest_lod"), &MAssetMesh::get_merged_mesh);
    ClassDB::bind_static_method("MAssetMesh",D_METHOD("get_collection_merged_mesh","collection_id","lowest_lod"),&MAssetMesh::get_collection_merged_mesh);
    ClassDB::bind_static_method("MAssetMesh",D_METHOD("refresh_all_masset_nodes"),&MAssetMesh::refresh_all_masset_nodes);
}

void MAssetMesh::refresh_all_masset_nodes(){
    for(int i=0; i < asset_mesh_node_list.size(); i++){
        asset_mesh_node_list[i]->update_instance_date();
    }
}

MAssetMesh::MAssetMesh(){
    set_notify_transform(true);
    connect("tree_exited",Callable(this,"_update_visibility"));
    connect("tree_entered",Callable(this,"_update_visibility"));
    asset_mesh_node_list.insert(this);
}

MAssetMesh::~MAssetMesh(){
    remove_instances(true);
    asset_mesh_node_list.erase(this);
}

void MAssetMesh::generate_instance_data(int collection_id,const Transform3D& transform){
    Ref<MAssetTable> asset_table = MAssetTable::get_singleton();
    ERR_FAIL_COND(asset_table.is_null());
    /////////////////////
    ///// Mesh Item ////
    ////////////////////
    int item_id = asset_table->collection_get_item_id(collection_id);
    if(item_id!=-1){
        InstanceData idata;
        idata.collection_id = collection_id;
        idata.local_transform = transform;
        idata.meshes = MAssetTable::mesh_item_meshes(item_id);
        idata.item_ids = MAssetTable::mesh_item_ids(item_id);
        idata.collission_data = asset_table->collection_get_collision_data(collection_id);
        for(int k=0; k < idata.collission_data.collision_shapes.size();k++){
            Transform3D t = transform * idata.collission_data.collision_shapes_transforms[k];
            idata.collission_data.collision_shapes_transforms.set(k,t);
        }
        instance_data.push_back(idata);
    }
    /////////////////////
    ///// collections ///
    /////////////////////
    Vector<Pair<int,Transform3D>> sub_collections = asset_table->collection_get_sub_collection_id_transform(collection_id);
    for(const Pair<int,Transform3D>& collection : sub_collections){
        generate_instance_data(collection.first,transform * collection.second);
    }
}

void MAssetMesh::update_instance_date(){
    if(collection_identifier.is_null()){ // NULL STATE
        collection_id == -1;
        return;
    }
    Ref<MAssetTable> at = MAssetTable::get_singleton();
    ERR_FAIL_COND(at.is_null());
    remove_instances(true);
    collection_id = at->collection_get_id_by_identifier(collection_identifier);
    if(collection_id < 0){ // invalid state
        collection_id = -2;
        UtilityFunctions::print("Invalid state ",collection_id);
        return;
    }
    Transform3D t; // Identity Transform
    generate_instance_data(collection_id,t);
    compute_joined_aabb();
    update_material_sets_from_data();
    notify_property_list_changed();
}

void MAssetMesh::update_lod(int lod){
    current_lod = lod;
    if(lod_cutoff>=0 && lod >= lod_cutoff){
        remove_instances(false);
        return;
    }
    bool is_visible = is_visible_in_tree() && is_inside_tree();
    for(InstanceData& data : instance_data){
        ERR_CONTINUE(data.meshes.size()==0);
        RID mesh_rid = data.get_mesh_rid_last(lod);
        Ref<MMesh> mmesh = data.get_mesh_last(lod);
        if(mesh_rid == data.mesh_rid){
            continue;
        }
        if(!mesh_rid.is_valid() && data.mesh_rid.is_valid()){ // Remove
            RS->free_rid(data.instance_rid);
            data.mesh_rid = RID();
            data.instance_rid = RID();
            if(data.current_mmesh.is_valid()){
                if(data.material_set_user_added){
                    data.current_mmesh->remove_user(data.material_set_id);
                }
            } else {
                WARN_PRINT("current_mmesh is not valid for removing user");
            }
            data.current_mmesh = Ref<MMesh>();
            data.update_material(data.material_set_id,-1);
            continue;
        }
        if(mesh_rid.is_valid() && !data.mesh_rid.is_valid()){ // create
            data.instance_rid = RS->instance_create();
            instance_count++;
            RS->instance_set_scenario(data.instance_rid,get_world_3d()->get_scenario());
            RS->instance_set_transform(data.instance_rid,get_global_transform() * data.local_transform);
            RS->instance_set_visible(data.instance_rid,is_visible);
        } // create finish or update
        // First set mesh and then material override important
        data.mesh_rid = mesh_rid;
        RS->instance_set_base(data.instance_rid,mesh_rid);
        // Removing user for old mmesh
        if(data.current_mmesh.is_valid() && data.material_set_user_added){
            data.current_mmesh->remove_user(data.material_set_id);
        }
        // Setting material override
        if(mmesh.is_valid() && mmesh->has_material_override() && data.material_set_id >= 0){
            Vector<RID> material_rids;
            mmesh->get_materials_add_user(data.material_set_id,material_rids);
            for(int i=0; i < material_rids.size(); i++){
                RS->instance_set_surface_override_material(data.instance_rid,i,material_rids[i]);
            }
            data.material_set_user_added = true;
        }
        data.current_mmesh = mmesh;
        data.update_material(data.material_set_id,data.get_mesh_index_last(lod));
        /// Later we add material here
    }
}

void MAssetMesh::destroy_meshes(){
    remove_instances(false);
}

void MAssetMesh::compute_joined_aabb(){
    joined_aabb = AABB();
    bool is_first_set = false;
    for(int i=0; i < instance_data.size(); i++){
        for(int j=0; j < instance_data[i].meshes.size(); j++){
            Ref<MMesh> __mmesh = instance_data[i].meshes[j];
            if(__mmesh.is_valid()){
                if(!is_first_set){
                    joined_aabb = __mmesh->get_aabb();
                    is_first_set = true;
                } else {
                    joined_aabb.merge_with(joined_aabb);
                }
                break;
            }
        }
    }
}

bool MAssetMesh::has_collsion() const{
    for(const InstanceData& data : instance_data){
        if(data.collission_data.collision_shapes.size()!=0){
            return true;
        }
    }
    return false;
}

void MAssetMesh::set_disable_collision(bool input){
    disable_collision = input;
}

bool MAssetMesh::get_disable_collision() const{
    return disable_collision;
}

void MAssetMesh::remove_instances(bool hard_remove){
    for(InstanceData& data : instance_data){
        if(data.instance_rid.is_valid()){
            if(data.current_mmesh.is_valid()){
                if(data.material_set_user_added){
                    data.update_material(data.material_set_id,-1);
                }
            } else {
                WARN_PRINT("ata.current_mmesh is not valid for removing user");
            }
            RS->free_rid(data.instance_rid);
            data.instance_rid = RID();
            data.mesh_rid = RID();
            instance_count--;
        }
    }
    if(hard_remove){
        joined_triangle_mesh.unref();
        joined_aabb = AABB();
        instance_data.clear();
    }
}

void MAssetMesh::set_hlod_layers(int64_t input){
    hlod_layers = input;
}

int64_t MAssetMesh::get_hlod_layers() const {
    return hlod_layers;
}

void MAssetMesh::set_lod_cutoff(int input){
    lod_cutoff = input;
    update_lod(current_lod);
}

int MAssetMesh::get_lod_cutoff(){
    return lod_cutoff;
}

void MAssetMesh::set_collection_id_no_lod_update(int input){
    Ref<MAssetTable> at = MAssetTable::get_singleton();
    ERR_FAIL_COND(at.is_null());
    collection_id = input;
    if(collection_id>=0){
        collection_identifier = at->collection_get_identifier(collection_id);
    }
    update_instance_date();
}

void MAssetMesh::set_collection_id(int input){
    if(input<0 || collection_id==-2){ // Invalid mode
        return;
    }
    collection_id = input;
    Ref<MAssetTable> at = MAssetTable::get_singleton();
    ERR_FAIL_COND(at.is_null());
    if(collection_id>=0){
        collection_identifier = at->collection_get_identifier(collection_id);
    }
    if(is_inside_tree()){
        update_instance_date();
        update_lod(current_lod);
        update_gizmos();
    }
}

int MAssetMesh::get_collection_id(){
    return collection_id;
}

void MAssetMesh::set_collection_identifier(const Array& info){
    ERR_FAIL_COND(info.size()!=2);
    collection_identifier.glb_id = info[0];
    collection_identifier.name = info[1];
    if(is_inside_tree()){
        update_instance_date();
        update_lod(current_lod);
        update_gizmos();
    }
}

Array MAssetMesh::get_collection_identifier(){
    Array out;
    out.resize(2);
    out[0] = collection_identifier.glb_id;
    out[1] = collection_identifier.name;
    return out;
}

void MAssetMesh::set_glb_id(int32_t _glb_id){
    if(is_inside_tree()){
        return;
    }
    glb_id = _glb_id;
}

int32_t MAssetMesh::get_glb_id(){
    return glb_id;
}

void MAssetMesh::set_collection_name(const String& input){
    if(is_inside_tree()){
        return;
    }
    collection_name = input;
}

String MAssetMesh::get_collection_name(){
    return collection_name;
}

PackedInt32Array MAssetMesh::get_collection_ids() const {
    PackedInt32Array out;
    for(const InstanceData& idata : instance_data){
        if(idata.meshes.size()>0){
            out.push_back(idata.collection_id);
        }
    }
    return out;
}

int MAssetMesh::get_collection_material_set(int collection_id) const{
    if(collections_material_set.has(collection_id)){
        return collections_material_set[collection_id];
    }
    return 0;
}

void MAssetMesh::set_collection_material_set(int collection_id, int material_set){
    if(material_set==0){
        collections_material_set.erase(collection_id); // back to default
    } else {
        collections_material_set[collection_id] = material_set;
    }
    for(InstanceData& idata : instance_data){
        if(idata.collection_id == collection_id){
            idata.update_material(material_set,idata.active_mesh_index);
            // don't put break here we can have multiple collection with same ID
        }
    }
}

void MAssetMesh::update_material_sets_from_data(){
    for(InstanceData& idata : instance_data){
        if(collections_material_set.has(idata.collection_id)){
            idata.update_material(collections_material_set[idata.collection_id],idata.active_mesh_index);
        }
    }
    notify_property_list_changed();
}

void MAssetMesh::set_collections_material_set(Dictionary data){
    collections_material_set = data;
    update_material_sets_from_data();
}

Dictionary MAssetMesh::get_collections_material_set() const {
    return collections_material_set;
}

void MAssetMesh::_update_position(){
    Transform3D gtransform = get_global_transform();
    for(InstanceData& data : instance_data){
        if(data.instance_rid.is_valid()){
            RS->instance_set_transform(data.instance_rid,gtransform * data.local_transform);
        }
    }
}

void MAssetMesh::_update_visibility(){
    bool is_visible = is_visible_in_tree() && is_inside_tree();
    for(InstanceData& data : instance_data){
        if(data.instance_rid.is_valid()){
            RS->instance_set_visible(data.instance_rid,is_visible);
        }
    }
}

void MAssetMesh::_notification(int32_t what){
    switch (what)
    {
    case NOTIFICATION_TRANSFORM_CHANGED:
        _update_position();
        break;
    case NOTIFICATION_VISIBILITY_CHANGED:
        _update_visibility();
        break;
    case NOTIFICATION_READY:
        update_instance_date();
        break;
    default:
        break;
    }
}

void MAssetMesh::_get_property_list(List<PropertyInfo> *p_list) const{
    for(const InstanceData& idata : instance_data){
        if(idata.meshes.size()==0){
            continue;
        }
        String prop_name;
        if(idata.collection_id == collection_id){
            prop_name = "material_set";
        } else {
            prop_name = String("Sub_Collections_material_set/") + itos(idata.collection_id);
        }
        p_list->push_back(PropertyInfo(Variant::INT,prop_name,PROPERTY_HINT_RANGE,"0,128"));
    }
}

bool MAssetMesh::_get(const StringName &p_name, Variant &r_ret) const{
    int _u_collection_id = -1;
    if(p_name==String("material_set")){
        _u_collection_id = collection_id;
    }
    else if(p_name.begins_with("Sub_Collections_material_set/")){
        _u_collection_id = p_name.replace("Sub_Collections_material_set/","").to_int();
    }
    if(_u_collection_id!=-1){
        r_ret = get_collection_material_set(_u_collection_id);
        return r_ret;
    }
    return false;
}

bool MAssetMesh::_set(const StringName &p_name, const Variant &p_value){
    int _u_collection_id = -1;
    if(p_name==String("material_set")){
        _u_collection_id = collection_id;
    }
    if(p_name.begins_with("Sub_Collections_material_set/")){
        _u_collection_id = p_name.replace("Sub_Collections_material_set/","").to_int();
    }
    if(_u_collection_id!=-1){
        set_collection_material_set(_u_collection_id,p_value);
        return true;
    }
    return false;
}


TypedArray<MAssetMeshData> MAssetMesh::get_mesh_data(){
    if(instance_data.is_empty()){
        update_instance_date();
    }
    TypedArray<MAssetMeshData> out;
    for(const InstanceData& data : instance_data){
        if(data.meshes.size()>0){
            Ref<MAssetMeshData> _m;
            _m.instantiate();
            _m->material_set_id = data.material_set_id;
            _m->transform = data.local_transform;
            _m->global_transform = get_global_transform() * data.local_transform;
            _m->mesh_lod = data.meshes;
            _m->item_ids = data.item_ids;
            if(!disable_collision){
                _m->collision_data = data.collission_data;
            }
            out.push_back(_m);
        }
    }
    return out;
}

AABB MAssetMesh::get_joined_aabb(){
    if(joined_triangle_mesh.is_null()){
        generate_joined_triangle_mesh();
    }
    return joined_aabb;
}

Ref<TriangleMesh> MAssetMesh::get_joined_triangle_mesh(){
    if(instance_data.size() == 0){
        return nullptr;
    }
    if(joined_triangle_mesh.is_null()){
        generate_joined_triangle_mesh();
    }
    return joined_triangle_mesh;
}

void MAssetMesh::generate_joined_triangle_mesh(){
    joined_triangle_mesh.unref();
    // we need only vertices and indices for triangle mesh!
    PackedVector3Array verticies;
    PackedInt32Array indicies;
    int index_offset = 0;
    for(const InstanceData& data : instance_data){
        Ref<MMesh> current_mesh = data.get_last_valid_mesh();
        if(current_mesh.is_null()){
            continue;
        }
        Transform3D local_transform = data.local_transform;
        int surf_count = current_mesh->get_surface_count();
        for(int j=0; j < surf_count; j++){
            Array surface_data = current_mesh->surface_get_arrays(j);
            PackedVector3Array surface_vertices = surface_data[Mesh::ARRAY_VERTEX];
            PackedInt32Array surface_indicies = surface_data[Mesh::ARRAY_INDEX];
            for(int v=0; v < surface_vertices.size(); v++){
                surface_vertices.set(v,local_transform.xform(surface_vertices[v]));
            }
            for(int k=0; k < surface_indicies.size(); k++){
                surface_indicies.set(k,surface_indicies[k] + index_offset);
            }
            verticies.append_array(surface_vertices);
            indicies.append_array(surface_indicies);
            index_offset = verticies.size();
        }
    }
    if(indicies.size()==0){
        return;
    }
    Array mdata;
    mdata.resize(Mesh::ARRAY_MAX);
    mdata[Mesh::ARRAY_VERTEX] = verticies;
    mdata[Mesh::ARRAY_INDEX] = indicies;

    Ref<ArrayMesh> arr_mesh;
    arr_mesh.instantiate();
    arr_mesh->add_surface_from_arrays(Mesh::PRIMITIVE_TRIANGLES,mdata);

    joined_aabb = arr_mesh->get_aabb();
    joined_triangle_mesh = arr_mesh->generate_triangle_mesh();
}


Ref<ArrayMesh> MAssetMesh::get_merged_mesh(bool lowest_lod){
    bool was_data_size_zero = instance_data.size()==0;
    if(was_data_size_zero){
        update_instance_date();
        if(instance_data.size()==0){
            return nullptr;
        }
    }
    Ref<MMeshJoiner> mesh_joiner;
    mesh_joiner.instantiate();
    Array _mmeshes;
    Array _transforms;
    PackedInt32Array _material_set_ids;
    for(const InstanceData& data : instance_data){
        Ref<MMesh> c_mmesh;
        if(lowest_lod){
            c_mmesh = data.get_first_valid_mesh();
        } else {
            c_mmesh = data.get_last_valid_mesh();
        }
        if(c_mmesh.is_valid()){
            _mmeshes.push_back(c_mmesh);
            _transforms.push_back(data.local_transform);
            _material_set_ids.push_back(data.material_set_id);
        }
    }
    if(_mmeshes.is_empty()){
        return nullptr;
    }
    mesh_joiner->insert_mmesh_data(_mmeshes,_transforms,_material_set_ids);
    if(was_data_size_zero){
        remove_instances(true);
    }
    return mesh_joiner->join_meshes();
}

Ref<ArrayMesh> MAssetMesh::get_collection_merged_mesh(int collection_id,bool lowest_lod){
    MAssetMesh* _ma = memnew(MAssetMesh);
    _ma->set_collection_id_no_lod_update(collection_id);
    Ref<ArrayMesh> _arr_mesh = _ma->get_merged_mesh(lowest_lod);
    memdelete(_ma);
    return _arr_mesh;
}