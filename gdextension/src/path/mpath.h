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

    void set_curve(Ref<MCurve> input);
    Ref<MCurve> get_curve();

    void _notification(int p_what);
    void update_scenario_space();
    RID get_scenario();
    RID get_space();
};
#endif