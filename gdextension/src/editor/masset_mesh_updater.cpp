#include "masset_mesh_updater.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/viewport.hpp>
#include <godot_cpp/classes/camera3d.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/world3d.hpp>

#include <godot_cpp/classes/rendering_server.hpp>
#define RS RenderingServer::get_singleton()

#include "../mtool.h"
#include "../moctree.h"
#include "../hlod/mhlod_scene.h"
#include "masset_table.h"

#include "masset_mesh.h"

void MAssetMeshUpdater::_bind_methods(){

    ClassDB::bind_method(D_METHOD("update_auto_lod"), &MAssetMeshUpdater::update_auto_lod);
    ClassDB::bind_method(D_METHOD("update_force_lod","lod"), &MAssetMeshUpdater::update_force_lod);

    ClassDB::bind_method(D_METHOD("get_current_lod"), &MAssetMeshUpdater::get_current_lod);

    ClassDB::bind_method(D_METHOD("set_joined_mesh_collection_id","input"), &MAssetMeshUpdater::set_joined_mesh_collection_id);
    ClassDB::bind_method(D_METHOD("get_joined_mesh_collection_id"), &MAssetMeshUpdater::get_joined_mesh_collection_id);
    ADD_PROPERTY(PropertyInfo(Variant::INT,"joined_mesh_collection_id"),"set_joined_mesh_collection_id","get_joined_mesh_collection_id");

    ClassDB::bind_method(D_METHOD("set_root_node","input"), &MAssetMeshUpdater::set_root_node);
    ClassDB::bind_method(D_METHOD("get_root_node"), &MAssetMeshUpdater::get_root_node);

    ClassDB::bind_method(D_METHOD("get_joined_mesh_ids"), &MAssetMeshUpdater::get_joined_mesh_ids);
    ClassDB::bind_method(D_METHOD("get_mesh_lod"), &MAssetMeshUpdater::get_mesh_lod);
    ClassDB::bind_method(D_METHOD("get_join_at_lod"), &MAssetMeshUpdater::get_join_at_lod);
}

MAssetMeshUpdater::MAssetMeshUpdater(){

}

MAssetMeshUpdater::~MAssetMeshUpdater(){
    remove_join_mesh();
}

void MAssetMeshUpdater::_update_lod(int lod){
    current_lod = lod;
    bool is_join_mesh = lod >= join_at && join_at >= 0;
    //UtilityFunctions::print("lod ",lod," is_join_mesh ",is_join_mesh," join_at ",join_at);
    if(is_join_mesh){
        add_join_mesh(lod);
    } else {
        remove_join_mesh();
    }
    ERR_FAIL_COND(root_node==nullptr);
    if(!root_node->is_inside_tree()){
        return;
    }
    TypedArray<Node> children = root_node->get_children();
    while (children.size() > 0)
    {
        int last_index = children.size() - 1;
        Node* cur_node = Object::cast_to<Node>(children[last_index]);
        children.remove_at(last_index);
        if(cur_node == nullptr){
            WARN_PRINT("node is null");
            continue;
        }
        if(cur_node->get("asset_mesh_updater").get_type() == Variant::Type::NIL){
            children.append_array(cur_node->get_children());
        }
        MAssetMesh* amesh = Object::cast_to<MAssetMesh>(cur_node);
        if(amesh){
            if(is_join_mesh){
                amesh->destroy_meshes();
            } else {
                amesh->update_lod(lod);
            }
        }
    }
}

