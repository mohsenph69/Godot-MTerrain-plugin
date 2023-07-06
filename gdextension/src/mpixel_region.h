#ifndef MPIXELREGION
#define MPIXELREGION

#include <stdint.h>
#include <godot_cpp/templates/vector.hpp>

using namespace godot;


struct MPixelRegion {
    uint32_t left=0;
    uint32_t right=0;
    uint32_t top=0;
    uint32_t bottom=0;

    MPixelRegion();
    MPixelRegion(const uint32_t& _left, const uint32_t& _right, const uint32_t& _top, const uint32_t& _bottom);
    MPixelRegion(const uint32_t& width,const uint32_t& height);

    bool grow_positve(const uint32_t& xamount,const uint32_t& yamount,const MPixelRegion& limit);
    Vector<MPixelRegion> devide(uint32_t amount);
};

#endif