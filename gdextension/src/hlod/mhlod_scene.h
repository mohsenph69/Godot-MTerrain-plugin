#ifndef __MHLODSCENE
#define __MHLODSCENE

#define MHLODSCENE_DEBUG_COUNT 0
#if MHLODSCENE_DEBUG_COUNT
#include <atomic>
#endif

#define MHLODSCENE_DISABLE_PHYSICS 0
#define MHLODSCENE_DISABLE_RENDERING 0
#define MHLODSCENE_THREAD_RENDERING 0

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

class MHlodNode3D;

class MMesh;

using namespace godot;

class MHlodScene : public Node3D {
    friend MHlodNode3D;
    struct Proc;
    GDCLASS(MHlodScene,Node3D);
    #if MHLODSCENE_DEBUG_COUNT
    /**
     * @brief
     * when body_add_shape(); will be total_shape_count++!
     * when body_remove_shape(); will be total_shape_count--!
     */
    inline static std::atomic<int> total_shape_count = {0};
    /**
     * @brief
     * when RS->instance_create(); will be total_rendering_instance_count++!
     * when RS->free_rid(); will be total_rendering_instance_count--!
     */
    inline static std::atomic<int> total_rendering_instance_count = {0};
    /**
     * @brief
     * in MHlodNode3D constructor total_rendering_instance_count++
     * in MHlodNode3D destructor total_rendering_instance_count--
     */
    inline static std::atomic<int> total_packed_scene_count = {0};
    #endif
    /**
     * @brief After LOAD_REST all stage is done by @ref apply_update function
     * I know APPLY_LIGHT and APPLY_COLLISION are almost empty but they are there for more cpu IDLE time and future update
     */
    enum class UpdateState:int8_t{
        OCTREE = 0,
        LOAD,
        LOAD_REST,
        APPLY_LIGHT,
        APPLY_COLLISION,
        APPLY_COLLISION_COMPLEX,
        APPLY_DECAL,
        APPLY_MESH,
        APPLY_PACKED_SCENE,
        REMOVE_USER,
        APPLY_CLEAR,
        UPDATE_STATE_MAX
    };
    _FORCE_INLINE_ static UpdateState get_next_update_state(const UpdateState _cs){
        if(_cs==UpdateState::UPDATE_STATE_MAX){
            return UpdateState::OCTREE;
        }
        return static_cast<UpdateState>(static_cast<int8_t>(_cs) + 1);
    }
    _FORCE_INLINE_ static bool is_update_state_rendering(const UpdateState _cs){
        return _cs==UpdateState::APPLY_LIGHT || _cs==UpdateState::APPLY_DECAL || _cs==UpdateState::APPLY_MESH;
    }
    _FORCE_INLINE_ static bool is_update_state_physics(const UpdateState _cs){
        return _cs==UpdateState::APPLY_COLLISION || _cs==UpdateState::APPLY_COLLISION_COMPLEX;
    }
    protected:
    static void _bind_methods();

