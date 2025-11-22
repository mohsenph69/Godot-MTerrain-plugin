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
#include <godot_cpp/templates/hash_map.hpp>

#include "mbound.h"
#include "mresource.h"


using namespace godot;

class MRegion;

struct MImageRGB8 {
	uint8_t r;
	uint8_t g;
	uint8_t b;
};

struct MImageUndoData {
    int layer;
    bool empty=false;// In case the layer is empty at this data
    uint8_t* data;

    void free(){
        if(!empty)
            memdelete_arr(data);
    }
};

struct MImage {
    int index=-1;
    MRegion* region=nullptr;
    StringName name;
    String uniform_name;
    int compression=-1;
    uint32_t width;
    uint32_t height;
    uint32_t current_size;
    uint32_t current_scale = 1;
    uint32_t pixel_size;
    uint32_t total_pixel_amount;
    Image::Format format = Image::Format::FORMAT_MAX; //Setting an invalid format so in case it is not set we can generate error
    PackedByteArray data;
    #ifdef M_IMAGE_LAYER_ON
    int active_layer=0;
    int holes_layer=-1;
    PackedStringArray layer_names;
    Vector<PackedByteArray*> image_layers;
    Vector<bool> is_saved_layers;
    #endif
    RID old_tex_rid;
    RID new_tex_rid;
    bool has_texture_to_apply = false;
    bool is_dirty = false;
    bool is_save = false;
    MGridPos grid_pos;
    std::mutex update_mutex;
    std::recursive_mutex load_mutex;//Any method which read/write the data or layer data exept for pixel modification as that would be expensive, for pixel modifcation we should do some higher level lock 
    bool active_undo=false;
    int current_undo_id;
    // Key is undo redo id
    HashMap<int,MImageUndoData> undo_data;
    bool is_init=false;
    bool is_corrupt_file = false;
    bool is_null_image=true;
    bool is_ram_image=false; // in case the image exist only on RAM not VRAM
    
    MImage();
    MImage(const String& _name,const String& _uniform_name,MGridPos _grid_pos,MRegion* r);
    ~MImage();
    void load(Ref<MResource> mres);
    void unload(Ref<MResource> mres);
    void set_active_layer(int l);
    void add_layer(String lname);
    void rename_layer(int layer_index,String new_name);
    void merge_layer();
    void remove_layer(bool is_visible);
    void layer_visible(bool input);
    void create(uint32_t _size, Image::Format _format);
    // This create bellow should not be used for terrain, It is for other stuff
    void create(uint32_t _width,uint32_t _height, Image::Format _format);
    // get data with custom scale
    void get_data(PackedByteArray* out,int scale);
    void update_texture(int scale,bool apply_update);
    void apply_update();
    // This works only for Format_RF
    _FORCE_INLINE_ real_t get_pixel_RF(const uint32_t x, const uint32_t  y) const;
    _FORCE_INLINE_ void set_pixel_RF(const uint32_t x, const uint32_t  y,const real_t value);
	_FORCE_INLINE_ void set_pixel_rgb8(const uint32_t x,const uint32_t y,MImageRGB8 rgb);
	_FORCE_INLINE_ MImageRGB8 get_pixel_rgb8(const uint32_t x,const uint32_t y) const;
    _FORCE_INLINE_ real_t get_pixel_RF_in_layer(const uint32_t x, const uint32_t  y) const;
    _FORCE_INLINE_ Color get_pixel(const uint32_t x, const uint32_t  y) const;
    _FORCE_INLINE_ void set_pixel(const uint32_t x, const uint32_t  y,const Color& color);
    _FORCE_INLINE_ void set_pixel_by_data_pointer(uint32_t x,uint32_t y,uint8_t* ptr);
    _FORCE_INLINE_ const uint8_t* get_pixel_by_data_pointer(uint32_t x,uint32_t y) const;
    bool save(Ref<MResource> mres,bool force_save);
    void check_undo(); // Register the state of image before the draw
    void remove_undo_data(int ur_id);
    void remove_undo_data_in_layer(int layer_index);
    bool go_to_undo(int ur_id);
    bool has_undo(int ur_id);

