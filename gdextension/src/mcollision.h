#ifndef MCOLLISION
#define MCOLLISION


#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/vector3.hpp>

using namespace godot;


class MCollision : public RefCounted {
    GDCLASS(MCollision,RefCounted);    

    protected:
    static void _bind_methods();
    public:
    bool collided=false;
    Vector3 collision_position;

    bool is_collided();
    Vector3 get_collision_position();

};





#endif