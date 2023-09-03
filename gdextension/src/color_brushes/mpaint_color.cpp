#include "mpaint_color.h"
#include "../mbrush_manager.h"





String MPaintColor::_get_name(){
    return "Color Paint";
}
void MPaintColor::_set_property(String prop_name, Variant value){
    if(prop_name=="color"){
        color = value;
        return;
    }
    if(prop_name=="hardness"){
        hardness = value;
        return;
    }
}
bool MPaintColor::is_two_point_brush(){
    return false;
}
void MPaintColor::before_draw(){

}
void MPaintColor::set_color(const uint32_t& local_x,const uint32_t& local_y,const uint32_t& x,const uint32_t& y,MImage* img){
    img->set_pixel(local_x,local_y,color);
}