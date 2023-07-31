#include "mgrass_lod_setting.h"



void MGrassLodSetting::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_force_lod_count","input"), &MGrassLodSetting::set_force_lod_count);
    ClassDB::bind_method(D_METHOD("get_force_lod_count"), &MGrassLodSetting::get_force_lod_count);
    ADD_PROPERTY(PropertyInfo(Variant::INT,"force_lod_count"),"set_force_lod_count","get_force_lod_count");
    ClassDB::bind_method(D_METHOD("set_force_lod_mesh","input"), &MGrassLodSetting::set_force_lod_mesh);
    ClassDB::bind_method(D_METHOD("get_force_lod_mesh"), &MGrassLodSetting::get_force_lod_mesh);
    ADD_PROPERTY(PropertyInfo(Variant::INT,"force_lod_mesh"),"set_force_lod_mesh","get_force_lod_mesh");
    ClassDB::bind_method(D_METHOD("set_offset","input"), &MGrassLodSetting::set_offset);
    ClassDB::bind_method(D_METHOD("get_offset"), &MGrassLodSetting::get_offset);
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR3,"offset"),"set_offset","get_offset");
    ClassDB::bind_method(D_METHOD("set_rot_offset","input"), &MGrassLodSetting::set_rot_offset);
    ClassDB::bind_method(D_METHOD("get_rot_offset"), &MGrassLodSetting::get_rot_offset);
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR3,"rot_offset"),"set_rot_offset","get_rot_offset");
    ClassDB::bind_method(D_METHOD("set_rand_pos_start","input"), &MGrassLodSetting::set_rand_pos_start);
    ClassDB::bind_method(D_METHOD("get_rand_pos_start"), &MGrassLodSetting::get_rand_pos_start);
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR3,"rand_pos_start"),"set_rand_pos_start","get_rand_pos_start");
    ClassDB::bind_method(D_METHOD("set_rand_pos_end","input"), &MGrassLodSetting::set_rand_pos_end);
    ClassDB::bind_method(D_METHOD("get_rand_pos_end"), &MGrassLodSetting::get_rand_pos_end);
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR3,"rand_pos_end"),"set_rand_pos_end","get_rand_pos_end");
    ClassDB::bind_method(D_METHOD("set_rand_rot_start","input"), &MGrassLodSetting::set_rand_rot_start);
    ClassDB::bind_method(D_METHOD("get_rand_rot_start"), &MGrassLodSetting::get_rand_rot_start);
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR3,"rand_rot_start"),"set_rand_rot_start","get_rand_rot_start");
    ClassDB::bind_method(D_METHOD("set_rand_rot_end","input"), &MGrassLodSetting::set_rand_rot_end);
    ClassDB::bind_method(D_METHOD("get_rand_rot_end"), &MGrassLodSetting::get_rand_rot_end);
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR3,"rand_rot_end"),"set_rand_rot_end","get_rand_rot_end");
}

void MGrassLodSetting::set_force_lod_count(int input){
    force_lod_count = input;
}
int MGrassLodSetting::get_force_lod_count(){
    return force_lod_count;
}

void MGrassLodSetting::set_force_lod_mesh(int input){
    force_lod_mesh = input;
}
int MGrassLodSetting::get_force_lod_mesh(){
    return force_lod_mesh;
}

void MGrassLodSetting::set_offset(Vector3 input){
    offset = input;
}
Vector3 MGrassLodSetting::get_offset(){
    return offset;
}

void MGrassLodSetting::set_rot_offset(Vector3 input){
    rot_offset = input;
}
Vector3 MGrassLodSetting::get_rot_offset(){
    return rot_offset;
}

void MGrassLodSetting::set_rand_pos_start(Vector3 input){
    rand_pos_start = input;
}
Vector3 MGrassLodSetting::get_rand_pos_start(){
    return rand_pos_start;
}

void MGrassLodSetting::set_rand_pos_end(Vector3 input){
    rand_pos_end = input;
}
Vector3 MGrassLodSetting::get_rand_pos_end(){
    return rand_pos_end;
}

void MGrassLodSetting::set_rand_rot_start(Vector3 input){
    rand_rot_start = input;
}
Vector3 MGrassLodSetting::get_rand_rot_start(){
    return rand_rot_start;
}

void MGrassLodSetting::set_rand_rot_end(Vector3 input){
    rand_rot_end = input;
}
Vector3 MGrassLodSetting::get_rand_rot_end(){
    return rand_rot_end;
}