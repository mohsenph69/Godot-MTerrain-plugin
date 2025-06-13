#ifndef _MPATH
#define _MPATH

#include <godot_cpp/classes/node3d.hpp>


#include "mcurve.h"

#include <godot_cpp/classes/material.hpp>


using namespace godot;

class MPath : public Node3D{
    GDCLASS(MPath,Node3D);

    protected:
    static void _bind_methods();

    private:
    #ifdef DEBUG_ENABLED // only for editor
    bool is_current_editing_dirty=false;
    HashSet<int32_t> dirty_points;
    int32_t current_editing_point = 0;
    double wait_commit_time=0;
    #endif
    int32_t selected_handle = -1;
    RID scenario;
    RID space;
    void _get_handle(PackedVector3Array& positions, PackedInt32Array& ids, const MCurve::Point* p,uint32_t p_id,bool secondary) const;
    bool mirror_control = true;
    static Vector<MPath*> all_path_nodes;

    public:
    static TypedArray<MPath> get_all_path_nodes();
    MPath();
    ~MPath();
    Ref<MCurve> curve;

    /// Setting that to zero will clear it
    void set_current_editing_point(int32_t point_id);
    int32_t get_current_editing_point() const;

    void set_curve(Ref<MCurve> input);
    Ref<MCurve> get_curve();

    void _notification(int p_what);
    void update_scenario_space();
    RID get_scenario();
    RID get_space();

    #ifdef DEBUG_ENABLED
    void _get_property_list(List<PropertyInfo> *p_list) const;
    bool _get(const StringName &p_name, Variant &r_ret) const;
    bool _set(const StringName &p_name, const Variant &p_value);
    #endif
};
#endif