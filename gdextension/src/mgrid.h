#ifndef MGRID
#define MGRID

//#define NO_MERGE

#include <thread>

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/rid.hpp>
#include <godot_cpp/templates/vector.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/variant/basis.hpp>
#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/templates/vector.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/classes/material.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/variant/dictionary.hpp>




#include "mregion.h"
#include "mchunks.h"
#include "mconfig.h"
#include "mbound.h"
#include "mpixel_region.h"
#include "mcollision.h"

class MBrushManager;
class MHeightBrush;



using namespace godot;





// size -1 means it has been merged
// lod -1 means it is out of range
// lod -2 means it should be droped and never been drawn
struct MPoint
{
    RID instance = RID();
    RID mesh = RID();
    int8_t lod = -1;
    int8_t size=0;

    _FORCE_INLINE_ bool has_instance(){
        return instance != RID();
    }
    void create_instance(const Vector3& pos,const RID& scenario,const RID& material){
        Transform3D xform(Basis(), pos);
        RenderingServer* rs = RenderingServer::get_singleton();
        instance = rs->instance_create();
        rs->instance_set_scenario(instance, scenario);
        rs->instance_set_transform(instance, xform);
        if(material != RID())
            rs->instance_geometry_set_material_override(instance, material);
    }

    ~MPoint(){
        RenderingServer::get_singleton()->free_rid(instance);
    }
};

class MGrid : public Object {
    GDCLASS(MGrid, Object);
    friend class MRegion;
    private:
    MBrushManager* _brush_manager = nullptr;
    MPoint** points;
    MRegion* regions;
    bool current_update = true;
    bool is_dirty = false;
    MChunks* _chunks;
    MGridPos _size;
    MGridPos _size_meter;
    MGridPos _vertex_size;
    MBound _grid_bound;
    MBound _region_grid_bound;
    MBound _last_region_grid_bound;
    MBound _search_bound;
    MBound _last_search_bound;
    MGridPos _cam_pos;
    Vector3 _cam_pos_real;
    MGridPos _lowest_distance;
    RID _scenario;
    int32_t num_chunks = 0;
    int32_t chunk_counter = 0;
    MGridPos _region_grid_size;
    int32_t _regions_count;
    Vector<MImage*> _all_image_list;
    PackedVector3Array nvec8;
    
    
    Vector<RID> remove_instance_list;
    Vector<RID> update_mesh_list;
    Ref<ShaderMaterial> _material;
    uint64_t update_count=0;
    uint64_t total_remove=0;
    uint64_t total_add=0;
    uint64_t total_chunks=0;

    _FORCE_INLINE_ bool _has_pixel(const uint32_t& x,const uint32_t& y);

    




    protected:
    static void _bind_methods(){};

    public:
    bool has_normals = false;
    bool save_generated_normals=false;
    Dictionary uniforms_id;
    int32_t physics_update_limit = 1;
    RID space;
    String dataDir;
    PackedInt32Array lod_distance;
    int32_t region_size = 128;
    int32_t region_size_meter;
    uint32_t region_pixel_size;
    uint32_t rp;
    //MBound grid_pixel_bound;
    uint32_t pixel_width;
    uint32_t pixel_height;
    MPixelRegion grid_pixel_region;
    Vector3 offset;
    int32_t max_range = 128;
    /*
    Brush Stuff
    */
    uint32_t brush_px_pos_x;
    uint32_t brush_px_pos_y;
    uint32_t brush_px_radius;
    real_t brush_radius;
    Vector3 brush_world_pos;
    MGrid();
    ~MGrid();
    void clear();
    bool is_created();
    MGridPos get_size();
    void set_scenario(RID scenario);
    void create(const int32_t &width,const int32_t& height, MChunks* chunks);
    void update_regions_uniforms(Array input);
    void update_regions_uniform(Dictionary input);
    void update_all_image_list();
    Vector3 get_world_pos(const int32_t &x,const int32_t& y,const int32_t& z);
    Vector3 get_world_pos(const MGridPos& pos);
    MGridPos get_grid_pos(const Vector3& pos);
    int32_t get_region_id_by_point(const int32_t &x, const int32_t& z);
    MRegion* get_region_by_point(const int32_t &x, const int32_t& z);
    MRegion* get_region(const int32_t &x, const int32_t& z);
    MGridPos get_region_pos_by_world_pos(Vector3 world_pos);
    int8_t get_lod_by_distance(const int32_t& dis);
    void set_cam_pos(const Vector3& cam_world_pos);
    void update_search_bound();
    void cull_out_of_bound();
    void update_lods();
    void merge_chunks();
    bool check_bigger_size(const int8_t& lod,const int8_t& size,const int32_t& region_id, const MBound& bound);
    int8_t get_edge_num(const bool& left,const bool& right,const bool& top,const bool& bottom);


    void set_material(Ref<ShaderMaterial> material);
    Ref<ShaderMaterial> get_material();

    MGridPos get_3d_grid_pos_by_middle_point(MGridPos input);
    real_t get_closest_height(const Vector3& pos);
    real_t get_height(Vector3 pos);
    Ref<MCollision> get_ray_collision_point(Vector3 ray_origin,Vector3 ray_vector,real_t step,int max_step);

    void update_chunks(const Vector3& cam_pos);
    void apply_update_chunks();
    void update_physics(const Vector3& cam_pos);

    Color get_pixel(uint32_t x,uint32_t y, const int32_t& index);
    void set_pixel(uint32_t x,uint32_t y,const Color& col,const int32_t& index);
    real_t get_height_by_pixel(uint32_t x,uint32_t y);
    void set_height_by_pixel(uint32_t x,uint32_t y,const real_t& value);
    bool has_pixel(const uint32_t& x,const uint32_t& y);
    void generate_normals_thread(MPixelRegion pxr);
    void generate_normals(MPixelRegion pxr);
    void save_image(int index,bool force_save);
    bool has_unsave_image();
    void save_all_dirty_images();

    Vector2i get_closest_pixel(Vector3 world_pos);
    Vector3 get_pixel_world_pos(uint32_t x,uint32_t y);

    void set_brush_manager(MBrushManager* input);
    void draw_height(Vector3 brush_pos,real_t radius,int brush_id);
    void draw_height_region(MImage* img, MPixelRegion draw_pixel_region, MPixelRegion local_pixel_region, MHeightBrush* brush);

    void update_all_dirty_image_texture();
};

#endif