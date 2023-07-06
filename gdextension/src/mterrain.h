#ifndef TEST_H
#define TEST_H

#include <thread>
#include <future>
#include <chrono>

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/material.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/classes/timer.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/templates/list.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/classes/shader_material.hpp>
#include <godot_cpp/variant/dictionary.hpp>



#include "mgrid.h"

using namespace godot;


class MTerrain : public  Node3D {
    GDCLASS(MTerrain, Node3D);
    private:
    MChunks* _chunks;
    std::future<void> update_thread_chunks;
    bool finish_updating_chunks=true;
    bool update_chunks_loop=true;
    Timer* update_chunks_timer;
    float update_chunks_interval = 0.2;

    std::future<void> update_thread_physics;
    bool finish_updating_physics=true;
    bool update_physics_loop=true;
    Timer* update_physics_timer;
    float update_physics_interval = 1.0;

    MGrid* grid;
    Ref<ShaderMaterial> material;
    Vector2i terrain_size = Vector2i(10,10);
    Vector3 cam_pos;
    Node3D* editor_camera = nullptr;
    Node3D* custom_camera = nullptr;
    Vector3 offset;
    int min_size_index = 2;
    int max_size_index = 7;
    int min_h_scale_index = 2;
    int max_h_scale_index = 7;
    int8_t max_lod;
    int8_t max_size;
    int32_t size_list[8] = M_SIZE_LIST;
    real_t h_scale_list[8]   = M_H_SCALE_LIST;
    Array size_info;
    int32_t max_range;
    PackedInt32Array lod_distance;
    // key is name
    // value is compression
    Array uniforms;
    int32_t region_size;
    String dataDir;
    bool save_generated_normals = false;
    


    protected:
    static void _bind_methods();

    public:
    MTerrain();
    ~MTerrain();
    void finish_terrain();
    void start();
    void create_grid();
    void remove_grid();
    void restart_grid();
    void update();
    void finish_update();
    void update_physics();
    void finish_update_physics();
    bool is_finish_updating_chunks();
    bool is_finish_updating_physics();
    Array get_image_list();
    int get_image_id(String uniform_name);
    void save_image(int image_index, bool force_save);

    Color get_pixel(const uint32_t& x,const uint32_t& y, const int32_t& index);
    void set_pixel(const uint32_t& x,const uint32_t& y,const Color& col,const int32_t& index);
    real_t get_height_by_pixel(const uint32_t& x,const uint32_t& y);
    void set_height_by_pixel(const uint32_t& x,const uint32_t& y,const real_t& value);

    void get_cam_pos();

    void set_dataDir(String input);
    String get_dataDir();

    void set_create_grid(bool input);
    bool get_create_grid();


    Ref<ShaderMaterial> get_material();
    void set_material(Ref<ShaderMaterial> m);
    void set_save_generated_normals(bool input);
    bool get_save_generated_normals();
    float get_update_chunks_interval();
    void set_update_chunks_interval(float input);
    void set_update_chunks_loop(bool input);
    bool get_update_chunks_loop();
    float get_update_physics_interval();
    void set_update_physics_interval(float input);
    bool get_update_physics_loop();
    void set_update_physics_loop(float input);
    void set_physics_update_limit(int32_t input);
    int32_t get_physics_update_limit();
    Vector2i get_terrain_size();
    void set_terrain_size(Vector2i size);

    void set_max_range(int32_t input);
    int32_t get_max_range();

    void set_editor_camera(Node3D* camera_node);
    void set_custom_camera(Node3D* camera_node);

    void set_offset(Vector3 input);
    Vector3 get_offset();

    void set_region_size(int32_t input);
    int32_t get_region_size();
    

    void update_uniforms();
    void recalculate_terrain_config(const bool& force_calculate);    
    int get_min_size();
    void set_min_size(int index);
    int get_max_size();
    void set_max_size(int index);
    int get_min_h_scale();
    void set_min_h_scale(int index);
    int get_max_h_scale();
    void set_max_h_scale(int index);
    void set_size_info(const Array& arr);
    Array get_size_info();
    void set_lod_distance(const PackedInt32Array& input);
    PackedInt32Array get_lod_distance();

    real_t get_closest_height(const Vector3& pos);

    void _get_property_list(List<PropertyInfo> *p_list) const;
    bool _get(const StringName &p_name, Variant &r_ret) const;
    bool _set(const StringName &p_name, const Variant &p_value);
};



#endif
