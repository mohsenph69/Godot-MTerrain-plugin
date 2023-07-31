#ifndef MGRASSLODSETTING
#define MGRASSLODSETTING


#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/vector3.hpp>


using namespace godot;


class MGrassLodSetting : public Resource {
    GDCLASS(MGrassLodSetting,Resource);


    protected:
    static void _bind_methods();

    public:
    int force_lod_count=-1;
    int force_lod_mesh=-1;
    Vector3 offset = Vector3(0,0,0);
    Vector3 rot_offset = Vector3(0,0,0);
    Vector3 rand_pos_start = Vector3(0,0,0);
    Vector3 rand_pos_end = Vector3(1,1,1);
    Vector3 rand_rot_start = Vector3(0,0,0);
    Vector3 rand_rot_end = Vector3(0,0,0);

    void set_force_lod_count(int input);
    int get_force_lod_count();

    void set_force_lod_mesh(int input);
    int get_force_lod_mesh();

    void set_offset(Vector3 input);
    Vector3 get_offset();

    void set_rot_offset(Vector3 input);
    Vector3 get_rot_offset();

    void set_rand_pos_start(Vector3 input);
    Vector3 get_rand_pos_start();

    void set_rand_pos_end(Vector3 input);
    Vector3 get_rand_pos_end();

    void set_rand_rot_start(Vector3 input);
    Vector3 get_rand_rot_start();

    void set_rand_rot_end(Vector3 input);
    Vector3 get_rand_rot_end();
};
#endif