void MAssetMeshUpdater::update_join_mesh(){
    ERR_FAIL_COND(MAssetTable::get_singleton().is_null());
    join_at = -1;
    joined_mesh_ids.clear();
    joined_mesh.clear();
    if(joined_mesh_collection_id<0){
        return;
    }
    Ref<MAssetTable> at = MAssetTable::get_singleton();
    PackedInt32Array mesh_item_list = at->collection_get_mesh_items_ids(joined_mesh_collection_id);
    ERR_FAIL_COND_MSG(mesh_item_list.size()!=1,"Joined Mesh Collection "+itos(joined_mesh_collection_id)+" should have one mesh item, but has "+itos(mesh_item_list.size()));
    int mid = mesh_item_list[0];
    PackedInt64Array meshe_ids = at->mesh_item_get_mesh(mid);
    if(meshe_ids.size()==0){
        return;
    }
    TypedArray<MMesh> meshes;
    int first_valid_mesh = -1;
    for(int64_t m : meshe_ids){
        if(m < 0){
            meshes.push_back(Ref<MMesh>());
            joined_mesh_ids.push_back(-1);
            continue;
        }
        Ref<MMesh> mesh = ResourceLoader::get_singleton()->load(MHlod::get_mesh_path(m));
        meshes.push_back(mesh);
        joined_mesh_ids.push_back(m);
        if(mesh.is_valid() && first_valid_mesh == -1){
            first_valid_mesh = meshes.size() - 1;
        }
    }
    ERR_FAIL_COND_MSG(!first_valid_mesh==-1,"No valid mesh in join mesh");
    join_at = first_valid_mesh;
    joined_mesh = meshes;
}

void MAssetMeshUpdater::add_join_mesh(int lod){
    ERR_FAIL_COND(root_node==nullptr);
    ERR_FAIL_COND(joined_mesh.size() == 0);
    if(!join_mesh_instance.is_valid()){
        join_mesh_instance = RS->instance_create();
        RS->instance_set_scenario(join_mesh_instance,root_node->get_world_3d()->get_scenario());
    }
    lod = lod < joined_mesh.size() ? lod : joined_mesh.size() - 1;
    Ref<MMesh> last_mesh = joined_mesh[lod];
    if(last_mesh.is_null()){
        RS->instance_set_base(join_mesh_instance,RID());
    } else {
        
        RS->instance_set_base(join_mesh_instance,last_mesh->get_mesh_rid());
    }
}

void MAssetMeshUpdater::remove_join_mesh(){
    if(join_mesh_instance.is_valid()){
        RS->free_rid(join_mesh_instance);
        join_mesh_instance = RID();
    }
}

void MAssetMeshUpdater::update_auto_lod(){
    ERR_FAIL_COND(root_node==nullptr);
    if(!root_node->is_inside_tree()){
        return;
    }
    Node3D* camera_node = nullptr;
    if(Engine::get_singleton()->is_editor_hint()){
        camera_node = MTool::find_editor_camera(true);
    } else {
        Viewport* v = root_node->get_viewport();
        if(v!=nullptr){
            camera_node = v->get_camera_3d();
        }
    }
    ERR_FAIL_COND(camera_node==nullptr);
    MOctree* octree = MHlodScene::get_octree();
    ERR_FAIL_COND_MSG(octree==nullptr,"No octree define for HLod system! create a octree and activate that for hlod by calling enable_as_hlod_updater()");
    PackedFloat32Array lods = octree->get_lod_setting();
    float dis = camera_node->get_global_position().distance_to(root_node->get_global_position());
    int lod = 0;
    for(int i=0; i < lods.size(); i++){
        if(dis < lods[i]){
            break;
        }
        lod++;
    }
    _update_lod(lod);
}

void MAssetMeshUpdater::update_force_lod(int lod){
    _update_lod(lod);
}

PackedInt64Array MAssetMeshUpdater::get_joined_mesh_ids(){
    return joined_mesh_ids;
}

TypedArray<MMesh> MAssetMeshUpdater::get_mesh_lod(){
    return joined_mesh;
}

int MAssetMeshUpdater::get_join_at_lod(){
    return join_at;
}


int MAssetMeshUpdater::get_current_lod(){
    return current_lod;
}

void MAssetMeshUpdater::set_joined_mesh_collection_id(int input){
    joined_mesh_collection_id = input;
    update_join_mesh();
}

int MAssetMeshUpdater::get_joined_mesh_collection_id(){
    return joined_mesh_collection_id;
}


void MAssetMeshUpdater::set_root_node(Node3D* input){
    root_node = input;
    update_join_mesh();
}

Node3D* MAssetMeshUpdater::get_root_node() const{
    return root_node;
}