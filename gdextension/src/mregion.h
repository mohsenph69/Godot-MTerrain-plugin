#ifndef MREGION
#define MREGION

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/material.hpp>
#include <godot_cpp/classes/shader_material.hpp>
#include <godot_cpp/classes/shader.hpp>
#include <godot_cpp/variant/rid.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/templates/vector.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/shader.hpp>
#include <godot_cpp/templates/vset.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/physics_server3d.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include "mbound.h"
#include "mimage.h"
#include "mpixel_region.h"

class MGrid;

using namespace godot;



class MRegion : public Object{
    GDCLASS(MRegion, Object);

    private:
    //Ref<ShaderMaterial> _material;
    RID _material_rid = RID();
    MImage* heightmap = nullptr;
    MImage* normals = nullptr;
    VSet<int8_t>* lods;
    int8_t last_lod = -2;
    RID physic_body;
    RID heightmap_shape;
    bool has_physic=false;
    double current_image_size = 5;
    int32_t current_scale=1;


    protected:
    static void _bind_methods(){}

    public:
    Vector<MImage*> images;
    float min_height= 1000000000000000;	
    float max_height=-1000000000000000;
    MGrid* grid;
    MGridPos pos;
    Vector3 world_pos;
    MPixelRegion normals_pixel_region; // use for recalculating normals
    //int32_t region_size_meter;
    MRegion* left = nullptr;
    MRegion* right = nullptr;
    MRegion* top = nullptr;
    MRegion* bottom = nullptr;
    static Vector<Vector3> nvecs;
    
    
    MRegion();
    ~MRegion();
    void set_material(RID input);
    RID get_material_rid();
    void add_image(MImage* input);
    void configure();
    void update_region();
    void insert_lod(const int8_t& input);
    void apply_update();
    void create_physics();
    void remove_physics();
    Color get_pixel(const uint32_t& x, const uint32_t& y, const int32_t& index) const;
    void set_pixel(const uint32_t& x, const uint32_t& y,const Color& color,const int32_t& index);
    Color get_normal_by_pixel(const uint32_t& x, const uint32_t& y) const;
    void set_normal_by_pixel(const uint32_t& x, const uint32_t& y,const Color& value);
    real_t get_height_by_pixel(const uint32_t& x, const uint32_t& y) const;
    void set_height_by_pixel(const uint32_t& x, const uint32_t& y,const real_t& value);
    real_t get_closest_height(Vector3 pos);
    real_t get_height_by_pixel_in_layer(const uint32_t& x, const uint32_t& y) const;

    void update_all_dirty_image_texture();
    void save_image(int index,bool force_save);

    void recalculate_normals();
    void refresh_all_uniforms();
};
#endif