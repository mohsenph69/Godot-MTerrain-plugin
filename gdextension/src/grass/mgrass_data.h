#ifndef MGRASS_DATA
#define MGRASS_DATA

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

using namespace godot;


class MGrassData : public Resource {
    GDCLASS(MGrassData,Resource);

    protected:
    static void _bind_methods();

    public:
    PackedByteArray data;

    void set_data(const PackedByteArray& d);
    PackedByteArray get_data();

    void add(int d);
    void print_all_data();

};
#endif