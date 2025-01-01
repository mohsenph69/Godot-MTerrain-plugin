#include "mhlod_collision_setting.h"
#include <godot_cpp/classes/physics_server3d.hpp>

void MHlodCollisionSetting::_bind_methods(){
    ClassDB::bind_method(D_METHOD("set_name","input"), &MHlodCollisionSetting::set_name);
    ClassDB::bind_method(D_METHOD("get_name"), &MHlodCollisionSetting::get_name);
    ADD_PROPERTY(PropertyInfo(Variant::STRING,"name"),"set_name","get_name");

    ClassDB::bind_method(D_METHOD("set_physics_material","input"), &MHlodCollisionSetting::set_physics_material);
    ClassDB::bind_method(D_METHOD("get_physics_material"), &MHlodCollisionSetting::get_physics_material);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT,"physics_material",PROPERTY_HINT_RESOURCE_TYPE,"PhysicsMaterial"),"set_physics_material","get_physics_material");

    ClassDB::bind_method(D_METHOD("set_constant_angular_velocity","input"), &MHlodCollisionSetting::set_constant_angular_velocity);
    ClassDB::bind_method(D_METHOD("get_constant_angular_velocity"), &MHlodCollisionSetting::get_constant_angular_velocity);
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR3,"constant_angular_velocity"),"set_constant_angular_velocity","get_constant_angular_velocity");

    ClassDB::bind_method(D_METHOD("set_constant_linear_velocity","input"), &MHlodCollisionSetting::set_constant_linear_velocity);
    ClassDB::bind_method(D_METHOD("get_constant_linear_velocity"), &MHlodCollisionSetting::get_constant_linear_velocity);
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR3,"constant_linear_velocity"),"set_constant_linear_velocity","get_constant_linear_velocity");

    ClassDB::bind_method(D_METHOD("set_collision_layer","input"), &MHlodCollisionSetting::set_collision_layer);
    ClassDB::bind_method(D_METHOD("get_collision_layer"), &MHlodCollisionSetting::get_collision_layer);
    ADD_PROPERTY(PropertyInfo(Variant::INT,"collision_layer",PROPERTY_HINT_LAYERS_3D_PHYSICS),"set_collision_layer","get_collision_layer");

    ClassDB::bind_method(D_METHOD("set_collision_mask","input"), &MHlodCollisionSetting::set_collision_mask);
    ClassDB::bind_method(D_METHOD("get_collision_mask"), &MHlodCollisionSetting::get_collision_mask);
    ADD_PROPERTY(PropertyInfo(Variant::INT,"collision_mask",PROPERTY_HINT_LAYERS_3D_PHYSICS),"set_collision_mask","get_collision_mask");
}

void MHlodCollisionSetting::set_name(const String& input){
    name = input;
}

String MHlodCollisionSetting::get_name() const{
    return name;
}

void MHlodCollisionSetting::set_physics_material(Ref<PhysicsMaterial> input){
    physics_material = input;
}

Ref<PhysicsMaterial> MHlodCollisionSetting::get_physics_material() const{
    return physics_material;
}


void MHlodCollisionSetting::set_constant_angular_velocity(const Vector3& input){
    constant_angular_velocity = input;
}

Vector3 MHlodCollisionSetting::get_constant_angular_velocity() const{
    return constant_angular_velocity;
}


void MHlodCollisionSetting::set_constant_linear_velocity(const Vector3& input){
    constant_linear_velocity = input;
}

Vector3 MHlodCollisionSetting::get_constant_linear_velocity() const{
    return constant_linear_velocity;
}

void MHlodCollisionSetting::set_collision_layer(int32_t input){
    collision_layer = input;
}

int32_t MHlodCollisionSetting::get_collision_layer(){
    return collision_layer;
}


void MHlodCollisionSetting::set_collision_mask(int32_t input){
    collision_mask = input;
}

int32_t MHlodCollisionSetting::get_collision_mask(){
    return collision_mask;
}

#define PS PhysicsServer3D::get_singleton()
RID MHlodCollisionSetting::create_body(){
    RID b = PS->body_create();
    PS->body_set_mode(b,PhysicsServer3D::BodyMode::BODY_MODE_STATIC);
    PS->body_set_collision_layer(b,collision_layer);
    PS->body_set_collision_mask(b,collision_mask);
    PS->body_set_state(b,PhysicsServer3D::BodyState::BODY_STATE_LINEAR_VELOCITY,constant_linear_velocity);
    PS->body_set_state(b,PhysicsServer3D::BodyState::BODY_STATE_ANGULAR_VELOCITY,constant_angular_velocity);
	if (physics_material.is_null()) {
		PS->body_set_param(b, PhysicsServer3D::BODY_PARAM_BOUNCE, 0);
		PS->body_set_param(b, PhysicsServer3D::BODY_PARAM_FRICTION, 1);
	} else {
        real_t bounce =  physics_material->is_absorbent() ? -  physics_material->get_bounce() : physics_material->get_bounce();
        real_t friction = physics_material->is_rough() ? -physics_material->get_friction() : physics_material->get_friction();

		PS->body_set_param(b, PhysicsServer3D::BODY_PARAM_BOUNCE, bounce);
		PS->body_set_param(b, PhysicsServer3D::BODY_PARAM_FRICTION, friction);
	}
    return b;
}