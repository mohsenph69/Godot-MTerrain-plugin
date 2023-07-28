#include "mgrass.h"
#include "../mgrid.h"




void MGrass::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_grass_data","input"), &MGrass::set_grass_data);
    ClassDB::bind_method(D_METHOD("get_grass_data"), &MGrass::get_grass_data);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT,"grass_data",PROPERTY_HINT_RESOURCE_TYPE,"MGrassData"),"set_grass_data","get_grass_data");
}

MGrass::MGrass(){

}
MGrass::~MGrass(){

}

void MGrass::init_grass(MGrid* grid) {
    UtilityFunctions::print("Init grass ", get_name());
}

void MGrass::clear_grass(){

}

void MGrass::set_grass_data(Ref<MGrassData> d){
    grass_data = d;
}

Ref<MGrassData> MGrass::get_grass_data(){
    return grass_data;
}