    public:
    union GlobalItemID
    {
        struct
        {
            int32_t oct_point_id;
            int32_t transform_index;
        };
        int64_t id;
        _FORCE_INLINE_ GlobalItemID(){
            oct_point_id = -1;
            transform_index = -1;
        };
        _FORCE_INLINE_ GlobalItemID(int32_t oct_point_id,int32_t transform_index):oct_point_id(oct_point_id),transform_index(transform_index){};
        _FORCE_INLINE_ GlobalItemID(int64_t id):id(id){};
        _FORCE_INLINE_ bool is_valid()const{return transform_index>=0;}
    };
    private:
    struct CreationInfo
    {
        // 1 more free byte Up here
        MHlod::Type type = MHlod::Type::NONE;
        int16_t body_id = -1; // in case need this space for other type just put this in union
        int32_t item_id = -1;
        union
        {
            int64_t rid;
            MHlodNode3D* root_node;
        };
        _FORCE_INLINE_ void set_rid(const RID input){
            rid = input.get_id();
        }
        _FORCE_INLINE_ RID get_rid() const{
            RID out;
            memcpy(&out,&rid,sizeof(RID));
            return out;
        }
        CreationInfo()=default;
    };
    /**
     * @brief As we create instance in update thread and both update thread and bind_item_set_disabled (in MHlodNode3D)
     * use update_mutex protection as disable visual instance set disable_visible in update thread
     * And disabling visuall has nothing to do with apply_update it is ok this way!
     * This is not true for ApplyInfoPhysics as disable shape should be set in apply_update
     * **More explanation in ApplyInfoPhysics**
     */
    class ApplyInfoRendering
    {
        inline static Vector<ApplyInfoRendering> data;
        bool remove;
        MHlod::Item* item;
        RID instance;
        public:
        ApplyInfoRendering()=default;
        _FORCE_INLINE_ ApplyInfoRendering(RID instance, MHlod::Item* item,bool remove):
        instance(instance),item(item),remove(remove){}
        _FORCE_INLINE_ bool is_remove() const {return remove;}
        _FORCE_INLINE_ MHlod::Item* get_item() const {return item;}
        _FORCE_INLINE_ RID get_instance() const {return instance;}
        _FORCE_INLINE_ static void add(RID instance, MHlod::Item* item,bool remove){
            data.push_back(ApplyInfoRendering(instance,item,remove));
        }
        _FORCE_INLINE_ static void clear(){
            data.clear();
        }
        _FORCE_INLINE_ static const ApplyInfoRendering& get(int index) {
            return data[index];
        }
        _FORCE_INLINE_ static size_t size() {
            return data.size();
        }
    };
    /**
     * @brief (Only Add) we can not determine the value of bind item disable in update thread and pass it with ApplyInfoPhysics
     * As it might change afterward
     * For ApplyInfoRendering we can do this because even if it change after it will automaticlly set by bind_item_set_disabled
     * As in case of Physic Flickiring does not matter! only if has_cache is false will send apply info
     * For the same reason above removing a physics Item only happen in update thread
     */
    class ApplyInfoPhysics {
        inline static Vector<ApplyInfoPhysics> data;
        MHlod::Item* item;
        GlobalItemID gitem_id;
        Proc* proc;
        public:
        ApplyInfoPhysics()=default;
        _FORCE_INLINE_ ApplyInfoPhysics(MHlod::Item* item,Proc* proc,GlobalItemID gitem_id):
        item(item),proc(proc),gitem_id(gitem_id) {}
        _FORCE_INLINE_ MHlod::Item* get_item() const {return item;}
        _FORCE_INLINE_ Proc* get_proc() const {return proc;}
        _FORCE_INLINE_ GlobalItemID get_gitem_id() const {return gitem_id;}
        _FORCE_INLINE_ static void add(MHlod::Item* item,Proc* proc,GlobalItemID gitem_id){
            data.push_back(ApplyInfoPhysics(item,proc,gitem_id));
        }
        _FORCE_INLINE_ static void clear(){
            data.clear();
        }
        _FORCE_INLINE_ static const ApplyInfoPhysics& get(int index) {
            return data[index];
        }
        _FORCE_INLINE_ static size_t size() {
            return data.size();
        }
    };
    /**
     * @brief For non-cached PackedScene only adding
     */
    class ApplyInfoPackedScene {
        inline static Vector<ApplyInfoPackedScene> data;
        MHlod::Item* item;
        GlobalItemID gitem_id;
        Proc* proc;
        public:
        ApplyInfoPackedScene()=default;
        _FORCE_INLINE_ ApplyInfoPackedScene(MHlod::Item* item,Proc* proc,GlobalItemID gitem_id):
        item(item),proc(proc),gitem_id(gitem_id) {}
        _FORCE_INLINE_ MHlod::Item* get_item() const {return item;}
        _FORCE_INLINE_ Proc* get_proc() const {return proc;}
        _FORCE_INLINE_ GlobalItemID get_gitem_id() const {return gitem_id;}
        _FORCE_INLINE_ static void add(MHlod::Item* item,Proc* proc,GlobalItemID gitem_id){
            data.push_back(ApplyInfoPackedScene(item,proc,gitem_id));
        }
        _FORCE_INLINE_ static void clear(){
            data.clear();
        }
        _FORCE_INLINE_ static const ApplyInfoPackedScene& get(int index) {
            return data[index];
        }
        _FORCE_INLINE_ static size_t size() {
            return data.size();
        }
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
        void disable(const bool recursive,const bool is_destruction);
        void enable_sub_proc();
        void disable_sub_proc();
        _FORCE_INLINE_ void add_item(MHlod::Item* item,const int item_id); // can be called in non-game loop thread as it generate apply info which will be affected in main game-loop
        _FORCE_INLINE_ void remove_item(MHlod::Item* item,const int item_id,const bool is_destruction=false); // should clear creation_info afer calling this
        _FORCE_INLINE_ Transform3D get_item_transform(const int32_t transform_index) const;
        // use bellow rather than upper
        _FORCE_INLINE_ Transform3D get_item_transform(const MHlod::Item* item) const;
        void update_item_transform(const int32_t transform_index,const Transform3D& new_transform);// Must be protect with packed_scene_mutex if Item is_bound = true
        void update_all_transform();
        void reload_meshes(const bool recursive=true); // must be called with mutex lock
        void remove_all_items(const bool immediate=false,const bool is_destruction=false);
        void update_lod(int8_t _lod);
        void set_visibility(bool visibility);
        _FORCE_INLINE_ const Proc* get_subprocs_ptr() const{
            return scene->procs.ptr() + sub_proc_index;
        }
        _FORCE_INLINE_ Proc* get_subprocs_ptrw() const{
            return scene->procs.ptrw() + sub_proc_index;
        }
        _FORCE_INLINE_ GlobalItemID get_item_global_id(int item_id) const{
            ERR_FAIL_COND_V(!is_enable,GlobalItemID());
            if(item_id<0){
                return GlobalItemID();
            }
            ERR_FAIL_COND_V(item_id>=hlod->item_list.size(),GlobalItemID());
            int32_t btransform_index = hlod->item_list[item_id].transform_index;
            return GlobalItemID(oct_point_id,btransform_index);
        }
        // All function bellow should be protected by packed_scene_mutex
        _FORCE_INLINE_ void bind_item_clear(const GlobalItemID bound_id);
        _FORCE_INLINE_ Transform3D bind_item_get_transform(const GlobalItemID bound_id) const;
        _FORCE_INLINE_ void bind_item_modify_transform(const GlobalItemID bound_id,const Transform3D& new_transform);
        _FORCE_INLINE_ bool bind_item_get_disable(const GlobalItemID bound_id) const;
        _FORCE_INLINE_ void bind_item_set_disable(const GlobalItemID bound_id,const bool disable);
    };
    bool is_hidden = false;
    bool is_init = false;
    uint16_t scene_layers = 0;
    Ref<MHlod> main_hlod;
    Vector<Proc> procs; // Consist root proc and all sub_procs /// 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17
    MBoolVector procs_update_state; // show each proc if they are update or not in the last recent update, access it under update_mutex protection
    friend Proc;
    friend MMesh;

