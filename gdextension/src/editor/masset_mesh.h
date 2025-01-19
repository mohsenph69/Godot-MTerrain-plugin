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
    PackedInt32Array mesh_ids;
    Transform3D transform;
    Transform3D global_transform;

    PackedInt32Array get_material_set_ids();
    Transform3D get_transform();
    Transform3D get_global_transform();
    TypedArray<MMesh> get_mesh_lod();
    PackedInt32Array get_mesh_ids();
    int8_t get_last_valid_lod() const;
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
        int8_t material_set_id = 0; // main one
        int8_t active_mesh_index = -1;
        int32_t collection_id = -1;
        RID mesh_rid;
        RID instance_rid;
        TypedArray<MMesh> meshes;
        Ref<MMesh> current_mmesh;
        Vector<Ref<Material>> materials; // no user add and remove
        PackedInt32Array mesh_ids;
        Transform3D local_transform; // local transform compare to the main node
        void update_material(int set_id,int8_t _active_mesh_index);
        Ref<MMesh> get_last_valid_mesh() const;
        Ref<MMesh> get_first_valid_mesh() const;
        int8_t get_mesh_index_last(int lod) const;
        RID get_mesh_rid_last(int lod) const;
        Ref<MMesh> get_mesh_last(int lod) const;
    };

    uint16_t hlod_layers = 0;
    int collection_id = -1;
    int current_lod = -1;
    int lod_cutoff = -1;
    Vector<InstanceData> instance_data;
    Ref<TriangleMesh> joined_triangle_mesh; // chached for editor selection
    AABB joined_aabb; // if above is cached the this is also is calculated
    Dictionary collections_material_set; // key collection id , value material set, should be updated with InstanceData 

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
    int64_t get_hlod_layers() const;

    void set_lod_cutoff(int input);
    int get_lod_cutoff();
    
    void set_collection_id_no_lod_update(int input);
    void set_collection_id(int input);
    int get_collection_id();
    PackedInt32Array get_collection_ids() const;
    int get_collection_material_set(int collection_id) const;
    void set_collection_material_set(int collection_id, int material_set);
    void update_material_sets_from_data();
    void set_collections_material_set(Dictionary data);
    Dictionary get_collections_material_set() const;

    void _update_position();
    void _update_visibility();
    void _notification(int32_t what);
    void _get_property_list(List<PropertyInfo> *p_list) const;
    bool _get(const StringName &p_name, Variant &r_ret) const;
    bool _set(const StringName &p_name, const Variant &p_value);

    TypedArray<MAssetMeshData> get_mesh_data();

    AABB get_joined_aabb();
    Ref<TriangleMesh> get_joined_triangle_mesh();
    void generate_joined_triangle_mesh();

    Ref<ArrayMesh> get_merged_mesh(bool lowest_lod);
    static Ref<ArrayMesh> get_collection_merged_mesh(int collection_id,bool lowest_lod);
};
#endif