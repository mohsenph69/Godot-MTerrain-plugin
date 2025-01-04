#include "masset_mesh.h"

#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/world3d.hpp>
#include "masset_table.h"
#include "../hlod/mhlod.h"
#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#define RS RenderingServer::get_singleton()


void MAssetMeshData::_bind_methods(){
    ClassDB::bind_method(D_METHOD("get_material_set_id"), &MAssetMeshData::get_material_set_id);
    ClassDB::bind_method(D_METHOD("get_transform"), &MAssetMeshData::get_transform);
    ClassDB::bind_method(D_METHOD("get_global_transform"), &MAssetMeshData::get_global_transform);
    ClassDB::bind_method(D_METHOD("get_mesh_lod"), &MAssetMeshData::get_mesh_lod);
    ClassDB::bind_method(D_METHOD("get_mesh_ids"), &MAssetMeshData::get_mesh_ids);
}

int MAssetMeshData::get_material_set_id(){
    return material_set_id;
}

Transform3D MAssetMeshData::get_transform(){
    return transform;
}

Transform3D MAssetMeshData::get_global_transform(){
    return global_transform;
}

TypedArray<MMesh> MAssetMeshData::get_mesh_lod(){
    return mesh_lod;
}

PackedInt64Array MAssetMeshData::get_mesh_ids(){
    return mesh_ids;
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

Ref<MMesh> MAssetMesh::InstanceData::get_last_valid_mesh() const {
    for(int i=meshes.size()-1;i>=0;i--){
        Ref<MMesh> m = meshes[i];
        if(m.is_valid()){
            return m;
        }
    }
    return Ref<MMesh>();
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

void MAssetMesh::_bind_methods(){
    ClassDB::bind_method(D_METHOD("update_instance_date"), &MAssetMesh::update_instance_date);
    ClassDB::bind_method(D_METHOD("update_lod","lod"), &MAssetMesh::update_lod);

    ClassDB::bind_method(D_METHOD("set_hlod_layers","input"), &MAssetMesh::set_hlod_layers);
    ClassDB::bind_method(D_METHOD("get_hlod_layers"), &MAssetMesh::get_hlod_layers);
    ADD_PROPERTY(PropertyInfo(Variant::INT,"hlod_layers"),"set_hlod_layers","get_hlod_layers");

    ClassDB::bind_method(D_METHOD("get_collection_id"), &MAssetMesh::get_collection_id);
    ClassDB::bind_method(D_METHOD("set_collection_id","input"), &MAssetMesh::set_collection_id);
    ADD_PROPERTY(PropertyInfo(Variant::INT,"collection_id"),"set_collection_id","get_collection_id");

    ClassDB::bind_method(D_METHOD("_update_visibility"), &MAssetMesh::_update_visibility);

    ClassDB::bind_method(D_METHOD("get_mesh_data"), &MAssetMesh::get_mesh_data);

    ClassDB::bind_method(D_METHOD("get_joined_aabb"), &MAssetMesh::get_joined_aabb);
    ClassDB::bind_method(D_METHOD("get_joined_triangle_mesh"), &MAssetMesh::get_joined_triangle_mesh);
}

MAssetMesh::MAssetMesh(){
    set_notify_transform(true);
    connect("tree_exited",Callable(this,"_update_visibility"));
    connect("tree_entered",Callable(this,"_update_visibility"));
    
}

MAssetMesh::~MAssetMesh(){
    remove_instances(true);
}

void MAssetMesh::generate_instance_data(int collection_id,const Transform3D& transform){
    Ref<MAssetTable> asset_table = MAssetTable::get_singleton();
    ERR_FAIL_COND(asset_table.is_null());
    /////////////////////
    ///// Mesh Item ////
    ////////////////////
    Vector<Pair<int,Transform3D>> mesh_items = asset_table->collection_get_mesh_items_id_transform(collection_id);
    for(const Pair<int,Transform3D>& item : mesh_items){
        InstanceData idata;
        idata.local_transform = transform * item.second;
        PackedInt64Array mesh_ids = asset_table->mesh_item_get_mesh(item.first);
        //ERR_CONTINUE(mesh_material.size()==0);
        // Setting lods
        TypedArray<MMesh> meshes;
        for(int m : mesh_ids){
            if(m<0){
                meshes.push_back(Ref<MMesh>());
                continue;
            }
            Ref<MMesh> mesh = ResourceLoader::get_singleton()->load(MHlod::get_mesh_path(m));
            meshes.push_back(mesh);
        }
        idata.material_set_id = asset_table->mesh_item_get_material(item.first);
        idata.meshes = meshes;
        idata.mesh_ids = mesh_ids;
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
    remove_instances(true);
    if(collection_id==-1){
        return;
    }
    Transform3D t; // Identity Transform
    generate_instance_data(collection_id,t);
    compute_joined_aabb();
}

void MAssetMesh::update_lod(int lod){
    current_lod = lod;
    bool is_visible = is_visible_in_tree() && is_inside_tree();
    for(InstanceData& data : instance_data){
        ERR_CONTINUE(data.meshes.size()==0);
        RID mesh_rid = data.get_mesh_rid_last(lod);
        Ref<MMesh> mmesh = data.get_last_valid_mesh();
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

void MAssetMesh::remove_instances(bool hard_remove){
    for(InstanceData& data : instance_data){
        if(data.instance_rid.is_valid()){
            if(data.current_mmesh.is_valid()){
                if(data.material_set_user_added){
                    data.current_mmesh->remove_user(data.material_set_id);
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

int64_t MAssetMesh::get_hlod_layers(){
    return hlod_layers;
}

void MAssetMesh::set_collection_id(int input){
    collection_id = input;
    update_instance_date();
    update_lod(current_lod);
    update_gizmos();
}

int MAssetMesh::get_collection_id(){
    return collection_id;
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
        //update_instance_date();
        break;
    default:
        break;
    }
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
            _m->mesh_ids = data.mesh_ids;
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