#ifndef MGRASS
#define MGRASS

#include <godot_cpp/classes/node3d.hpp>
#include "mgrass_data.h"


using namespace godot;

class MGrid;

class MGrass : public Node3D {
    GDCLASS(MGrass,Node3D);

    protected:
    static void _bind_methods();

    public:
    Ref<MGrassData> grass_data;
    MGrid* grid = nullptr;


    MGrass();
    ~MGrass();
    void init_grass(MGrid* grid);
    void clear_grass();
    void set_grass_data(Ref<MGrassData> d);
    Ref<MGrassData> get_grass_data();



};
#endif