#include "mraise.h"
#include <godot_cpp/variant/utility_functions.hpp>




MRaise::MRaise(){

}
MRaise::~MRaise(){

}
String MRaise::_get_name(){
    return "raise";
}
Array MRaise::_get_property_list(){
    return Array();
}
void MRaise::_set_property(String prop_name, Variant value){

}
void MRaise::before_draw(const MGrid*& grid){
    
}
float MRaise::get_height(const uint32_t& x,const uint32_t& y){
    float h = grid->get_height_by_pixel(x,y);
    return h + 10.0;
}