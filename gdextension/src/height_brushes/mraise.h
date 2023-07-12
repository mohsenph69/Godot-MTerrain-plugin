#ifndef RAISEBRUSH
#define RAISEBRUSH

#include "../mheight_brush.h"

class MRaise : public MHeightBrush {
    public:
    MRaise();
    ~MRaise();
    String _get_name();
    Array _get_property_list();
    void _set_property(String prop_name, Variant value);
    void before_draw(const MGrid*& grid);
    float get_height(const uint32_t& x,const uint32_t& y);
};
#endif