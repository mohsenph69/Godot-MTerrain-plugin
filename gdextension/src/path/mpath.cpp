#include "mpath.h"
#include <godot_cpp/classes/rendering_server.hpp>
#define RS RenderingServer::get_singleton()
#include <godot_cpp/classes/world3d.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>

#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/resource_saver.hpp>
#include <godot_cpp/classes/world3d.hpp>

Vector<MPath*> MPath::all_path_nodes;

void MPath::_bind_methods(){
    ADD_SIGNAL(MethodInfo("curve_changed"));

    ClassDB::bind_method(D_METHOD("set_current_editing_point","input"), &MPath::set_current_editing_point);
    ClassDB::bind_method(D_METHOD("get_current_editing_point"), &MPath::get_current_editing_point);

    ClassDB::bind_method(D_METHOD("set_curve","input"), &MPath::set_curve);
    ClassDB::bind_method(D_METHOD("get_curve"), &MPath::get_curve);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "curve", PROPERTY_HINT_RESOURCE_TYPE, "MCurve"),"set_curve","get_curve");

    ClassDB::bind_static_method("MPath",D_METHOD("get_all_path_nodes"), &MPath::get_all_path_nodes);
}

TypedArray<MPath> MPath::get_all_path_nodes(){
    TypedArray<MPath> out;
    for(MPath* p: all_path_nodes){
        if(p->is_inside_tree()){
            out.push_back(p);
        }
    }
    return out;
}

MPath::MPath(){
    set_process(true);
    set_notify_transform(true);
    all_path_nodes.push_back(this);
}
MPath::~MPath(){
    for(int i=0; i < all_path_nodes.size(); i++){
        if(this == all_path_nodes[i]){
            all_path_nodes.remove_at(i);
            break;
        }
    }
}

void MPath::set_current_editing_point(int32_t point_id){
    #ifdef DEBUG_ENABLED
    current_editing_point = point_id;
    notify_property_list_changed();
    #endif
}

int32_t MPath::get_current_editing_point() const{
    #ifdef DEBUG_ENABLED
    return current_editing_point;
    #else
    return 0;
    #endif
}

void MPath::set_curve(Ref<MCurve> input){
    if(curve.is_valid()){
        curve->disconnect("curve_updated",Callable(this,"update_gizmos"));
    }
    curve = input;
    if(curve.is_valid()){
        if(is_inside_tree()){
            input->init_insert();
        }
        curve->connect("curve_updated",Callable(this,"update_gizmos"));
    }
    emit_signal("curve_changed");
    update_gizmos();
    #ifdef DEBUG_ENABLED
    notify_property_list_changed();
    #endif
}

Ref<MCurve> MPath::get_curve(){
    return curve;
}

void MPath::_notification(int p_what){
    switch (p_what)
    { 
    case NOTIFICATION_PROCESS:
        #ifdef DEBUG_ENABLED
        if(is_current_editing_dirty){
            wait_commit_time+= get_process_delta_time();
            if(wait_commit_time>=1.0){
                wait_commit_time=0.0;
                is_current_editing_dirty=false;
                if(curve.is_valid()){
                    for(auto it=dirty_points.begin();it!=dirty_points.end();++it){
                        curve->commit_point_update(*(it));
                    }
                    dirty_points.clear();
                }
            }
        }
        #endif
        if(curve.is_valid()){
            curve->init_insert();
            //set_process(false);
        }
        break;
    case NOTIFICATION_READY:
        update_scenario_space();
        break;
    case NOTIFICATION_TRANSFORM_CHANGED:
        set_global_transform(Transform3D());
        break;
    case NOTIFICATION_EDITOR_PRE_SAVE:
        if(curve.is_valid()){
            String file_name = curve->get_path().get_file();
            if(file_name.is_valid_filename()){
                String ext = file_name.get_extension();
                if(ext!="res"){
                    WARN_PRINT_ONCE("Please save curve resource in \""+get_name()+"\" as .res extension");
                }
                // Maybe later put this in a condition
                ResourceSaver::get_singleton()->save(curve,curve->get_path());
            } else {
                WARN_PRINT_ONCE("Please save curve resource in \""+get_name()+"\" as .res extension");
            }
        }
        break;
    case NOTIFICATION_ENTER_WORLD:
        //set_visible(true);
        break;
    case NOTIFICATION_EXIT_WORLD:
        //set_visible(false);
        break;
    }
}

void MPath::update_scenario_space(){
    if(is_inside_tree()){
        scenario = get_world_3d()->get_scenario();
        space = get_world_3d()->get_space();
    }
}

RID MPath::get_scenario(){
    if(!scenario.is_valid()){
        update_scenario_space();
    }
    return scenario;
}

RID MPath::get_space(){
    if(!space.is_valid()){
        update_scenario_space();
    }
    return space;
}


#ifdef DEBUG_ENABLED
void MPath::_get_property_list(List<PropertyInfo> *p_list) const{
    if(curve.is_null() || !curve->has_point(current_editing_point)){
        return;
    }
    p_list->push_back(
    PropertyInfo(Variant::VECTOR3,"point_position",PROPERTY_HINT_NONE,"",PROPERTY_USAGE_EDITOR)
    );
    p_list->push_back(
    PropertyInfo(Variant::VECTOR3,"point_in",PROPERTY_HINT_NONE,"",PROPERTY_USAGE_EDITOR)
    );
    p_list->push_back(
    PropertyInfo(Variant::VECTOR3,"point_out",PROPERTY_HINT_NONE,"",PROPERTY_USAGE_EDITOR)
    );
}

bool MPath::_get(const StringName &p_name, Variant &r_ret) const{
    if(curve.is_null() || !curve->has_point(current_editing_point)){
        return false;
    }
    if(p_name==String("point_position")){
        r_ret = curve->get_point_position(current_editing_point);
        return true;
    }
    if(p_name==String("point_in")){
        r_ret = curve->get_point_in(current_editing_point);
        return true;
    }
    if(p_name==String("point_out")){
        r_ret = curve->get_point_out(current_editing_point);
        return true;
    }
    return false;
}

bool MPath::_set(const StringName &p_name, const Variant &p_value){
    if(curve.is_null() || !curve->has_point(current_editing_point)){
        return false;
    }
    bool is_val_set = false;
    if(p_name==String("point_position")){
        curve->move_point(current_editing_point,p_value);
        is_current_editing_dirty = true;
        is_val_set=true;
    }
    if(p_name==String("point_in")){
        curve->move_point_in(current_editing_point,p_value);
        is_current_editing_dirty = true;
        is_val_set=true;
    }
    if(p_name==String("point_out")){
        curve->move_point_out(current_editing_point,p_value);
        is_current_editing_dirty = true;
        is_val_set=true;
    }
    if(is_val_set){
        dirty_points.insert(current_editing_point);
        return true;
    }
    return false;
}
#endif