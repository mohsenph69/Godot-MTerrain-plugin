#include "mpixel_region.h"

#include <godot_cpp/variant/utility_functions.hpp>


MPixelRegion::MPixelRegion(){}

MPixelRegion::MPixelRegion(const uint32_t& _width,const uint32_t& _height) {
    //Minus one becuase pixels id start from zero
    width = _width;
    height = _height;
    right = _width - 1;
    bottom = _height - 1;
}

MPixelRegion::MPixelRegion(const uint32_t& _left, const uint32_t& _right, const uint32_t& _top, const uint32_t& _bottom){
    left = _left;
    right = _right;
    top = _top;
    bottom = _bottom;
    width = right - left + 1;
    height = bottom - top + 1;
}

void MPixelRegion::grow_all_side(const MPixelRegion& limit){
    if(left>0) left -=1;
    if(top>0) top -=1;
    right += 1;
    bottom +=1;
    if(left<limit.left) left = limit.left;
    if(top<limit.top) top = limit.top;
    if(right>limit.right) right = limit.right;
    if(bottom>limit.bottom) bottom = limit.bottom;
}


bool MPixelRegion::grow_positve(const uint32_t& xamount,const uint32_t& yamount,const MPixelRegion& limit){
    if(left>limit.right || top>limit.bottom){
        return false;
    }
    right += xamount;
    bottom += yamount;
    if(right>limit.right) right = limit.right;
    if(bottom>limit.bottom) bottom = limit.bottom;
    return true;
}

Vector<MPixelRegion> MPixelRegion::devide(uint32_t amount) {
    Vector<MPixelRegion> output;
    uint32_t xamount = (right - left)/amount;
    uint32_t yamount = (bottom - top)/amount;
    UtilityFunctions::print("xamount ", xamount);
    UtilityFunctions::print("yamount ", yamount);
    uint32_t xpoint=left;
    uint32_t ypoint=top;
    uint32_t index = 0;
    while (true)
    {
        MPixelRegion r(xpoint,xpoint,ypoint,ypoint);
        if(r.grow_positve(xamount,yamount, *this)){
            output.append(r);
            xpoint = xpoint + xamount + 1;
        } else {
            xpoint=left;
            ypoint = ypoint + yamount + 1;
            MPixelRegion r2(xpoint,xpoint,ypoint,ypoint);
            if(r2.grow_positve(xamount,yamount, *this)){
                output.append(r2);
                xpoint = xpoint + xamount + 1;
            } else {
                break;
            }
        }
        index++;
        if(index>100){
            break;
        }
    }
    return output;
}

MPixelRegion MPixelRegion::get_local(MPixelRegion region){
    region.left -= left;
    region.right -= left;
    region.top -= top;
    region.bottom -= top;
    return region;
}