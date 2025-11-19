#ifndef MGRASS_DATA
#define MGRASS_DATA

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/templates/hash_map.hpp>

#include "../mconfig.h"

using namespace godot;
class MGrass;
struct MGrassUndoData {
    uint8_t* data=nullptr;
    uint8_t* backup_data=nullptr;
    void free(){
        memdelete_arr(data);
        if(backup_data!=nullptr){
            memdelete_arr(backup_data);
        }
    }
};

class MGrassData : public Resource {
    friend MGrass;
    GDCLASS(MGrassData,Resource);

    protected:
    static void _bind_methods();

    uint32_t grass_region_pixel_width;
    uint32_t region_grid_width;
    uint32_t grass_region_pixel_size;
    int density_index=2;
    float density=1;
    int current_undo_id=0;
    int lowest_undo_id=0;
    PackedByteArray data;
    PackedByteArray backup_data;
    HashMap<int,MGrassUndoData> undo_data;

    public:
    MGrassData();
    ~MGrassData();



    void set_data(const PackedByteArray& d);
    const PackedByteArray& get_data();
    void set_backup_data(const PackedByteArray& d);
    const PackedByteArray& get_backup_data();
    void set_density(int input);
    int get_density();

    bool backup_exist();
    void backup_create();
    void backup_merge();
    void backup_restore();

    void check_undo(); // register a stage for undo
    void clear_undo();
    void undo();
    /// @brief  no error check make sure x and y is valid
    /// @param x grass x pixel pos in world pos
    /// @param y grass y pixel pos in world pos
    /// @return true if grass exist and false if grass does not exist
    _FORCE_INLINE_ bool get_pixel(uint32_t px,uint32_t py) const;
};


bool MGrassData::get_pixel(uint32_t px,uint32_t py) const{
    uint32_t rx = px/grass_region_pixel_width;
    uint32_t ry = py/grass_region_pixel_width;
    uint32_t rid = ry*region_grid_width + rx;
    uint32_t x = px%grass_region_pixel_width;
    uint32_t y = py%grass_region_pixel_width;
    uint32_t offs = rid*grass_region_pixel_size + y*grass_region_pixel_width + x;
    uint32_t ibyte = offs/8;
    uint32_t ibit = offs%8;
    return (data[ibyte] & (1 << ibit)) != 0;
}

#endif