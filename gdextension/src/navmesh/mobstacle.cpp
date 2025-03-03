#include "mobstacle.h"

#include <godot_cpp/classes/tree.hpp>
#include "mnavigation_region_3d.h"

void MObstacle::_bind_methods(){
    ClassDB::bind_method(D_METHOD("get_width"), &MObstacle::get_width);
    ClassDB::bind_method(D_METHOD("set_width","input"), &MObstacle::set_width);
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT,"width"),"set_width","get_width");

    ClassDB::bind_method(D_METHOD("get_depth"), &MObstacle::get_depth);
    ClassDB::bind_method(D_METHOD("set_depth","input"), &MObstacle::set_depth);
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT,"depth"),"set_depth","get_depth");

    ClassDB::bind_method(D_METHOD("has_gizmo"), &MObstacle::has_gizmo);
    ClassDB::bind_method(D_METHOD("get_aabb"), &MObstacle::get_aabb);
}


MObstacle::MObstacle(){
    MNavigationRegion3D::add_obstacle(this);
}

MObstacle::~MObstacle(){
    MNavigationRegion3D::remove_obstacle(this);
}

float MObstacle::get_width(){
    return width;
}
void MObstacle::set_width(float input){
    width = input;
    update_gizmos();
}
float MObstacle::get_depth(){
    return depth;
}
void MObstacle::set_depth(float input){
    depth = input;
    update_gizmos();
}

bool MObstacle::has_gizmo() const{
    return true;
}

AABB MObstacle::get_aabb() const{
    return AABB(Vector3(-width/2.0,-10.0,-depth/2.0),Vector3(width,20.0,depth));
}