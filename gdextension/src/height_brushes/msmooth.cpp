#include "msmooth.h"




MSmooth::MSmooth(){

}
MSmooth::~MSmooth(){

}
String MSmooth::_get_name(){
    return "Smooth";
}
Array MSmooth::_get_property_list(){
    Array props;
    // p1
    Dictionary p1;
    p1["name"] = "mode";
    p1["type"] = Variant::INT;
    p1["hint"] = "enum";
    p1["hint_string"] = "AVERAGE,GAUSSIAN";
    p1["default_value"] = 1;
    p1["min"] = 0;
    p1["max"] = 2;
    // p2
    Dictionary p2;
    p2["name"] = "amount";
    p2["type"] = Variant::FLOAT;
    p2["hint"] = "range";
    p2["hint_string"] = "0.01";
    p2["default_value"] = 0.5;
    p2["min"] = 0;
    p2["max"] = 1;
    props.append(p1);
    props.append(p2);
    return props;
}
void MSmooth::_set_property(String prop_name, Variant value){
    if(prop_name=="mode"){
        mode = value;
        return;
    }
    if(prop_name=="amount"){
        amount = value;
        return;
    }
}

bool MSmooth::is_two_point_brush(){
    return false;
}

void MSmooth::before_draw(){

}
float MSmooth::get_height(const uint32_t& x,const uint32_t& y){
    if(mode==0){
        float total = 1;
        float h = grid->get_height_by_pixel(x,y);
        float toh = h;
        if(grid->has_pixel(x-1,y-1)) { toh += grid->get_height_by_pixel(x-1,y-1); total+=1; }
        if(grid->has_pixel(x,y-1)) { toh += grid->get_height_by_pixel(x,y-1); total+=1; }
        if(grid->has_pixel(x+1,y-1)) { toh += grid->get_height_by_pixel(x+1,y-1); total+=1; }
        if(grid->has_pixel(x-1,y)) { toh += grid->get_height_by_pixel(x-1,y); total+=1; }
        if(grid->has_pixel(x+1,y)) { toh += grid->get_height_by_pixel(x+1,y); total+=1; }
        if(grid->has_pixel(x-1,y+1)) { toh += grid->get_height_by_pixel(x-1,y+1); total+=1; }
        if(grid->has_pixel(x,y+1)) { toh += grid->get_height_by_pixel(x,y+1); total+=1; }
        if(grid->has_pixel(x+1,y+1)) { toh += grid->get_height_by_pixel(x+1,y+1); total+=1; }
        return (toh/total -h)*amount + h;
    } else {
        float total = 4;
        float h = grid->get_height_by_pixel(x,y);
        float toh = h*4.0;
        if(grid->has_pixel(x-1,y-1)) { toh += grid->get_height_by_pixel(x-1,y-1); total+=1; }
        if(grid->has_pixel(x,y-1)) { toh += grid->get_height_by_pixel(x,y-1)*2.0; total+=2; }
        if(grid->has_pixel(x+1,y-1)) { toh += grid->get_height_by_pixel(x+1,y-1); total+=1; }
        if(grid->has_pixel(x-1,y)) { toh += grid->get_height_by_pixel(x-1,y)*2.0; total+=2; }
        if(grid->has_pixel(x+1,y)) { toh += grid->get_height_by_pixel(x+1,y)*2.0; total+=2; }
        if(grid->has_pixel(x-1,y+1)) { toh += grid->get_height_by_pixel(x-1,y+1); total+=1; }
        if(grid->has_pixel(x,y+1)) { toh += grid->get_height_by_pixel(x,y+1)*2.0; total+=2; }
        if(grid->has_pixel(x+1,y+1)) { toh += grid->get_height_by_pixel(x+1,y+1); total+=1; }
        return (toh/total -h)*amount + h;
    }
}