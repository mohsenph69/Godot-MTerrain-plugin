#ifndef MNAVIGATIONREGION3D
#define MNAVIGATIONREGION3D

#include <godot_cpp/classes/navigation_server3d.hpp>
#include <godot_cpp/classes/navigation_region3d.hpp>
#include <godot_cpp/classes/navigation_mesh.hpp>
#include <godot_cpp/classes/navigation_mesh_source_geometry_data3d.hpp>
#include <godot_cpp/classes/array_mesh.hpp>
#include <godot_cpp/classes/timer.hpp>
#include <godot_cpp/templates/vector.hpp>
#include <godot_cpp/templates/vset.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/variant/vector4.hpp>

#include <godot_cpp/classes/mesh_instance3d.hpp>
#include <godot_cpp/classes/array_mesh.hpp>
#include <godot_cpp/classes/standard_material3d.hpp>
#include "../mterrain.h"
#include "mnavigation_mesh_data.h"
#include "../grass/mgrass_chunk.h"

#include <thread>
#include <future>
#include <chrono>

using namespace godot;


class MNavigationRegion3D : public NavigationRegion3D{
    GDCLASS(MNavigationRegion3D,NavigationRegion3D);
    Ref<MNavigationMeshData> nav_data;
    MGrid* grid = nullptr;
    MTerrain* terrain = nullptr;
    float navigation_radius = 256;
    std::future<void> update_thread;
    bool is_updating = false;
    bool _force_update = false;
    bool start_update = true;
    Vector3 cam_pos;
    Vector3 last_update_pos;
    Node3D* custom_camera = nullptr;
    Timer* update_timer;
    bool active_update_loop=true;
    float distance_update_threshold=64;
    void _update_navmesh(Vector3 cam_pos);
    MeshInstance3D* debug_mesh_instance;
    Ref<ArrayMesh> debug_mesh;
    Ref<NavigationMesh> tmp_nav;
    Vector<Vector4> obs_info;
    PackedFloat32Array obst_info;

    RID scenario;
    uint32_t base_grid_size_in_pixel;
    uint32_t region_pixel_width;
    uint32_t region_pixel_size;
    std::mutex npoint_mutex;
    HashMap<int64_t,MGrassChunk*> grid_to_npoint;
    Vector<MGrassChunk*> to_be_visible;
    VSet<int>* dirty_points_id;
    uint64_t update_id=0;
    Ref<ArrayMesh> paint_mesh;
    Ref<StandardMaterial3D> paint_material;
    uint32_t region_grid_width;
    uint32_t width;
    uint32_t height;
    float h_scale;
    bool is_npoints_visible = false;




    protected:
    static void _bind_methods();

    public:
    bool is_nav_init = false;
    MNavigationRegion3D();
    ~MNavigationRegion3D();
    
    void init(MTerrain* _terrain, MGrid* _grid);
    void clear();
    void _update_loop();
    void update_navmesh(Vector3 cam_pos);
    void _finish_update(Ref<NavigationMesh> nvm);
    void _set_is_updating(bool input);
    void get_cam_pos();
    void force_update();

    void set_nav_data(Ref<MNavigationMeshData> input);
    Ref<MNavigationMeshData> get_nav_data();

    void set_start_update(bool input);
    bool get_start_update();

    void set_active_update_loop(bool input);
    bool get_active_update_loop();

    void set_distance_update_threshold(float input);
    float get_distance_update_threshold();

    void set_navigation_radius(float input);
    float get_navigation_radius();



    void update_npoints();
    void update_dirty_npoints();
    void apply_update_npoints();
    void create_npoints(int grid_index,MGrassChunk* grass_chunk=nullptr);
    void set_npoint_by_pixel(uint32_t px, uint32_t py, bool p_value);
    bool get_npoint_by_pixel(uint32_t px, uint32_t py);
    Vector2i get_closest_pixel(Vector3 pos);
    void draw_npoints(Vector3 brush_pos,real_t radius,bool add);
    void set_npoints_visible(bool val);

};
#endif