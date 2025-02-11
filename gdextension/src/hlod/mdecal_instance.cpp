#include "mdecal_instance.h"


void MDecalInstance::_bind_methods(){
    ClassDB::bind_method(D_METHOD("has_decal"), &MDecalInstance::has_decal);

    ClassDB::bind_method(D_METHOD("set_decal"), &MDecalInstance::set_decal);
    ClassDB::bind_method(D_METHOD("get_decal"), &MDecalInstance::get_decal);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT,"decal",PROPERTY_HINT_RESOURCE_TYPE,"MDecal"), "set_decal","get_decal");
}

bool MDecalInstance::has_decal() const{
    return mdecal.is_valid();
}

void MDecalInstance::set_decal(Ref<MDecal> input){
    mdecal = input;
    if(is_inside_tree()){
        if(mdecal.is_valid()){
            RS->instance_set_base(get_instance(),mdecal->get_decal_rid());
        } else {
            RS->instance_set_base(get_instance(),RID());
        }
    }
}

Ref<MDecal> MDecalInstance::get_decal() const{
    return mdecal;
}

AABB MDecalInstance::_get_aabb() const{
    if(mdecal.is_valid()){
        return mdecal->get_aabb();
    }
    return AABB();
}

void MDecalInstance::_notification(int32_t what){
	switch (what)
	{
	case NOTIFICATION_READY:
		if(mdecal.is_valid()){
			RS->instance_set_base(get_instance(),mdecal->get_decal_rid());
		}
		break;
	default:
		break;
	}
}