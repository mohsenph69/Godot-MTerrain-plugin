#include "mimage.h"
#include <godot_cpp/classes/resource_saver.hpp>
#include <godot_cpp/variant/utility_functions.hpp>


MImage::MImage(const String& _file_path,const String& _name,const String& _uniform_name,const int& _compression){
    file_path = _file_path;
    name = _name;
    uniform_name = _uniform_name;
    compression = _compression;
}

void MImage::load(){
    Ref<Image> img = ResourceLoader::get_singleton()->load(file_path);
    size = img->get_size().x;
    format = img->get_format();
	pixel_size = get_format_pixel_size(format);
    data = img->get_data();
    current_size = size;
	if(pixel_size==0){
		ERR_FAIL_EDMSG("Unsported image format for Mterrain");
	}
	is_save = true;
}

void MImage::create(uint32_t _size, Image::Format _format) {
	size = _size;
	format = _format;
	pixel_size = get_format_pixel_size(format);
	data.resize(size*size*pixel_size);
	current_size = size;
}

PackedByteArray MImage::get_data(int scale) {
    current_size = ((size - 1)/scale) + 1;
	current_scale = scale;
    PackedByteArray output;
    output.resize(current_size*current_size*pixel_size);
    for(int32_t y=0; y < current_size; y++){
        for(int32_t x=0; x < current_size; x++){
            int32_t main_offset = (scale*x+size*y*scale)*pixel_size;
            int32_t new_offset = (x+y*current_size)*pixel_size;
            for(int32_t i=0; i < pixel_size; i++){
                output[new_offset+i] = data[main_offset+i];
            }
        }
    }
    return output;
}

void MImage::update_texture(int scale,bool apply_update){
	update_mutex.lock();
	while (has_texture_to_apply)
	{
		update_mutex.unlock();
		std::this_thread::sleep_for(std::chrono::milliseconds(5));
		update_mutex.lock();
	}
	Ref<ImageTexture> new_tex;
	if(scale > 0){
		PackedByteArray scaled_data = get_data(scale);
		Ref<Image> new_img = Image::create_from_data(current_size,current_size,false,format,scaled_data);
		new_tex = ImageTexture::create_from_image(new_img);
	}
	if(apply_update){
		material->set_shader_parameter(uniform_name, material);
		is_dirty = false;
	} else {
		has_texture_to_apply = true;
		texture_to_apply = new_tex;
	}
	update_mutex.unlock();
}

void MImage::apply_update() {
	update_mutex.lock();
	if(has_texture_to_apply){
		material->set_shader_parameter(uniform_name, texture_to_apply);
		has_texture_to_apply = false;
		is_dirty = false;
	}
	update_mutex.unlock();
}


// This works only for Format_RF
real_t MImage::get_pixel_RF(const uint32_t&x, const uint32_t& y) const {
    uint32_t ofs = (x + y*size);
    return ((float *)data.ptr())[ofs];
}

void MImage::set_pixel_RF(const uint32_t&x, const uint32_t& y,const real_t& value){
	uint32_t ofs = (x + y*size);
	((float *)data.ptrw())[ofs] = value;
	is_dirty = true;
	is_save = false;
}

Color MImage::get_pixel(const uint32_t&x, const uint32_t& y) const {
	uint32_t ofs = (x + y*size);
	return _get_color_at_ofs(data.ptr(), ofs);
}

void MImage::set_pixel(const uint32_t&x, const uint32_t& y,const Color& color){
	uint32_t ofs = (x + y*size);
	_set_color_at_ofs(data.ptrw(), ofs, color);
	is_dirty = true;
	is_save = false;
}


void MImage::save(bool force_save) {
	if(force_save || !is_save){
		Ref<Image> img = Image::create_from_data(size,size,false,format,data);
		ResourceSaver::get_singleton()->save(img,file_path);
		is_save = true;
	}
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


int MImage::get_format_pixel_size(Image::Format p_format) {
	switch (p_format) {
		case Image::FORMAT_L8:
			return 1; //luminance
		case Image::FORMAT_LA8:
			return 2; //luminance-alpha
		case Image::FORMAT_R8:
			return 1;
		case Image::FORMAT_RG8:
			return 2;
		case Image::FORMAT_RGB8:
			return 3;
		case Image::FORMAT_RGBA8:
			return 4;
		case Image::FORMAT_RGBA4444:
			return 2;
		case Image::FORMAT_RGB565:
			return 2;
		case Image::FORMAT_RF:
			return 4; //float
		case Image::FORMAT_RGF:
			return 8;
		case Image::FORMAT_RGBF:
			return 12;
		case Image::FORMAT_RGBAF:
			return 16;
		case Image::FORMAT_RGBE9995:
			return 4;
	}
	return 0;
}