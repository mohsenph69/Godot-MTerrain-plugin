#ifndef __MHLODITEM__
#define __MHLODITEM__

#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/classes/material.hpp>
#include <godot_cpp/classes/geometry_instance3d.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/classes/shape3d.hpp>
#include <godot_cpp/templates/hash_map.hpp>

#include "mmesh.h"

#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

class MHlod;

struct MHLodItemMesh {
    uint8_t shadow_setting;
    uint8_t gi_mode;
    int8_t material_id;
    int32_t render_layers;
    int32_t mesh_id;
    Ref<MMesh> mesh;
    //Vector<Material> surface_material;

    MHLodItemMesh();
    ~MHLodItemMesh();
    _FORCE_INLINE_ bool has_material_ovveride();
    void load();
    void unload();
    RID get_mesh() const;
    void get_material(Vector<RID>& material_rids);
    GeometryInstance3D::ShadowCastingSetting get_shadow_setting();
    GeometryInstance3D::GIMode get_gi_mode();
    void set_data(int64_t _mesh,int8_t _material,uint8_t _shadow_setting,uint8_t _gi_mode,int32_t _render_layers);
    void set_data(const PackedByteArray& d);
    PackedByteArray get_data() const;
};

struct MHLodItemMeshTest {
    friend MHlod;
    private:
    uint8_t shadow_setting;
    uint8_t gi_mode;
    int32_t material_id;
    int32_t render_layers;
    int64_t mesh_id;
    Ref<Mesh> mesh;
};

////// Physics





struct MHLodItemCollision {
    friend MHlod;
    struct Param
    {
        enum Type : uint8_t {NONE,SHPERE,CYLINDER,CAPSULE,BOX};
        Type type = NONE;
        float param_1;
        float param_2;
        float param_3;

        static _FORCE_INLINE_ uint32_t hash(const Param &__p) {
            uint32_t hash = 2166136261u;
            hash ^= (uint32_t)__p.type;
            hash *= 0x5bd1e995;
            float param_1 = __p.param_1;
            float param_2 = __p.param_2;
            float param_3 = __p.param_3;
            hash ^= *reinterpret_cast<uint32_t*>(&param_1);
            hash = hash << 2;
            hash ^= *reinterpret_cast<uint32_t*>(&param_2);
            hash = hash >> 1;
            hash ^= *reinterpret_cast<uint32_t*>(&param_3);
            return hash;
        }

        static bool compare(const Param &l, const Param &r) {
            return l.param_1==r.param_1 && l.param_2==r.param_2 && l.param_3==r.param_3 && l.type==r.type;
        }
    };
    struct ShapeData
    {
        RID rid;
        int64_t user_count;
    };
    Param param;
    int32_t static_body = -1;
    MHLodItemCollision();
    ~MHLodItemCollision();
    RID get_shape();
    void set_data(const Dictionary& d);
    Dictionary get_data() const;
    private:
    static HashMap<Param,ShapeData,Param,Param> shapes;
};
#endif