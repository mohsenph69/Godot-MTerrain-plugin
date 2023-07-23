#ifndef MIMAGE
#define MIMAGE

#include "mconfig.h"

#include <mutex>
#include <thread>
#include <chrono>

#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/templates/vector.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/shader_material.hpp>
#include <godot_cpp/classes/image_texture.hpp>

#include "mbound.h"


using namespace godot;


struct MImage {
    String file_path;
    String layerDataDir;
    String name;
    String uniform_name;
    int compression=-1;
    uint32_t width;
    uint32_t height;
    uint32_t current_size;
    uint32_t current_scale = 1;
    uint32_t pixel_size;
    uint32_t total_pixel_amount;
    Image::Format format;
    PackedByteArray data;
    #ifdef M_IMAGE_LAYER_ON
    int active_layer=0;
    PackedStringArray layer_names;
    Vector<PackedByteArray*> image_layers;
    Vector<bool> is_saved_layers;
    #endif
    Ref<ShaderMaterial> material;
    Ref<ImageTexture> texture_to_apply;
    bool has_texture_to_apply = false;
    bool is_dirty = false;
    bool is_save = false;
    MGridPos grid_pos;
    std::mutex update_mutex;
    
    MImage();
    MImage(const String& _file_path,const String& _layers_folder,const String& _name,const String& _uniform_name,MGridPos _grid_pos,const int& _compression);
    void load();
    void add_layer(String lname);
    void create(uint32_t _size, Image::Format _format);
    // This create bellow should not be used for terrain, It is for other stuff
    void create(uint32_t _width,uint32_t _height, Image::Format _format);
    // get data with custom scale
    PackedByteArray get_data(int scale);
    void update_texture(int scale,bool apply_update);
    void apply_update();
    // This works only for Format_RF
    real_t get_pixel_RF(const uint32_t&x, const uint32_t& y) const;
    void set_pixel_RF(const uint32_t&x, const uint32_t& y,const real_t& value);
    Color get_pixel(const uint32_t&x, const uint32_t& y) const;
    void set_pixel(const uint32_t&x, const uint32_t& y,const Color& color);
    void save(bool force_save);


    // This functions exist in godot source code
	_FORCE_INLINE_ Color _get_color_at_ofs(const uint8_t *ptr, uint32_t ofs) const;
	_FORCE_INLINE_ void _set_color_at_ofs(uint8_t *ptr, uint32_t ofs, const Color &p_color);
    static int get_format_pixel_size(Image::Format p_format);

};


enum MImageBlendMode {
    mix,
    add
};



#endif