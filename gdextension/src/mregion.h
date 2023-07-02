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
#include "mbound.h"

class MGrid;

using namespace godot;



struct MImageInfo {
    String file_path;
    String name;
    String uniform_name;
    int compression;
    int32_t size; // Width or height , because they are equal
    Image::Format format;
    PackedByteArray data;
    MImageInfo(const String& _file_path,const String& _name,const String& _uniform_name,const int& _compression){
        file_path = _file_path;
        name = _name;
        uniform_name = _uniform_name;
        compression = _compression;
        load();
    }
    void load(){
        Ref<Image> img = ResourceLoader::get_singleton()->load(file_path);
        size = img->get_size().x;
        format = img->get_format();
        data = img->get_data();
    }
    // This works only for Format_RF
    real_t get_pixel_RF(const int32_t&x, const int32_t& y){
        int32_t ofs = (x + y*size);
        return ((float *)data.ptr())[ofs];
    }
};

struct MUpdateInfo
{
    StringName uniform;
    Ref<ImageTexture> tex;
};




class MRegion : public Object{
    GDCLASS(MRegion, Object);

    private:
    Ref<ShaderMaterial> _material;
    Vector<MImageInfo*> images;
    MImageInfo* heightmap = nullptr;
    Vector<MUpdateInfo> update_info;
    String shader_code;
    VSet<int8_t>* lods;
    int8_t last_lod = -2;
    RID physic_body;
    RID heightmap_shape;
    bool has_physic=false;
    double current_image_size = 5;


    protected:
    static void _bind_methods(){}

    public:
    float min_height= 1000000000000000;	
    float max_height=-1000000000000000;
    MGrid* grid;
    MGridPos pos;
    Vector3 world_pos;
    //int32_t region_size_meter;
    MRegion* left = nullptr;
    MRegion* right = nullptr;
    MRegion* top = nullptr;
    MRegion* bottom = nullptr;
    static int number_of_tex_update;
    
    
    MRegion();
    ~MRegion();
    void set_material(const Ref<ShaderMaterial> input);
    RID get_material_rid();
    void update_material(Ref<ShaderMaterial> mat);
    void set_image_info(MImageInfo* input);
    void update_region();
    void insert_lod(const int8_t& input);
    void apply_update();
    Ref<ImageTexture> get_texture(MImageInfo* info,int8_t lod);
    void create_physics();
    void remove_physics();

    real_t get_closest_height(Vector3 pos);

    // This function exist in godot source code
    // But unfortunatlly it is not expose in GDExtension
    // Beacause of this I have to copy that here
    // later if they expose this we can remove this
    static int get_format_pixel_size(Image::Format p_format);
};
#endif