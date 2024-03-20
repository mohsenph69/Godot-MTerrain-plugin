#ifndef MGRASSLODSETTING
#define MGRASSLODSETTING


#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/classes/geometry_instance3d.hpp>

using namespace godot;


class MGrassLodSetting : public Resource {
    GDCLASS(MGrassLodSetting,Resource);
    private:
    _FORCE_INLINE_ double rand_float(double a,double b,int seed);

    protected:
    static void _bind_methods();

    public:
    bool is_dirty=false;
    int seed=1001;
    int divide=1;
    int grass_in_cell=1;
    int force_lod_count=-1;
    Vector3 offset = Vector3(0,0,0);
    Vector3 rot_offset = Vector3(0,0,0);
    Vector3 rand_pos_start = Vector3(0,0,0);
    Vector3 rand_pos_end = Vector3(1,0,1);
    Vector3 rand_rot_start = Vector3(0,0,0);
    Vector3 rand_rot_end = Vector3(0,0,0);
    float unifrom_rand_scale_start=1.0;
    float unifrom_rand_scale_end=1.0;
    Vector3 rand_scale_start = Vector3(1,1,1);
    Vector3 rand_scale_end = Vector3(1,1,1);

    RenderingServer::ShadowCastingSetting shadow_setting = RenderingServer::ShadowCastingSetting::SHADOW_CASTING_SETTING_OFF;
    GeometryInstance3D::GIMode gi_mode = GeometryInstance3D::GIMode::GI_MODE_DISABLED;

    void set_seed(int input);
    int get_seed();

    void set_divide(int input);
    int get_divide();

    void set_grass_in_cell(int input);
    int get_grass_in_cell();

    void set_force_lod_count(int input);
    int get_force_lod_count();

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

    void set_uniform_rand_scale_start(float input);
    float get_uniform_rand_scale_start();

    void set_uniform_rand_scale_end(float input);
    float get_uniform_rand_scale_end();

    void set_rand_scale_start(Vector3 input);
    Vector3 get_rand_scale_start();

    void set_rand_scale_end(Vector3 input);
    Vector3 get_rand_scale_end();

    PackedFloat32Array* generate_random_number(float density,int amount);


    //Geometry setting
    void set_shadow_setting(RenderingServer::ShadowCastingSetting input);
    RenderingServer::ShadowCastingSetting get_shadow_setting();
    void set_gi_mode(GeometryInstance3D::GIMode input);
    GeometryInstance3D::GIMode get_gi_mode();
};
#endif