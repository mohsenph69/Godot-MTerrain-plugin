#ifndef MCOLORBRUSH
#define MCOLORBRUSH


#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/classes/object.hpp>
#include "mconfig.h"

#include "mgrid.h"

using namespace godot;




class MColorBrush {
    protected:
    MGrid* grid;
    public:
    void set_grid(MGrid* _grid){grid = _grid;};
    virtual ~MColorBrush(){};
    virtual String _get_name()=0;
    virtual void _set_property(String prop_name, Variant value)=0;
    virtual bool is_two_point_brush()=0;
    virtual void before_draw()=0;
    virtual void set_color(uint32_t local_x,uint32_t local_y,uint32_t x,uint32_t y,MImage* img)=0;
};
#endif