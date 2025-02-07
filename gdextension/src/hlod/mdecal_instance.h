#ifndef ___MDECALINSTANCE__
#define ___MDECALINSTANCE__

#include "mdecal.h"
#include <godot_cpp/classes/visual_instance3d.hpp>

class MDecalInstance : public VisualInstance3D {
    GDCLASS(MDecalInstance,VisualInstance3D);
    protected:
    static void _bind_methods();
    private:
    Ref<MDecal> mdecal;


    public:
    bool has_decal() const;
    void set_decal(Ref<MDecal> input);
    Ref<MDecal> get_decal() const;

    AABB _get_aabb() const;

    void _notification(int32_t what);
};

#endif