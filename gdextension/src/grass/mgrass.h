#ifndef MGRASS
#define MGRASS

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/rendering_server.hpp>
#include "mgrass_data.h"


using namespace godot;

class MGrid;

struct MGrassChunk // Rendering server multi mesh data
{
    RID multimesh;
    RID instance;
    int id=-1;
    int lod;
    bool is_relax=true;
    MGrassChunk(RID scenario, RID mesh_rid, RID material,int _lod){
        multimesh = RenderingServer::get_singleton()->multimesh_create();
        RenderingServer::get_singleton()->multimesh_set_mesh(multimesh, mesh_rid);
        instance = RenderingServer::get_singleton()->instance_create();
        RenderingServer::get_singleton()->instance_set_base(instance, multimesh);
        RenderingServer::get_singleton()->instance_geometry_set_material_overlay(instance,material);
        RenderingServer::get_singleton()->instance_set_scenario(instance,scenario);
        RenderingServer::get_singleton()->instance_set_visible(instance,false);
        lod = _lod;
    }
    ~MGrassChunk(){
        RenderingServer::get_singleton()->free_rid(multimesh);
        RenderingServer::get_singleton()->free_rid(instance);
    }
    void relax(){
        RenderingServer::get_singleton()->instance_set_visible(instance,false);
        is_relax = true;
    }
    void unrelax(){
        RenderingServer::get_singleton()->instance_set_visible(instance,true);
        is_relax = false;
    }
    void set_buffer(int count, const PackedFloat32Array& data){
        RenderingServer::get_singleton()->multimesh_allocate_data(multimesh, count, RenderingServer::MULTIMESH_TRANSFORM_3D, false, false);
        RenderingServer::get_singleton()->multimesh_set_buffer(multimesh, data);
    }
};


class MGrass : public Node3D {
    GDCLASS(MGrass,Node3D);

    protected:
    static void _bind_methods();

    public:
    bool is_grass_init = false;
    Ref<MGrassData> grass_data;
    MGrid* grid = nullptr;
    int grass_in_cell=1;
    uint32_t grass_region_pixel_size;
    int lod_count;
    int min_grass_cutoff=5;
    Array materials;
    Array meshes;

    MGrass();
    ~MGrass();
    void init_grass(MGrid* grid);
    void clear_grass();
    void recalculate_grass_config(int max_lod);
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