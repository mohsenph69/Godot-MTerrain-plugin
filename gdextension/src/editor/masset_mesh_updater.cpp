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

VSet<MAssetMeshUpdater*> MAssetMeshUpdater::asset_mesh_updater_list;

void MAssetMeshUpdater::_bind_methods(){

    ClassDB::bind_method(D_METHOD("update_auto_lod"), &MAssetMeshUpdater::update_auto_lod);
    ClassDB::bind_method(D_METHOD("update_force_lod","lod"), &MAssetMeshUpdater::update_force_lod);

    ClassDB::bind_method(D_METHOD("get_current_lod"), &MAssetMeshUpdater::get_current_lod);

    ClassDB::bind_method(D_METHOD("set_join_mesh_id","input"), &MAssetMeshUpdater::set_join_mesh_id);
    ClassDB::bind_method(D_METHOD("get_join_mesh_id"), &MAssetMeshUpdater::get_join_mesh_id);
    ADD_PROPERTY(PropertyInfo(Variant::INT,"join_mesh_id"),"set_join_mesh_id","get_join_mesh_id");

    ClassDB::bind_method(D_METHOD("set_variation_layers","input"), &MAssetMeshUpdater::set_variation_layers);
    ClassDB::bind_method(D_METHOD("get_variation_layers"), &MAssetMeshUpdater::get_variation_layers);
    ADD_PROPERTY(PropertyInfo(Variant::INT,"variation_layers"),"set_variation_layers","get_variation_layers");

    ClassDB::bind_method(D_METHOD("set_root_node","input"), &MAssetMeshUpdater::set_root_node);
    ClassDB::bind_method(D_METHOD("get_root_node"), &MAssetMeshUpdater::get_root_node);

    ClassDB::bind_method(D_METHOD("get_joined_mesh_ids"), &MAssetMeshUpdater::get_joined_mesh_ids);
    ClassDB::bind_method(D_METHOD("get_mesh_lod"), &MAssetMeshUpdater::get_mesh_lod);
    ClassDB::bind_method(D_METHOD("get_join_at_lod"), &MAssetMeshUpdater::get_join_at_lod);

    ClassDB::bind_static_method("MAssetMeshUpdater",D_METHOD("refresh_all_masset_updater"), &MAssetMeshUpdater::refresh_all_masset_updater);
}

void MAssetMeshUpdater::refresh_all_masset_updater(){
    for(int i=0; i < asset_mesh_updater_list.size(); i++){
        asset_mesh_updater_list[i]->update_join_mesh();
    }
}

MAssetMeshUpdater::MAssetMeshUpdater(){
    asset_mesh_updater_list.insert(this);
}

MAssetMeshUpdater::~MAssetMeshUpdater(){
    asset_mesh_updater_list.erase(this);
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
                uint16_t avariation_layer = amesh->has_meta("variation_layers") ?  (int)amesh->get_meta("variation_layers") : 0;
                if(avariation_layer==0 || (avariation_layer&variation_layer)!=0){
                    amesh->update_lod(lod);
                } else {
                    amesh->update_lod(-1);
                }
            }
            continue;
        }
        VisualInstance3D* nd3d = Object::cast_to<VisualInstance3D>(cur_node);
        if(nd3d){
            uint16_t avariation_layer = nd3d->has_meta("variation_layers") ?  (int)nd3d->get_meta("variation_layers") : 0;
            bool is_visible = avariation_layer==0 || (avariation_layer&variation_layer)!=0;
            RS->instance_set_visible(nd3d->get_instance(),is_visible);
        }
    }
}

void MAssetMeshUpdater::update_join_mesh(){
    joined_mesh.clear();
    join_at = -1;
    if(join_mesh_id==-1){
        return;
    }
    if(!MAssetTable::mesh_join_is_valid(join_mesh_id)){
        join_at == -1;
        return;
    }
    joined_mesh_ids = MAssetTable::mesh_join_ids(join_mesh_id);
    join_at = MAssetTable::mesh_join_start_lod(join_mesh_id);
    joined_mesh = MAssetTable::mesh_join_meshes(join_mesh_id);
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

PackedInt32Array MAssetMeshUpdater::get_joined_mesh_ids(){
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

void MAssetMeshUpdater::set_join_mesh_id(int input){
    if(input == join_mesh_id){
        return;
    }
    ERR_FAIL_COND(input!=-1&&input>-10);
    join_mesh_id = input;
    update_join_mesh();
}

int MAssetMeshUpdater::get_join_mesh_id(){
    return join_mesh_id;
}

void MAssetMeshUpdater::set_variation_layers(int input){
    variation_layer = input;
}

int MAssetMeshUpdater::get_variation_layers(){
    return variation_layer;
}

void MAssetMeshUpdater::set_root_node(Node3D* input){
    root_node = input;
    update_join_mesh();
}

Node3D* MAssetMeshUpdater::get_root_node() const{
    return root_node;
}