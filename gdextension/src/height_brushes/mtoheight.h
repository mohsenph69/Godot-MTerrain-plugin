#ifndef MTOHEIGHT
#define MTOHEIGHT

#include "../mheight_brush.h"

using namespace godot;

class MToHeight : public MHeightBrush {
    public:
    float weight=0.1;
    float hardness=0.5;
    float offset=0.0;
    bool absolute=false;
    MToHeight();
    ~MToHeight();
    String _get_name();
    Array _get_property_list();
    void _set_property(String prop_name, Variant value);
    void before_draw();
    float get_height(const uint32_t& x,const uint32_t& y);
};
#endif