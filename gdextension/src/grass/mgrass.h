#ifndef MGRASS
#define MGRASS


#include <godot_cpp/classes/node3d.hpp>

using namespace godot;



class MGrass : public Node3D {
    GDCLASS(MGrass,Node3D);

    protected:
    static void _bind_methods();

};
#endif