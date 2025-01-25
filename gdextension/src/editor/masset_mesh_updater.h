#ifndef __MASSETMESHUPDATER__
#define __MASSETMESHUPDATER__

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/mesh_instance3d.hpp>
#include <godot_cpp/templates/vset.hpp>
#include "../hlod/mmesh.h"

using namespace godot;

class MAssetMeshUpdater : public RefCounted {
    GDCLASS(MAssetMeshUpdater,RefCounted);

    protected:
    static void _bind_methods();
    public:
    static void refresh_all_masset_updater();

    private:
    static VSet<MAssetMeshUpdater*> asset_mesh_updater_list;
    Node3D* root_node = nullptr;
    int current_lod = -1;
    // For join mesh always the transform is at the same position of baker
    int join_mesh_id = -1;
    int join_at = -1;
    TypedArray<MMesh> joined_mesh;
    PackedInt32Array joined_mesh_ids;
    RID join_mesh_instance;

    private:
    void _update_lod(int lod);
    public:
    MAssetMeshUpdater();
    ~MAssetMeshUpdater();
    void update_join_mesh();
    void add_join_mesh(int lod);
    void remove_join_mesh();
    void update_auto_lod();
    void update_force_lod(int lod);

    PackedInt32Array get_joined_mesh_ids();
    TypedArray<MMesh> get_mesh_lod();
    int get_join_at_lod();

    int get_current_lod();

    void set_join_mesh_id(int input);
    int get_join_mesh_id();

    void set_root_node(Node3D* input);
    Node3D* get_root_node() const;
};
#endif