    /// Static --> Proc Manager
    static double load_rest_timeout;
    static bool is_sleep;
    static Vector<Proc*> all_tmp_procs;
    static VSet<MHlodScene*> all_hlod_scenes;
    static HashMap<int32_t,Proc*> octpoints_to_proc;
    static MOctree* octree;
    static WorkerThreadPool::TaskID thread_task_id;
    static std::mutex update_mutex;
    static std::mutex packed_scene_mutex;
    static UpdateState update_state;
    static bool is_octree_inserted;
    static uint16_t oct_id;
    static int32_t last_oct_point_id;
    static Vector<MHlod::Item*> removing_users;
    static VSet<MHlodNode3D*> removed_packed_scenes;
    // key is global ID if Item, should be access with protection of packed_scene_mutex
    // Bellow has only Creation info of bound items (none bound Item are not here)
    static HashMap<int64_t,CreationInfo> bound_items_creation_info;
    static HashMap<int64_t,Transform3D> bound_items_modified_transforms;
    static HashSet<int64_t> bound_items_disabled;
    public:
    static bool is_my_octree(MOctree* input);
    static bool set_octree(MOctree* input);
    static MOctree* get_octree();
    static uint16_t get_oct_id();
    static int32_t get_free_oct_point_id();
    static int32_t add_proc(Proc* _proc,int oct_point_id);
    static void remove_proc(int32_t octpoint_id);
    static void move_proc(int32_t octpoint_id,const Vector3& old_pos,const Vector3& new_pos);
    static void insert_points();
    static void first_octree_update(Vector<MOctree::PointUpdate>* update_info);
    static void octree_update(Vector<MOctree::PointUpdate>* update_info);
    static void octree_thread_update(void* input);
    static void update_tick(double delta);
    static void apply_update(UpdateState u_state);

    static void set_load_rest_timeout(double input);
    static double get_load_rest_timeout();
    static void sleep();
    static void awake();
    static Array get_hlod_users(const String& hlod_path);
    // Debug Tools
    static Dictionary get_debug_info();