    // This functions exist in godot source code
	_FORCE_INLINE_ Color _get_color_at_ofs(const uint8_t *ptr, uint32_t ofs) const;
	_FORCE_INLINE_ void _set_color_at_ofs(uint8_t *ptr, uint32_t ofs, const Color &p_color);
    static int get_format_pixel_size(Image::Format p_format);
    static int get_format_uint_channel_count(Image::Format p_format);

    void set_pixel_in_channel(const uint32_t x, const uint32_t  y,int8_t channel,const float value);
    float get_pixel_in_channel(const uint32_t x, const uint32_t  y,int8_t channel);


    private:
    void load_layer(String lname);
    _FORCE_INLINE_ String get_layer_data_dir();
};



// This works only for Format_RF
real_t MImage::get_pixel_RF(const uint32_t x, const uint32_t  y) const {
	if(is_null_image || !is_init){
		return 0;
	}
	uint32_t ofs = (x + y*width);
    return ((float *)data.ptr())[ofs];
}

void MImage::set_pixel_RF(const uint32_t x, const uint32_t  y,const real_t value){
	if(is_null_image || !is_init){
		return;
	}
	check_undo();
	// not visibile layers should not be modified but as this called many times
	// it is better to check that in upper level
	uint32_t ofs = (x + y*width);
	#ifdef M_IMAGE_LAYER_ON
	// For when we have only background layer
	if(active_layer==0){
		((float *)data.ptrw())[ofs] = value;
		is_saved_layers.set(0,false);
		is_dirty = true;
		is_save = false;
		return;
	}
	// Check if we the layer is empty we resize that
	if(image_layers[active_layer]->size()!=data.size()){
		image_layers[active_layer]->resize(data.size());
		if(active_layer==holes_layer){ // Initialzation in case it is a holes layer
			float* ptrw = (float*)image_layers[active_layer]->ptrw();
			for(int i=0; i < total_pixel_amount; i++){
				ptrw[i] = std::numeric_limits<float>::quiet_NaN();
			}
		}
	}
	is_saved_layers.set(active_layer,false);
	if(std::isnan(value)){
		if(!std::isnan(((float *)data.ptr())[ofs])){
			((float *)image_layers[active_layer]->ptrw())[ofs] = ((float *)data.ptr())[ofs];
		}
		((float *)data.ptrw())[ofs] = value;
	} else if(std::isnan(((float *)data.ptr())[ofs])) {
		((float *)data.ptrw())[ofs] = ((float *)image_layers[active_layer]->ptr())[ofs];
		((float *)image_layers[active_layer]->ptrw())[ofs] = std::numeric_limits<float>::quiet_NaN();
	} else {
		float dif = value - ((float *)data.ptr())[ofs];
		((float *)image_layers[active_layer]->ptrw())[ofs] += dif;
		((float *)data.ptrw())[ofs] = value;
	}
	#else
	((float *)data.ptrw())[ofs] = value;
	#endif
	is_dirty = true;
	is_save = false;
}

void MImage::set_pixel_rgb8(const uint32_t x, const uint32_t y, MImageRGB8 rgb)
{
	if(unlikely(!is_init)) return;
	uint32_t ofs = (x + y*width) * 3;
	uint8_t* ptr = data.ptrw();
	ptr[ofs] = rgb.r;
	ptr[ofs + 1] = rgb.g;
	ptr[ofs + 2] = rgb.b;
}

MImageRGB8 MImage::get_pixel_rgb8(const uint32_t x, const uint32_t y) const
{
	uint32_t ofs = (x + y*width) * 3;
	const uint8_t* ptr = data.ptr() + ofs;
	return {ptr[0], ptr[1], ptr[2]};
}

real_t MImage::get_pixel_RF_in_layer(const uint32_t x, const uint32_t  y) const {
	if(unlikely(!is_init)){
		return 0.0;
	}
	if(image_layers[active_layer]->size()==0 || is_null_image){
		return 0.0;
	}
	uint32_t ofs = (x + y*width);
	return ((float *)image_layers[active_layer]->ptr())[ofs];
}

Color MImage::get_pixel(const uint32_t x, const uint32_t  y) const {
	if(unlikely(is_null_image||!is_init)){
		return Color();
	}
	uint32_t ofs = (x + y*width);
	return _get_color_at_ofs(data.ptr(), ofs);
}

