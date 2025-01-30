#ifndef __MHLODSCENE
#define __MHLODSCENE

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/templates/hash_set.hpp>
#include <godot_cpp/templates/vset.hpp>
#include <godot_cpp/classes/worker_thread_pool.hpp>

#ifdef DEBUG_ENABLED
#include <godot_cpp/classes/triangle_mesh.hpp>
#include <godot_cpp/classes/engine.hpp>
#endif

#include <mutex>

#include "../util/mbool_vector.h"
#include "../moctree.h"
#include "mhlod.h"

class MMesh;

using namespace godot;

class MHlodScene : public Node3D {
    GDCLASS(MHlodScene,Node3D);

    protected:
    static void _bind_methods();

    private:
    union GlobalItemID
    {
        struct
        {
            int32_t oct_point_id;
            int32_t transform_index;
        };
        int64_t id;
        _FORCE_INLINE_ GlobalItemID(int32_t oct_point_id,int32_t transform_index):oct_point_id(oct_point_id),transform_index(transform_index){};
        _FORCE_INLINE_ GlobalItemID(int64_t id):id(id){};
    };
    
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
        CreationInfo()=default;
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
        bool is_transform_changed = false;
        bool is_visible = true;
        bool is_enable = false;
        bool is_sub_proc_enable = true;
        int8_t lod = -1;
        uint16_t scene_layers = 0;
        uint16_t sub_procs_size = 0; // sub proc size is same as sub hlod 
        int32_t oct_point_id = -1;
        int32_t proc_id = -1; // Our index in Vector<Proc> in MHlodScene
        int32_t sub_proc_index = 0; // Our sub procs index start point in Vector<Proc> in MHlodScene
        Ref<MHlod> hlod;
        MHlodScene* scene = nullptr;
        HashMap<int32_t,CreationInfo> items_creation_info; // key is transform index
        #ifdef DEBUG_ENABLED
        // Need local transform because editor need this and we don't have it in this struct
        void _get_editor_tri_mesh_info(PackedVector3Array& vertices,PackedInt32Array& indices,const Transform3D& local_transform) const;
        #endif
        Transform3D transform; // global transform
        
