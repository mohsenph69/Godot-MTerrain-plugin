#ifndef MHEIGHTBRUSH
#define MHEIGHTBRUSH

#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/classes/object.hpp>

#include "mgrid.h"




using namespace godot;


/*
Property Format
array = [
    {"name":"name of props", type:Variant_type, default:default_value, min:min_value, max:max_value}
    .
    .
    .
]
*/

class MHeightBrush {
    protected:
    MGrid* grid;
    public:
    void set_grid(MGrid* _grid){grid = _grid;};
    virtual ~MHeightBrush(){};
    virtual String _get_name()=0;
    virtual Array _get_property_list()=0;
    virtual void _set_property(String prop_name, Variant value)=0;
    // Will be called before start to draw
    // a initilized type before each draw
    virtual void before_draw(const MGrid*& grid)=0;
    // x,y -> position of current pixel to be modified
    // grid -> grid class in mterrain to access information about all pixel, normals, height or anything that you need for your brush
    virtual float get_height(const uint32_t& x,const uint32_t& y)=0;
};
#endif