void MImage::set_pixel(const uint32_t x, const uint32_t  y,const Color& color){
	if(is_null_image || !is_init){
		return;
	}
	check_undo();
	uint32_t ofs = (x + y*width);
	_set_color_at_ofs(data.ptrw(), ofs, color);
	is_dirty = true;
	is_save = false;
}

void MImage::set_pixel_by_data_pointer(uint32_t x,uint32_t y,uint8_t* ptr){
	if(is_null_image || !is_init){
		return;
	}
	check_undo();
	uint32_t ofs = (x + y*width);
	uint8_t* ptrw = data.ptrw() + ofs*pixel_size;
	memcpy(ptrw,ptr,pixel_size);
	is_dirty = true;
	is_save = false;
}

const uint8_t* MImage::get_pixel_by_data_pointer(uint32_t x,uint32_t y) const {
	if(is_null_image || !is_init){
		return nullptr;
	}
	uint32_t ofs = (x + y*width);
	return data.ptr() + ofs*pixel_size;
}



Color MImage::_get_color_at_ofs(const uint8_t *ptr, uint32_t ofs) const {
	switch (format) {
		case Image::FORMAT_L8: {
			float l = ptr[ofs] / 255.0;
			return Color(l, l, l, 1);
		}
		case Image::FORMAT_LA8: {
			float l = ptr[ofs * 2 + 0] / 255.0;
			float a = ptr[ofs * 2 + 1] / 255.0;
			return Color(l, l, l, a);
		}
		case Image::FORMAT_R8: {
			float r = ptr[ofs] / 255.0;
			return Color(r, 0, 0, 1);
		}
		case Image::FORMAT_RG8: {
			float r = ptr[ofs * 2 + 0] / 255.0;
			float g = ptr[ofs * 2 + 1] / 255.0;
			return Color(r, g, 0, 1);
		}
		case Image::FORMAT_RGB8: {
			float r = ptr[ofs * 3 + 0] / 255.0;
			float g = ptr[ofs * 3 + 1] / 255.0;
			float b = ptr[ofs * 3 + 2] / 255.0;
			return Color(r, g, b, 1);
		}
		case Image::FORMAT_RGBA8: {
			float r = ptr[ofs * 4 + 0] / 255.0;
			float g = ptr[ofs * 4 + 1] / 255.0;
			float b = ptr[ofs * 4 + 2] / 255.0;
			float a = ptr[ofs * 4 + 3] / 255.0;
			return Color(r, g, b, a);
		}
		case Image::FORMAT_RGBA4444: {
			uint16_t u = ((uint16_t *)ptr)[ofs];
			float r = ((u >> 12) & 0xF) / 15.0;
			float g = ((u >> 8) & 0xF) / 15.0;
			float b = ((u >> 4) & 0xF) / 15.0;
			float a = (u & 0xF) / 15.0;
			return Color(r, g, b, a);
		}
		case Image::FORMAT_RGB565: {
			uint16_t u = ((uint16_t *)ptr)[ofs];
			float r = (u & 0x1F) / 31.0;
			float g = ((u >> 5) & 0x3F) / 63.0;
			float b = ((u >> 11) & 0x1F) / 31.0;
			return Color(r, g, b, 1.0);
		}
		case Image::FORMAT_RF: {
			float r = ((float *)ptr)[ofs];
			return Color(r, 0, 0, 1);
		}
		case Image::FORMAT_RGF: {
			float r = ((float *)ptr)[ofs * 2 + 0];
			float g = ((float *)ptr)[ofs * 2 + 1];
			return Color(r, g, 0, 1);
		}
		case Image::FORMAT_RGBF: {
			float r = ((float *)ptr)[ofs * 3 + 0];
			float g = ((float *)ptr)[ofs * 3 + 1];
			float b = ((float *)ptr)[ofs * 3 + 2];
			return Color(r, g, b, 1);
		}
		case Image::FORMAT_RGBAF: {
			float r = ((float *)ptr)[ofs * 4 + 0];
			float g = ((float *)ptr)[ofs * 4 + 1];
			float b = ((float *)ptr)[ofs * 4 + 2];
			float a = ((float *)ptr)[ofs * 4 + 3];
			return Color(r, g, b, a);
		}
		case Image::FORMAT_RGBE9995: {
			return Color::from_rgbe9995(((uint32_t *)ptr)[ofs]);
		}
		default: {
			ERR_FAIL_V_MSG(Color(), "Unsportet format for Mterrain");
		}
	}
}