        Proc(MHlodScene* _scene,Ref<MHlod> _hlod,int32_t _proc_id,int32_t _scene_layers,const Transform3D& _transform);
        Proc() = default;
        ~Proc();
        void init_sub_proc(int32_t _sub_proc_index,uint64_t _sub_proc_size,int32_t _proc_id);
        void change_transform(const Transform3D& new_transform);
        // difference between init deinit and enable and disable is that the latter one will not remove sub procs
        // or in another word enable and disable will only turn off and not remove the the sturcture of procs and subprocs
        // enable and disable will remove themself from octree
        void enable(const bool recursive=true);
        void disable(const bool recursive=true);
        void enable_sub_proc();
        void disable_sub_proc();
        _FORCE_INLINE_ void add_item(MHlod::Item* item,const int item_id,const bool immediate=false); // can be called in non-game loop thread as it generate apply info which will be affected in main game-loop
        _FORCE_INLINE_ void remove_item(MHlod::Item* item,const int item_id,const bool immediate=false);
        _FORCE_INLINE_ void update_item_transform(MHlod::Item* item);
        void update_all_transform();
        void reload_meshes(const bool recursive=true); // must be called with mutex lock
        void remove_all_items(const bool immediate=false,const bool recursive=true);
        void update_lod(int8_t _lod,const bool immediate=false);
        void set_visibility(bool visibility);
        _FORCE_INLINE_ const Proc* get_subprocs_ptr() const{
            return scene->procs.ptr() + sub_proc_index;
        }
        _FORCE_INLINE_ Proc* get_subprocs_ptrw() const{
            return scene->procs.ptrw() + sub_proc_index;
        }
    };
    bool is_init = false;
    uint16_t scene_layers = 0;
    Vector<Proc> procs; // Consist root proc and all sub_procs /// 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17
    MBoolVector procs_update_state; // show each proc if they are update or not in the last recent update, access it under update_mutex protection
    friend Proc;
    friend MMesh;

    /// Static --> Proc Manager
    static bool is_sleep;
    static Vector<Proc*> all_tmp_procs;
    static VSet<MHlodScene*> all_hlod_scenes;
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
    static void first_octree_update(Vector<MOctree::PointUpdate>* update_info);
    static void octree_update(Vector<MOctree::PointUpdate>* update_info);
    static void octree_thread_update(void* input);
    static void update_tick();
    static void apply_remove_item_users();
    static void apply_update();
    static void flush();

    static void sleep();
    static void awake();
    static Array get_hlod_users(const String& hlod_path);

    private:
    _FORCE_INLINE_ Proc* get_root_proc(){
        ERR_FAIL_COND_V(procs.size()==0,nullptr);
        return procs.ptrw();
    }
    _FORCE_INLINE_ void _init_proc();
    public:
    //Ref<MHlod> hlod;
    MHlodScene();
    ~MHlodScene();
    inline bool is_init_procs(){
        return is_init;
    }
    void set_hlod(Ref<MHlod> input);
    Ref<MHlod> get_hlod();
    void set_scene_layers(int64_t input);
    int64_t get_scene_layers();
    void _notification(int p_what);
    void _update_visibility();
    #ifdef DEBUG_ENABLED
    Ref<TriangleMesh> editor_tri_mesh;
    void _update_editor_tri_mesh(); // will be called in update thread
    #endif
    Array get_triangle_meshes();

    // usefull for joining the mesh
    Array get_last_lod_mesh_ids_transforms();


    template<bool UseLock>
    void init_proc(){
        if(procs.size()==0){
            procs.resize(1);
        }
        if(!is_inside_tree()){
            return;
        }
        ERR_FAIL_COND(get_root_proc()==nullptr);
        if(is_init_procs() || get_root_proc()->hlod.is_null()){
            return;
        }
        if constexpr (UseLock){
            std::lock_guard<std::mutex> lock(MHlodScene::update_mutex);
        }
        if(is_sleep){
            return;
        }
        ERR_FAIL_COND(procs.size() == 0);
        Ref<MHlod> main_hlod = procs[0].hlod;
        ERR_FAIL_COND(main_hlod.is_null());
        procs.clear();
        Transform3D gtransform = get_global_transform();
        int checked_children_to_add_index = -1;
        // Adding root proc
        procs.push_back(Proc(this,main_hlod,0,scene_layers,gtransform));
        while (checked_children_to_add_index != procs.size() - 1)
        {
            ++checked_children_to_add_index;
            Proc& current_proc = procs.ptrw()[checked_children_to_add_index];
            Ref<MHlod> current_hlod = current_proc.hlod;
            ERR_CONTINUE(current_hlod.is_null());
            int sub_proc_size = current_hlod->sub_hlods.size();
            int sub_proc_index = procs.size();
            current_proc.init_sub_proc(sub_proc_index,sub_proc_size,checked_children_to_add_index);
            // pushing back childrens
            for(int i=0; i < sub_proc_size; i++){
                Ref<MHlod> s = current_hlod->sub_hlods[i];
                ERR_FAIL_COND(s.is_null());
                uint16_t s_layers = current_hlod->sub_hlods_scene_layers[i];
                Transform3D s_transform = current_proc.transform * current_hlod->sub_hlods_transforms[i];
                int32_t proc_id = sub_proc_index + i;
                procs.push_back(Proc(this,s,proc_id,s_layers,s_transform));
            }
        }
        // enabling procs, don't use recursive, important for ordering!
        for(int i=0; i < procs.size(); i++){
            procs.ptrw()[i].enable(false);
        }
        is_init = true;
    }
    
    template<bool UseLock>
    void deinit_proc(){
        if(!is_init_procs()){
            return;
        }
        if constexpr (UseLock){
            std::lock_guard<std::mutex> lock(MHlodScene::update_mutex);
        }
        is_init = false;
        get_root_proc()->disable(true);
        flush();
        procs.resize(1);
    }

    void check_transform_change(){
        UtilityFunctions::print("CHeki");
        for(int i=0; i < all_tmp_procs.size();i++){
            if(!all_tmp_procs[i]->is_transform_changed){
                UtilityFunctions::print(i ," not changed");
            }
        }
        return;
        for(int i=0; i < procs.size();i++){
            if(!procs[i].is_transform_changed){
                UtilityFunctions::print(i ," not changed");
            }
        }
    }
};
#endif