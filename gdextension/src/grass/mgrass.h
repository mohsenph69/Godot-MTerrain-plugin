#ifndef MGRASS
#define MGRASS

#define BUFFER_STRID_FLOAT 12
#define BUFFER_STRID_BYTE 48

#include <mutex>

#include <godot_cpp/templates/vector.hpp>
#include <godot_cpp/templates/vset.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/rendering_server.hpp>
#include "mgrass_data.h"
#include "../mpixel_region.h"


using namespace godot;

class MGrid;

struct MGrassChunk // Rendering server multi mesh data
{
    RID multimesh;
    RID instance;
    Vector3 world_pos;
    int count=0;
    int lod;
    int region_id;
    MPixelRegion pixel_region;
    bool is_relax=true;

    MGrassChunk(const MPixelRegion& _pixel_region,Vector3 _world_pos, int _lod,int _region_id){
        pixel_region = _pixel_region;
        lod = _lod;
        region_id = _region_id;
        world_pos = _world_pos;
    }
    ~MGrassChunk(){
        if(count!=0){
            RenderingServer::get_singleton()->free_rid(multimesh);
            RenderingServer::get_singleton()->free_rid(instance);
        }
    }
    void relax(){
        if(count!=0){
            RenderingServer::get_singleton()->instance_set_visible(instance,false);
        }
        is_relax = true;
    }
    void unrelax(){
        if(count!=0){
            RenderingServer::get_singleton()->instance_set_visible(instance,true);
        }
        is_relax = false;
    }
    void set_buffer(int _count,RID scenario, RID mesh_rid, RID material ,const PackedFloat32Array& data){
        if(_count!=0 && count == 0){
            multimesh = RenderingServer::get_singleton()->multimesh_create();
            RenderingServer::get_singleton()->multimesh_set_mesh(multimesh, mesh_rid);
            instance = RenderingServer::get_singleton()->instance_create();
            RenderingServer::get_singleton()->instance_set_base(instance, multimesh);
            RenderingServer::get_singleton()->instance_geometry_set_material_overlay(instance,material);
            RenderingServer::get_singleton()->instance_set_scenario(instance,scenario);
        } else if(_count==0 && count!=0){
            RenderingServer::get_singleton()->free_rid(multimesh);
            RenderingServer::get_singleton()->free_rid(instance);
            instance = RID();
            multimesh = RID();
            count = 0;
            return;
        } else if(_count==0 && count==0){
            return;
        }
        count = _count;
        RenderingServer::get_singleton()->multimesh_allocate_data(multimesh, _count, RenderingServer::MULTIMESH_TRANSFORM_3D, false, false);
        RenderingServer::get_singleton()->multimesh_set_buffer(multimesh, data);
    }
};


class MGrass : public Node3D {
    GDCLASS(MGrass,Node3D);
    private:
    uint64_t update_id;
    std::mutex update_mutex;

    protected:
    static void _bind_methods();

    public:
    bool is_grass_init = false;
    RID scenario;
    Ref<MGrassData> grass_data;
    MGrid* grid = nullptr;
    int grass_in_cell=1;
    uint32_t base_grid_size_in_pixel;
    uint32_t grass_region_pixel_width; // Width or Height both are equal
    uint32_t grass_region_pixel_size; // Total pixel size for each region
    uint32_t region_grid_width;
    uint32_t width;
    uint32_t height;
    MPixelRegion grass_pixel_region;
    int lod_count;
    int min_grass_cutoff=5;
    Array materials;
    Array meshes;
    Vector<RID> material_rids;
    Vector<RID> meshe_rids;
    HashMap<int64_t,MGrassChunk*> grid_to_grass;
    Vector<MGrassChunk*> to_be_visible;
    VSet<int>* dirty_points_id;

    MGrass();
    ~MGrass();
    void init_grass(MGrid* _grid);
    void clear_grass();
    void update_grass();
    void update_dirty_chunks();
    void apply_update_grass();
    void create_grass_chunk(int grid_index,MGrassChunk* grass_chunk=nullptr);
    void recalculate_grass_config(int max_lod);

    void set_grass_by_pixel(uint32_t px, uint32_t py, bool p_value);
    bool get_grass_by_pixel(uint32_t px, uint32_t py);
    Vector2i get_closest_pixel(Vector3 pos);
    void draw_grass(Vector3 brush_pos,real_t radius,bool add);

    void set_grass_data(Ref<MGrassData> d);
    Ref<MGrassData> get_grass_data();
    void set_grass_in_cell(int input);
    int get_grass_in_cell();
    void set_min_grass_cutoff(int input);
    int get_min_grass_cutoff();
    void set_meshes(Array input);
    Array get_meshes();
    void set_materials(Array input);
    Array get_materials();


    void _get_property_list(List<PropertyInfo> *p_list) const;
    bool _get(const StringName &p_name, Variant &r_ret) const;
    bool _set(const StringName &p_name, const Variant &p_value);

};
#endif