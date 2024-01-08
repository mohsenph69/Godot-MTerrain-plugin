#ifndef MOBSTACLE
#define MOBSTACLE

#include <godot_cpp/classes/node3d.hpp>


using namespace godot;


class MObstacle : public Node3D{
    GDCLASS(MObstacle,Node3D);

    protected:
    static void _bind_methods();

    public:
    float width=1.0;
    float depth=1.0;
    MObstacle();
    ~MObstacle();
    
    float get_width();
    void set_width(float input);
    float get_depth();
    void set_depth(float input);
};
#endif