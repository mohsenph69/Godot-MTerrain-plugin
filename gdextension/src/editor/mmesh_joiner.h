#ifndef __MESHJOINDER__
#define __MESHJOINDER__

#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/classes/material.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/array_mesh.hpp>
#include <godot_cpp/classes/triangle_mesh.hpp>

#include "../hlod/mmesh.h"

using namespace godot;

class MMeshJoiner : public RefCounted {
    GDCLASS(MMeshJoiner,RefCounted);

    protected:
    static void _bind_methods();

    private:
    enum Flags {
        UV = 1 << 0,
        UV2 = 1 << 1,
        COLOR = 1 << 2,
        TANGENT = 1 << 3
    };
    struct MeshData {
        Ref<Material> material;
        PackedVector3Array vertices;
        PackedVector3Array normals;
        PackedFloat32Array tangents;
        PackedColorArray colors;
        PackedVector2Array uv;
        PackedVector2Array uv2;
        PackedInt32Array indices;
        Transform3D transform;
        Basis normal_transform;
        void append_uv_to(PackedVector2Array& _input) const;
        void append_uv2_to(PackedVector2Array& _input) const;
        void append_colors_to(PackedColorArray& _input) const;
        void append_vertices_to(PackedVector3Array& _input) const;
        void append_normals_to(PackedVector3Array& _input) const;
        void append_tangents_to(PackedFloat32Array& _input) const;
        void append_indices_to(PackedInt32Array& _input,int vertex_index_offset) const;
    };

    Vector<MeshData> data;
    Vector<Vector<int>> material_sorted_data;
    Vector<uint64_t> material_sorted_flags;
    private:
    void _sort_data_by_materials();
    void _join_meshes(const Vector<int>& data_ids,Array& mesh_arr,uint64_t flags);
    public:
    void clear();
    bool insert_mesh_data(Array meshes,Array transforms,Array materials_override);
    bool insert_mmesh_data(Array meshes,Array transforms,PackedInt32Array materials_set_ids);
    Ref<ArrayMesh> join_meshes();
    static Ref<Mesh> get_collission_mesh(Array meshes,Array transforms);
    int get_data_count() const;
};
#endif