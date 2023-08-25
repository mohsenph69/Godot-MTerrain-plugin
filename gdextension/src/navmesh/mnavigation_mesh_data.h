#ifndef MNAVIGATIONDATA
#define MNAVIGATIONDATA

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

using namespace godot;

class MNavigationMeshData : public Resource {
    GDCLASS(MNavigationMeshData, Resource);

    protected:
    static void _bind_methods();

    public:
    PackedByteArray data;

    void set_data(const PackedByteArray& d);
    PackedByteArray get_data();
};


#endif