    private:
    _FORCE_INLINE_ Proc* get_root_proc(){
        if(procs.size()==0){
            procs.resize(1);
        }
        return procs.ptrw();
    }
    public:
    //Ref<MHlod> hlod;
    MHlodScene();
    ~MHlodScene();
    inline bool is_init_procs(){
        return is_init;
    }
    void set_is_hidden(bool input);
    bool is_init_scene() const;
    void set_hlod(Ref<MHlod> input);
    Ref<MHlod> get_hlod() const;
    AABB get_aabb() const;
    void set_scene_layers(int64_t input);
    int64_t get_scene_layers();
    void _notification(int p_what);
    void _update_visibility();

    // usefull for joining the mesh
    Array get_last_lod_mesh_ids_transforms();

    // Works only in editor
    #ifdef DEBUG_ENABLED
    Ref<TriangleMesh> cached_triangled_mesh;
    Ref<TriangleMesh> get_triangle_mesh();
    #endif
    /// @brief  must be called with update_mutex
    void init_proc();
    /// @brief  must be called with update_mutex
    void deinit_proc();
};

_FORCE_INLINE_ Transform3D MHlodScene::Proc::get_item_transform(const int32_t transform_index) const{
    GlobalItemID gid(oct_point_id,transform_index);
    {
        std::lock_guard<std::mutex> plock(packed_scene_mutex);
        if(bound_items_modified_transforms.has(gid.id)){
            return bound_items_modified_transforms[gid.id];
        }
    }
    return transform * hlod->transforms[transform_index];
}

_FORCE_INLINE_ Transform3D MHlodScene::Proc::get_item_transform(const MHlod::Item* item) const{
    if(item->is_bound){
        GlobalItemID gid(oct_point_id,item->transform_index);
        std::lock_guard<std::mutex> plock(packed_scene_mutex);
        if(bound_items_modified_transforms.has(gid.id)){
            return bound_items_modified_transforms[gid.id];
        }
    }
    return transform * hlod->transforms[item->transform_index];
}

// All bind_item_ should be called with std::lock_guard<std::mutex> plock(packed_scene_mutex);
_FORCE_INLINE_ void MHlodScene::Proc::bind_item_clear(const MHlodScene::GlobalItemID bound_id){
    bind_item_set_disable(bound_id,false);
    bound_items_modified_transforms.erase(bound_id.id);
    // Not using get_item_transform function as it use packed_scene_mutex and will cause dead lock!
    update_item_transform(bound_id.transform_index,transform * hlod->transforms[bound_id.transform_index]);
}

_FORCE_INLINE_ Transform3D MHlodScene::Proc::bind_item_get_transform(const MHlodScene::GlobalItemID bound_id) const{
   return get_item_transform(bound_id.transform_index);
}

_FORCE_INLINE_ void MHlodScene::Proc::bind_item_modify_transform(const MHlodScene::GlobalItemID bound_id,const Transform3D& new_transform){
    bound_items_modified_transforms.insert(bound_id.id,new_transform);
    update_item_transform(bound_id.transform_index,new_transform);
}

_FORCE_INLINE_ bool MHlodScene::Proc::bind_item_get_disable(const GlobalItemID bound_id) const{
    return bound_items_disabled.has(bound_id.id);
}

_FORCE_INLINE_ void MHlodScene::Proc::bind_item_set_disable(const MHlodScene::GlobalItemID bound_id,const bool disable){
    if(disable){
        bound_items_disabled.insert(bound_id.id);
    } else {
        bound_items_disabled.erase(bound_id.id);
    }
    if(!bound_items_creation_info.has(bound_id.id)){
        return; // not exist nothing to do anymore
    }
    const CreationInfo& ci = bound_items_creation_info[bound_id.id];
    switch (ci.type)
    {
    case MHlod::Type::MESH:
    case MHlod::Type::LIGHT:
        RS->instance_set_visible(ci.get_rid(),!disable);
        break;
    case MHlod::Type::COLLISION:
        {
            MHlod::PhysicBodyInfo& binfo = MHlod::get_physic_body(ci.body_id);
            int index = binfo.shapes.find(bound_id.id);
            ERR_FAIL_COND(index==-1);
            PhysicsServer3D::get_singleton()->body_set_shape_disabled(binfo.rid,index,disable);
        }
        break;
    default:
        break;
    }
}
#endif