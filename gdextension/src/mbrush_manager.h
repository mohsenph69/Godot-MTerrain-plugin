#ifndef MBRUSHMANAGER
#define MBRUSHMANAGER

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/templates/vector.hpp>
#include <godot_cpp/templates/hash_map.hpp>

#include "mheight_brush.h"

using namespace godot;


class MBrushManager : public Object {
    GDCLASS(MBrushManager,Object);
    private:
    Vector<MHeightBrush*> height_brushes;
    HashMap<String,int> height_brush_map;
    void add_height_brush(MHeightBrush* brush);

    protected:
    static void _bind_methods();

    public:
    MBrushManager* get_singelton();
    MBrushManager();
    ~MBrushManager();
    MHeightBrush* get_height_brush(int brush_id);
    PackedStringArray get_height_brush_list();
    int get_height_brush_id(String brush_name);
    
};
#endif