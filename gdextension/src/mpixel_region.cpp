#include "mpixel_region.h"

#include <godot_cpp/variant/utility_functions.hpp>


MPixelRegion::MPixelRegion(){}

MPixelRegion::MPixelRegion(const uint32_t& width,const uint32_t& height) {
    //Minus one becuase pixels id start from zero
    right = width - 1;
    bottom = height - 1;
}

MPixelRegion::MPixelRegion(const uint32_t& _left, const uint32_t& _right, const uint32_t& _top, const uint32_t& _bottom){
    left = _left;
    right = _right;
    top = _top;
    bottom = _top;
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
            xpoint=0;
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

/*
Vector<MBound> MBound::devide(int32_t amount){
    Vector<MBound> output;
    int32_t xamount = (right - left)/amount;
    int32_t yamount = (bottom - top)/amount;
    UtilityFunctions::print("Xamount ", xamount);
    UtilityFunctions::print("Yamount ", yamount);
    int32_t xpoint=left;
    int32_t ypoint=top;
    int index = 0;
    while(true){
        UtilityFunctions::print("point ",xpoint," _ ",ypoint);
        MBound bound(xpoint,ypoint);
        UtilityFunctions::print("create bound ", bound.left, " ", bound.right, " ", bound.top, " ", bound.bottom);
        if(bound.grow_positive(xamount,yamount,*this)){
            UtilityFunctions::print("Accept grow x");
            UtilityFunctions::print("boundxgrow ", bound.left, " ", bound.right, " ", bound.top, " ", bound.bottom);
            output.append(bound);
            xpoint = xpoint + xamount + 1;
        } else {
            xpoint = 0;
            ypoint = ypoint + yamount + 1;
            MBound bound2(xpoint,ypoint);
            if(bound2.grow_positive(xamount,yamount,*this)){
                output.append(bound2);
                xpoint = xpoint + xamount + 1;
            } else {
                break;
            }
        }
        index++;
        if(index > 100){
            break;
        }
    }
    return output;
}

*/