#include "mraw16.h"

#include <godot_cpp/variant/utility_functions.hpp>


void MRaw16::_bind_methods() {
   ClassDB::bind_static_method("MRaw16", D_METHOD("get_image","file_path","width","height","min_height","max_height","is_half"), &MRaw16::get_image);
   ClassDB::bind_static_method("MRaw16", D_METHOD("get_texture","file_path","width","height","min_height","max_height","is_half"), &MRaw16::get_texture); 
}


MRaw16::MRaw16()
{
}

MRaw16::~MRaw16()
{
}


Ref<Image> MRaw16::get_image(const String& file_path, const uint64_t width, const uint64_t height,double min_height, double max_height,const bool is_half) {
    Ref<Image> img;
    UtilityFunctions::print("open: ", file_path);
    if(!FileAccess::file_exists(file_path)){
        ERR_FAIL_COND_V("File does not exist check your file path again", img);
    }
    Ref<FileAccess> file = FileAccess::open(file_path, FileAccess::READ);
    if(file->get_error() != godot::OK){
        ERR_FAIL_COND_V("Can not open the file", img);
    }
    uint64_t final_width = width;
    uint64_t final_height = height;
    uint64_t size = file->get_length();
    uint64_t size16 = size/2;
    if(width==0 || height==0){
        final_width = sqrt(size16);
        if(final_width*final_width*2 != size){
            ERR_FAIL_COND_V("Image width is not valid please set width and height", img);
        }
        final_height = final_width;
    } else {
        if(width*height != size16){
            ERR_FAIL_COND_V("Image width or height is not valid", img);
        }
    }
    if(is_half){
        PackedByteArray data;
        data.resize(size);
        uint64_t offset = 0;
        for(int i = 0; i<size16; i++){
            double p = (double)file->get_16()/65535;
            p *= (max_height - min_height);
            p += min_height;
            data.encode_half(offset, p);
            offset += 2;
        }
        img = Image::create_from_data(final_width,final_height,false, Image::FORMAT_RH, data);
    } else {
        PackedFloat32Array dataf;
        for(int i = 0; i<size16; i++){
            double p = (double)file->get_16()/65535;
            p *= (max_height - min_height);
            p += min_height;
            dataf.append(p);
        }
        img = Image::create_from_data(final_width,final_height,false, Image::FORMAT_RF, dataf.to_byte_array());
    }
    return img;
}



Ref<ImageTexture> MRaw16::get_texture(const String& file_path, const uint64_t width, const uint64_t height,double min_height, double max_height,const bool is_half){
    Ref<Image> img = MRaw16::get_image(file_path, width, height,min_height,max_height,is_half);
    Ref<ImageTexture> tex;
    if(img.is_valid()){
        tex = ImageTexture::create_from_image(img);
    }
    return tex;
}
