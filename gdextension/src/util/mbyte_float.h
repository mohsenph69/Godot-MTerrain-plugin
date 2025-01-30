#ifndef __MBYTEFLOAT__
#define __MBYTEFLOAT__

#include <godot_cpp/core/error_macros.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <typeinfo>
#include <type_traits>
#include <cstdint>


template<bool isSinged,int max>
class MByteFloat {
    using Type = typename std::conditional<isSinged,int8_t,uint8_t>::type;
    Type value = 0;

    public:
    constexpr int get_max(){
        return max;
    }

    _FORCE_INLINE_ float get_float() const{
        if constexpr (isSinged){
            return (((float)value)/127.0f) * max;
        } else {
            return (((float)value)/255.0f) * max;
        }
    }

    _FORCE_INLINE_ void set_float(const float input){
        if(unlikely(input > max)){
            if constexpr (isSinged) value = 127;
            else value = 255;
            return;
        }
        if constexpr (isSinged){
            if(unlikely(input < -max)){
                value = -127;
                return;
            }
            value = (Type)std::round((input/((float)max)) * 127.0f );
        } else {
            if(unlikely(input < 0)){
                value = 0;
                return;
            }
            value = (Type)std::round((input/((float)max)) * 255.0f);
        }
    }

    _FORCE_INLINE_ int8_t get_int_value() const{
        return value;
    }

    _FORCE_INLINE_ void set_int_value(int8_t input){
        value = (Type)input;
    }

    MByteFloat()=default;
    MByteFloat(const float input){
        set_float(input);
    }
    MByteFloat(const Variant input){
        set_float((float)input);
    }
    _FORCE_INLINE_ operator float() const {
        return get_float();
    }

    _FORCE_INLINE_ operator Variant() const {
        return Variant(get_float());
    }

    _FORCE_INLINE_ MByteFloat& operator=(float input) {
        set_float(input);
        return *this;
    }

    _FORCE_INLINE_ MByteFloat& operator=(Variant input) {
        set_float((float)input);
        return *this;
    }

    _FORCE_INLINE_ bool operator==(const MByteFloat& other) const {
        return value == other.value;
    }

    _FORCE_INLINE_ bool operator>(const MByteFloat& other) const {
        return value > other.value;
    }

    _FORCE_INLINE_ bool operator>=(const MByteFloat& other) const {
        return value >= other.value;
    }

    _FORCE_INLINE_ bool operator<(const MByteFloat& other) const {
        return value < other.value;
    }

    _FORCE_INLINE_ bool operator<=(const MByteFloat& other) const {
        return value < other.value;
    }
};
#endif