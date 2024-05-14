#ifndef _MOCTMESH
#define _MOCTMESH



#define OCT_POINT_ID_START 0

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/classes/worker_thread_pool.hpp>

#include <atomic>
#include <mutex>
#include "mmesh_lod.h"
#include "../mocttree.h"

using namespace godot;


class MOctMesh : public Node3D {
    GDCLASS(MOctMesh,Node3D);

    friend class MOctTree;
    
    protected:
    static void _bind_methods();    
    

    private:
    /// Static Part
    static WorkerThreadPool::TaskID thread_task_id;
    static std::mutex update_mutex;
    static bool is_updating;
    static bool is_octtree_inserted;
    static uint16_t oct_id;
    static int32_t last_oct_point_id;
    static HashMap<int32_t,MOctMesh*> octpoint_to_octmesh;
    static MOctTree* octtree;
    

    public:
    static bool is_my_octtree(MOctTree* input);
    static uint16_t get_oct_id();
    static bool set_octtree(MOctTree* input);
    static void remove_octtree(MOctTree* input);
    static void insert_points();
    static int32_t add_octmesh(MOctMesh* input); // use update_mutex
    static void remove_octmesh(int32_t id); // use update_mutex
    static void move_octmesh(MOctMesh* input);
    static void octtree_update(const Vector<MOctTree::PointUpdate>* update_info);
    static void octtree_thread_update(void* input); // use update_mutex
    static void update_tick();



    // Non static part
    private:
    std::atomic<int8_t> lod{-1};
    //int8_t lod = -1;
    int32_t oct_point_id = INVALID_OCT_POINT_ID;
    RID instance; // use with update_mutex protection
    RID current_mesh; // use with update_mutex protection
    Ref<MMeshLod> mesh_lod;

    void _update_visibilty();

    public:
    Vector3 oct_position;
    MOctMesh();
    ~MOctMesh();

    // -2 means update current mesh without changing LOD
    // -3 is invalide object, or it will removed
    void update_lod_mesh(int8_t new_lod=-2); // must be called with update_mutex protection
    Ref<Mesh> get_active_mesh();

    void set_mesh_lod(Ref<MMeshLod> input); // use update_mutex
    Ref<MMeshLod> get_mesh_lod();

    

    _FORCE_INLINE_ bool has_valid_oct_point_id();

    void _notification(int p_what); // some part use update_mutex
    void _lod_mesh_changed(); // use update_mutex

};
#endif