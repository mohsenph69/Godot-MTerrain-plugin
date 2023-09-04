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
        hardness = UtilityFunctions::clamp(value,0.0,0.99);
        return;
    }
}
bool MPaintColor::is_two_point_brush(){
    return false;
}
void MPaintColor::before_draw(){

}
void MPaintColor::set_color(uint32_t local_x,uint32_t local_y,uint32_t x,uint32_t y,MImage* img){
    uint32_t dx = abs(x - grid->brush_px_pos_x);
    uint32_t dy = abs(y - grid->brush_px_pos_y);
    float px_dis = (float)sqrt(dx*dx + dy*dy);
    px_dis /= (float)grid->brush_px_radius;
    float w = UtilityFunctions::smoothstep(1,hardness,px_dis);
    Color bg_color = grid->get_pixel(x,y,grid->current_paint_index);
    bg_color = bg_color.lerp(color,w);
    img->set_pixel(local_x,local_y,bg_color);
}