#ifndef __MHLODNODE3D__
#define __MHLODNODE3D__

#include <godot_cpp/classes/node3d.hpp>
#include "mhlod_scene.h"

using namespace godot;

class MHlodNode3D : public Node3D {
    GDCLASS(MHlodNode3D,Node3D);

    protected:
    static void _bind_methods();
};
#endif