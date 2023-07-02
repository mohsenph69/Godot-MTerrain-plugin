#ifndef MCHUNK_GENERATOR
#define MCHUNK_GENERATOR


#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/classes/array_mesh.hpp>
#include <godot_cpp/classes/ref.hpp>

using namespace godot;

class MChunkGenerator : public Object{
    GDCLASS(MChunkGenerator, Object);

    protected:
    static void _bind_methods();

    public:
    static Ref<ArrayMesh> generate(real_t size, real_t h_scale, bool el, bool er, bool et, bool eb);

};




#endif