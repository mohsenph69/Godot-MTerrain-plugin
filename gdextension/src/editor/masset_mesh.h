#ifndef __MASSETMESH__
#define __MASSETMESH__

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/triangle_mesh.hpp>

#include "../hlod/mmesh.h"

using namespace godot;

class MAssetMeshData : public RefCounted {
    GDCLASS(MAssetMeshData,RefCounted);
    protected:
    static void _bind_methods();

    public:
    int8_t material_set_id = -1;
    TypedArray<MMesh> mesh_lod;
    PackedInt64Array mesh_ids;
    Transform3D transform;
    Transform3D global_transform;

    int get_material_set_id();
    Transform3D get_transform();
    Transform3D get_global_transform();
    TypedArray<MMesh> get_mesh_lod();
    PackedInt64Array get_mesh_ids();
    Ref<MMesh> get_last_valid_mesh() const;
};

class MAssetMesh : public Node3D {
    GDCLASS(MAssetMesh,Node3D);

    protected:
    static void _bind_methods();

    private:
    int instance_count = 0;
    struct InstanceData
    {
        bool material_set_user_added = false;
        int8_t material_set_id = -1;
        RID mesh_rid;
        RID instance_rid;
        TypedArray<MMesh> meshes;
        Ref<MMesh> current_mmesh;
        PackedInt64Array mesh_ids;
        Transform3D local_transform; // local transform compare to the main node
        Ref<MMesh> get_last_valid_mesh() const;
        RID get_mesh_rid_last(int lod) const;
        Ref<MMesh> get_mesh_last(int lod) const;
    };

    uint16_t hlod_layers = 0;
    int collection_id = -1;
    int current_lod = -1;
    Vector<InstanceData> instance_data;
    Ref<TriangleMesh> joined_triangle_mesh; // chached for editor selection
    AABB joined_aabb; // if above is cached the this is also is calculated

    private:
    void remove_instances(bool hard_remove);
    public:
    MAssetMesh();
    ~MAssetMesh();
    void generate_instance_data(int collection_id,const Transform3D& transform); // at root level transform will be unity, this will append meshes to instance_data
    void update_instance_date();
    void update_lod(int lod);
    void destroy_meshes();
    void compute_joined_aabb();

    void set_hlod_layers(int64_t input);
    int64_t get_hlod_layers();
    
    void set_collection_id(int input);
    int get_collection_id();  

    void _update_position();
    void _update_visibility();
    void _notification(int32_t what);

    TypedArray<MAssetMeshData> get_mesh_data();

    AABB get_joined_aabb();
    Ref<TriangleMesh> get_joined_triangle_mesh();
    void generate_joined_triangle_mesh();
};
#endif