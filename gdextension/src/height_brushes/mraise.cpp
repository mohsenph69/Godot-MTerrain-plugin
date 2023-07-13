#include "mraise.h"
#include <godot_cpp/variant/utility_functions.hpp>




MRaise::MRaise(){

}
MRaise::~MRaise(){

}
String MRaise::_get_name(){
    return "raise";
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
    p1["min"] = 0.01;
    p1["max"] = 1.0;
    //p2
    Dictionary p2;
    p2["name"] = "amount";
    p2["type"] = Variant::FLOAT;
    p2["hint"] = "";
    p2["hint_string"] = "";
    p2["default_value"] = 0.5;
    p2["min"] = -100000000;
    p2["max"] = 100000000;
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
void MRaise::before_draw(){
    
}
float MRaise::get_height(const uint32_t& x,const uint32_t& y){
    float h = grid->get_height_by_pixel(x,y);
    return h + 10.0;
}