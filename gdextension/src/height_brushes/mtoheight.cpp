#include "mtoheight.h"

#include <godot_cpp/variant/utility_functions.hpp>


MToHeight::MToHeight(){

}
MToHeight::~MToHeight(){

}
String MToHeight::_get_name(){
    return "To Height";
}
Array MToHeight::_get_property_list(){
    Array props;
    // p1
    Dictionary p1;
    p1["name"] = "weight";
    p1["type"] = Variant::FLOAT;
    p1["hint"] = "range";
    p1["hint_string"] = "0.01";
    p1["default_value"] = 0.5;
    p1["min"] = 0.1;
    p1["max"] = 1.0;
    //p2
    Dictionary p2;
    p2["name"] = "hardness";
    p2["type"] = Variant::FLOAT;
    p2["hint"] = "range";
    p2["hint_string"] = "0.01";
    p2["default_value"] = 0.9;
    p2["min"] = 0.1;
    p2["max"] = 0.95;
    //p3
    Dictionary p3;
    p3["name"] = "offset";
    p3["type"] = Variant::FLOAT;
    p3["hint"] = "";
    p3["hint_string"] = "";
    p3["default_value"] = 0.0;
    p3["min"] = -10000000000;
    p3["max"] = 100000000000;
    //p4
    Dictionary p4;
    p4["name"] = "absolute";
    p4["type"] = Variant::BOOL;
    p4["hint"] = "";
    p4["hint_string"] = "";
    p4["default_value"] = false;
    p4["min"] = -0;
    p4["max"] = 0;
    props.append(p1);
    props.append(p2);
    props.append(p3);
    props.append(p4);
    return props;
}

void MToHeight::_set_property(String prop_name, Variant value){
    if (prop_name == "hardness"){
        hardness = value;
        return;
    } else if (prop_name == "offset")
    {
        offset = value;
        return;
    }
    else if (prop_name == "weight")
    {
        weight = value;
        return;
    } else if (prop_name == "absolute"){
        UtilityFunctions::print("Absoulute value ", value);
        absolute = value;
    }
}

bool MToHeight::is_two_point_brush(){
    return false;
}

void MToHeight::before_draw(){

}
float MToHeight::get_height(const uint32_t& x,const uint32_t& y){
    Vector3 world_pos = grid->get_pixel_world_pos(x,y);
    real_t dis = grid->brush_world_pos.distance_to(world_pos);
    dis = dis/grid->brush_radius;
    dis = UtilityFunctions::smoothstep(1,hardness,dis);
    float toh;
    if(absolute){
        toh=offset;
    } else {
        toh = grid->brush_world_pos.y + offset;
    }
    float h = grid->get_height_by_pixel(x,y);
    return (toh - h)*weight*dis + h;
}