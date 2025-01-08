#ifndef __MHLODSCENE
#define __MHLODSCENE

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/templates/hash_set.hpp>
#include <godot_cpp/classes/worker_thread_pool.hpp>

#include <mutex>

#include "../moctree.h"
#include "mhlod.h"

class MMesh;

using namespace godot;

class MHlodScene : public Node3D {
    GDCLASS(MHlodScene,Node3D);

    protected:
    static void _bind_methods();

    private:
    struct CreationInfo
    {
        // There is another 4 byte space here!!!
        MHlod::Type type = MHlod::Type::NONE;
        int item_id = -1;
        union
        {
            int64_t rid;
            Node* packed_scene;
        };
        _FORCE_INLINE_ void set_rid(const RID input);
        _FORCE_INLINE_ RID get_rid() const;
    };

    struct ApplyInfo
    {
        MHlod::Type type;
        bool remove;
        union
        {
            int64_t instance;
        };
        ApplyInfo()=default;
        ApplyInfo(MHlod::Type _type,bool _remove);
        // For type Mesh
        _FORCE_INLINE_ void set_instance(const RID input);
        _FORCE_INLINE_ RID get_instance() const;
    };
    /*
    Update Steps for procs
    in another cpu thread call update_lod (for the first update update_lod will be called in main game loop with immediate=true)
    Collecting the information which need to be change in main game loop in apply_info
    After finishing update_lod! in main game loop do what is inside apply_info which is static
    //////////////// Removing user from item id
    As we don't use any item we should call remove user from them and if the user count arrive to zero item will be free its resources
    //// in each update_lod we store the item_id which should be called remove_user() on that
    //// we keep this in a Vector<item*> remove_users which is static
    */
    struct Proc
    {
        // Creation Info! every information which is generated after creating each object
        // This is needed to be able to free the object later!
        bool is_init = false;
        bool is_visible = true;
        bool is_enable = true;
        bool is_sub_proc_enable = true;
        int8_t lod = -1;
        uint16_t scene_layers = 0;
        uint16_t sub_procs_size = 0;
        int32_t oct_point_id = -1;
        Ref<MHlod> hlod;
        Proc* sub_proc_ptr = nullptr;
        HashMap<int32_t,CreationInfo> items_creation_info; // key is transform index
        Transform3D transform;

        Proc();
        ~Proc();
        void change_transform(const Transform3D& new_transform);
        void init(Vector<Proc>& sub_procs_arr,int& sub_proc_index,const Transform3D& _transform,uint16_t _scene_layers);
        void deinit();
        // difference between init deinit and enable and disable is that the latter one will not remove sub_proc_ptr
        // or in another word enable and disable will only turn off and not remove the the sturcture of procs and subprocs
        // enable and disable will remove themself from octree
        void enable();
        void disable();
        void enable_sub_proc();
        void disable_sub_proc();
        _FORCE_INLINE_ void add_item(MHlod::Item* item,const int item_id,const bool immediate=false); // can be called in non-game loop thread as it generate apply info which will be affected in main game-loop
        _FORCE_INLINE_ void remove_item(MHlod::Item* item,const int item_id,const bool immediate=false);
        _FORCE_INLINE_ void update_item_transform(MHlod::Item* item);
        void update_all_transform();
        void reload_meshes(const bool recursive=true); // must be called with mutex lock
        void update_hlod(Ref<MHlod> new_hlod);
        void remove_all_items(const bool immediate=false,const bool recursive=true);
        void update_lod(int8_t _lod,const bool immediate=false);
        void set_visibility(bool visibility);
    };
    uint16_t scene_layers = 0;
    MHlodScene::Proc proc; /// 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17
    Vector<Proc> sub_procs; // Consist all sub_procs
    friend Proc;
    friend MMesh;

    /// Static --> Proc Manager
    static bool is_sleep;
    static HashSet<MHlodScene*> all_hlod_scenes;
    static HashMap<int32_t,Proc*> octpoints_to_proc;
    static MOctree* octree;
    static WorkerThreadPool::TaskID thread_task_id;
    static std::mutex update_mutex;
    static bool is_updating;
    static bool is_octree_inserted;
    static uint16_t oct_id;
    static int32_t last_oct_point_id;
    static Vector<ApplyInfo> apply_info;
    static Vector<MHlod::Item*> removing_users;
    public:
    static bool is_my_octree(MOctree* input);
    static bool set_octree(MOctree* input);
    static MOctree* get_octree();
    static uint16_t get_oct_id();
    static int32_t add_proc(Proc* _proc,int oct_point_id);
    static void remove_proc(int32_t octpoint_id);
    static void move_proc(int32_t octpoint_id,const Vector3& old_pos,const Vector3& new_pos);
    static void insert_points();
    static void octree_update(const Vector<MOctree::PointUpdate>* update_info);
    static void octree_thread_update(void* input);
    static void update_tick();
    static void apply_remove_item_users();
    static void apply_update();
    static void flush();

    static void sleep();
    static void awake();
    static Array get_hlod_users(const String& hlod_path);

    //Ref<MHlod> hlod;
    MHlodScene();
    ~MHlodScene();
    void init_proc();
    void init_proc_no_lock();
    void deinit_proc();
    void deinit_proc_no_lock();
    inline bool is_init_proc();
    void set_hlod(Ref<MHlod> input);
    Ref<MHlod> get_hlod();
    void set_scene_layers(int64_t input);
    int64_t get_scene_layers();
    void _notification(int p_what);
    void _update_visibility();

    // usefull for joining the mesh
    Array get_last_lod_mesh_ids_transforms();
};
#endif