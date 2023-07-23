#include "mraise.h"
#include <godot_cpp/variant/utility_functions.hpp>




MRaise::MRaise(){

}
MRaise::~MRaise(){

}
String MRaise::_get_name(){
    return "Raise";
}
//{"name":"name of props", type:Variant_type,hint:"Type hint",hint_string:"", default:default_value, min:min_value, max:max_value}
Array MRaise::_get_property_list(){
    Array props;
    // p1
    Dictionary p1;
    p1["name"] = "hardness";
    p1["type"] = Variant::FLOAT;
    p1["hint"] = "range";
    p1["hint_string"] = "0.001";
    p1["default_value"] = 0.5;
    p1["min"] = 0.0;
    p1["max"] = 0.95;
    //p2
    Dictionary p2;
    p2["name"] = "amount";
    p2["type"] = Variant::FLOAT;
    p2["hint"] = "range";
    p2["hint_string"] = "0.01";
    p2["default_value"] = 0.2;
    p2["min"] = -6;
    p2["max"] = 6;
    props.append(p1);
    props.append(p2);
    return props;
}
void MRaise::_set_property(String prop_name, Variant value){
    if (prop_name == "hardness"){
        hardness = value;
        return;
    } else if (prop_name == "amount")
    {
        amount = value;
        return;
    }
}

bool MRaise::is_two_point_brush(){
    return false;
}

void MRaise::before_draw(){
    
}
float MRaise::get_height(const uint32_t& x,const uint32_t& y){
    Vector3 world_pos = grid->get_pixel_world_pos(x,y);
    real_t dis = grid->brush_world_pos.distance_to(world_pos);
    dis = dis/grid->brush_radius;
    dis = UtilityFunctions::smoothstep(1,hardness,dis)*amount;
    return world_pos.y + dis;
}