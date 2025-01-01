#ifndef __COLLISIONSETTING__
#define __COLLISIONSETTING__

#include <godot_cpp/classes/physics_material.hpp>
#include <godot_cpp/classes/resource.hpp>

using namespace godot;

class MHlodCollisionSetting : public Resource {
    GDCLASS(MHlodCollisionSetting,Resource);

    protected:
    static void _bind_methods();

    private:
    RID body;

    public:
    String name;
    int32_t collision_layer = 1;
    int32_t collision_mask = 1;
    Ref<PhysicsMaterial> physics_material;
    Vector3 constant_angular_velocity;
    Vector3 constant_linear_velocity;

    void set_name(const String& input);
    String get_name() const;

    void set_physics_material(Ref<PhysicsMaterial> input);
    Ref<PhysicsMaterial> get_physics_material() const;
    
    void set_constant_angular_velocity(const Vector3& input);
    Vector3 get_constant_angular_velocity() const;

    void set_constant_linear_velocity(const Vector3& input);
    Vector3 get_constant_linear_velocity() const;

    void set_collision_layer(int32_t input);
    int32_t get_collision_layer();

    void set_collision_mask(int32_t input);
    int32_t get_collision_mask();

    RID create_body();
};
#endif