#ifndef MGRASSLODSETTING
#define MGRASSLODSETTING


#include <godot_cpp/classes/resource.hpp>


using namespace godot;


class MGrassLodSetting : public Resource {
    GDCLASS(MGrassLodSetting,Resource);


    protected:
    static void _bind_methods();
};
#endif