void MImage::_set_color_at_ofs(uint8_t *ptr, uint32_t ofs, const Color &p_color) {
	check_undo();
	switch (format) {
		case Image::FORMAT_L8: {
			ptr[ofs] = uint8_t(CLAMP(p_color.get_v() * 255.0, 0, 255));
		} break;
		case Image::FORMAT_LA8: {
			ptr[ofs * 2 + 0] = uint8_t(CLAMP(p_color.get_v() * 255.0, 0, 255));
			ptr[ofs * 2 + 1] = uint8_t(CLAMP(p_color.a * 255.0, 0, 255));
		} break;
		case Image::FORMAT_R8: {
			ptr[ofs] = uint8_t(CLAMP(p_color.r * 255.0, 0, 255));
		} break;
		case Image::FORMAT_RG8: {
			ptr[ofs * 2 + 0] = uint8_t(CLAMP(p_color.r * 255.0, 0, 255));
			ptr[ofs * 2 + 1] = uint8_t(CLAMP(p_color.g * 255.0, 0, 255));
		} break;
		case Image::FORMAT_RGB8: {
			ptr[ofs * 3 + 0] = uint8_t(CLAMP(p_color.r * 255.0, 0, 255));
			ptr[ofs * 3 + 1] = uint8_t(CLAMP(p_color.g * 255.0, 0, 255));
			ptr[ofs * 3 + 2] = uint8_t(CLAMP(p_color.b * 255.0, 0, 255));
		} break;
		case Image::FORMAT_RGBA8: {
			ptr[ofs * 4 + 0] = uint8_t(CLAMP(p_color.r * 255.0, 0, 255));
			ptr[ofs * 4 + 1] = uint8_t(CLAMP(p_color.g * 255.0, 0, 255));
			ptr[ofs * 4 + 2] = uint8_t(CLAMP(p_color.b * 255.0, 0, 255));
			ptr[ofs * 4 + 3] = uint8_t(CLAMP(p_color.a * 255.0, 0, 255));

		} break;
		case Image::FORMAT_RGBA4444: {
			uint16_t rgba = 0;

			rgba = uint16_t(CLAMP(p_color.r * 15.0, 0, 15)) << 12;
			rgba |= uint16_t(CLAMP(p_color.g * 15.0, 0, 15)) << 8;
			rgba |= uint16_t(CLAMP(p_color.b * 15.0, 0, 15)) << 4;
			rgba |= uint16_t(CLAMP(p_color.a * 15.0, 0, 15));

			((uint16_t *)ptr)[ofs] = rgba;

		} break;
		case Image::FORMAT_RGB565: {
			uint16_t rgba = 0;

			rgba = uint16_t(CLAMP(p_color.r * 31.0, 0, 31));
			rgba |= uint16_t(CLAMP(p_color.g * 63.0, 0, 33)) << 5;
			rgba |= uint16_t(CLAMP(p_color.b * 31.0, 0, 31)) << 11;

			((uint16_t *)ptr)[ofs] = rgba;

		} break;
		case Image::FORMAT_RF: {
			((float *)ptr)[ofs] = p_color.r;
		} break;
		case Image::FORMAT_RGF: {
			((float *)ptr)[ofs * 2 + 0] = p_color.r;
			((float *)ptr)[ofs * 2 + 1] = p_color.g;
		} break;
		case Image::FORMAT_RGBF: {
			((float *)ptr)[ofs * 3 + 0] = p_color.r;
			((float *)ptr)[ofs * 3 + 1] = p_color.g;
			((float *)ptr)[ofs * 3 + 2] = p_color.b;
		} break;
		case Image::FORMAT_RGBAF: {
			((float *)ptr)[ofs * 4 + 0] = p_color.r;
			((float *)ptr)[ofs * 4 + 1] = p_color.g;
			((float *)ptr)[ofs * 4 + 2] = p_color.b;
			((float *)ptr)[ofs * 4 + 3] = p_color.a;
		} break;
		case Image::FORMAT_RGBE9995: {
			((uint32_t *)ptr)[ofs] = p_color.to_rgbe9995();

		} break;
		default: {
			ERR_FAIL_MSG("Can't set_pixel() on compressed image, sorry.");
		}
	}
}

#endif