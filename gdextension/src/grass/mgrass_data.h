#ifndef MGRASS_DATA
#define MGRASS_DATA

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

#include "../mconfig.h"

using namespace godot;


class MGrassData : public Resource {
    GDCLASS(MGrassData,Resource);

    protected:
    static void _bind_methods();

    public:
    PackedByteArray data;
    int density_index=2;
    float density=1;

    void set_data(const PackedByteArray& d);
    PackedByteArray get_data();
    void set_density(int input);
    int get_density();

    void add(int d);
    void print_all_data();

};
#endif