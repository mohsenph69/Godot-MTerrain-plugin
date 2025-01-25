#include "mhlod_item.h"
#include "mhlod.h"

#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/physics_server3d.hpp>



#define RL ResourceLoader::get_singleton()



MHLodItemMesh::MHLodItemMesh(){

}
MHLodItemMesh::~MHLodItemMesh(){

}

// Should be called when mesh is valid
bool MHLodItemMesh::has_material_ovveride(){
    return mesh.is_valid() && mesh->has_material_override() && material_id >= 0;
}

void MHLodItemMesh::load(){
    if(mesh.is_null()){
        mesh = RL->load(MHlod::get_mesh_path(mesh_id));
    }
    if(has_material_ovveride()){
        mesh->add_user(material_id);
    }
}

void MHLodItemMesh::unload(){
    if(has_material_ovveride()){
        mesh->remove_user(material_id);
    }
    mesh.unref();
}

RID MHLodItemMesh::get_mesh() const{
    if(mesh.is_null()){
        return RID();
    }
    return mesh->get_mesh_rid();
}

void MHLodItemMesh::get_material(Vector<RID>& material_rids){
    if(!has_material_ovveride()){
        return;
    }
    mesh->get_materials(material_id,material_rids);
}

GeometryInstance3D::ShadowCastingSetting MHLodItemMesh::get_shadow_setting(){
    return (GeometryInstance3D::ShadowCastingSetting)shadow_setting;
}

GeometryInstance3D::GIMode MHLodItemMesh::get_gi_mode(){
    return (GeometryInstance3D::GIMode)gi_mode;
}

void MHLodItemMesh::set_data(int64_t _mesh,int8_t _material,uint8_t _shadow_setting,uint8_t _gi_mode,int32_t _render_layers){
    mesh_id = _mesh;
    material_id = _material;
    shadow_setting = _shadow_setting;
    gi_mode = _gi_mode;
    render_layers = _render_layers;
}

void MHLodItemMesh::set_data(const PackedByteArray& d){
    ERR_FAIL_COND(d.size()!=14);
    shadow_setting = d[0];
    gi_mode = d[1];
    material_id = d.decode_s32(2);
    render_layers = d.decode_s32(6);
    mesh_id = d.decode_s32(10);
}

PackedByteArray MHLodItemMesh::get_data() const{
    PackedByteArray d;
    d.resize(14);
    d[0] = shadow_setting;
    d[1] = gi_mode;
    d.encode_s32(2,material_id);
    d.encode_s32(6,render_layers);
    d.encode_s32(10,mesh_id);
    return d;
}

//////////////////////
//////////////////////

HashMap<MHLodItemCollision::Param,MHLodItemCollision::ShapeData,MHLodItemCollision::Param,MHLodItemCollision::Param> MHLodItemCollision::shapes;

MHLodItemCollision::MHLodItemCollision(){
    
}
MHLodItemCollision::~MHLodItemCollision(){

}

RID MHLodItemCollision::get_shape() {
    shapes.insert(param,MHLodItemCollision::ShapeData());
    UtilityFunctions::print("Has -------------------- ");
    Param p2 = param;
    p2.type = Param::Type::CYLINDER;
    bool has_param = shapes.has(p2);
    UtilityFunctions::print("Has param ",has_param);
    return RID();
}