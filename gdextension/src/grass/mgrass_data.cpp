#include "mgrass_data.h"

#include <godot_cpp/variant/utility_functions.hpp>


void MGrassData::_bind_methods(){
    ClassDB::bind_method(D_METHOD("add","d"), &MGrassData::add);
    ClassDB::bind_method(D_METHOD("print_all_data"), &MGrassData::print_all_data);

    ClassDB::bind_method(D_METHOD("set_data","input"), &MGrassData::set_data);
    ClassDB::bind_method(D_METHOD("get_data"), &MGrassData::get_data);
    ADD_PROPERTY(PropertyInfo(Variant::PACKED_BYTE_ARRAY,"data",PROPERTY_HINT_NONE,"",PROPERTY_USAGE_STORAGE|PROPERTY_USAGE_READ_ONLY),"set_data","get_data");
    ClassDB::bind_method(D_METHOD("set_density","input"), &MGrassData::set_density);
    ClassDB::bind_method(D_METHOD("get_density"), &MGrassData::get_density);
    ADD_PROPERTY(PropertyInfo(Variant::INT,"density",PROPERTY_HINT_ENUM,M_H_SCALE_LIST_STRING),"set_density","get_density");
}

void MGrassData::set_data(const PackedByteArray& d){
    data = d;
}

PackedByteArray MGrassData::get_data(){
    return data;
}

void MGrassData::set_density(int input){
    float l[] = M_H_SCALE_LIST;
    density = l[input];
    density_index = input;
    UtilityFunctions::print("density ", density);
}

int MGrassData::get_density(){
    return density_index;
}

void MGrassData::add(int d) {
    data.push_back((uint8_t)d);
}

void MGrassData::print_all_data() {
    for(int i=0; i< data.size();i++){
        UtilityFunctions::print("i ",itos(i), " --> ", itos(data[i]));
    }
}

