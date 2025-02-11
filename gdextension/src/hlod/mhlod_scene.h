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

class MHlodNode3D;

class MMesh;

using namespace godot;

template <typename T>
struct MDummyType
{
    MDummyType(const T& foo){}
};


class MHlodScene : public Node3D {
    friend MHlodNode3D;
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
        _FORCE_INLINE_ GlobalItemID(){
            oct_point_id = -1;
            transform_index = -1;
        };
        _FORCE_INLINE_ GlobalItemID(int32_t oct_point_id,int32_t transform_index):oct_point_id(oct_point_id),transform_index(transform_index){};
        _FORCE_INLINE_ GlobalItemID(int64_t id):id(id){};
        _FORCE_INLINE_ bool is_valid()const{return transform_index>=0;}
    };

    union PermanentItemID
    {
        struct
        {
            int32_t proc_id; // or index in procs
            int32_t item_id;
        };
        int64_t id;
        PermanentItemID()=default;
        _FORCE_INLINE_ PermanentItemID(int32_t proc_id,int32_t item_id):proc_id(proc_id),item_id(item_id){};
        _FORCE_INLINE_ PermanentItemID(int64_t id):id(id){};
        _FORCE_INLINE_ bool is_valid(){return item_id>=0;}
    };
    
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
        void disable(const bool recursive=true,const bool immediate=false,const bool is_destruction=false);
        void enable_sub_proc();
        void disable_sub_proc();
        _FORCE_INLINE_ void add_item(MHlod::Item* item,const int item_id,const bool immediate=false); // can be called in non-game loop thread as it generate apply info which will be affected in main game-loop
        _FORCE_INLINE_ void remove_item(MHlod::Item* item,const int item_id,const bool immediate=false,const bool is_destruction=false);
        _FORCE_INLINE_ Transform3D get_item_transform(const int32_t transform_index) const;
        // use bellow rather than upper
        _FORCE_INLINE_ Transform3D get_item_transform(const MHlod::Item* item) const;
        void update_item_transform(const int32_t transform_index,const Transform3D& new_transform);// Must be protect with packed_scene_mutex if Item is_bound = true
        void update_all_transform();
        void reload_meshes(const bool recursive=true); // must be called with mutex lock
        void remove_all_items(const bool immediate=false,const bool is_destruction=false);
        void update_lod(int8_t _lod,const bool immediate=false);
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
        _FORCE_INLINE_ PermanentItemID get_item_permanent_id(int item_id) const{
            ERR_FAIL_COND_V(!is_enable,PermanentItemID());
            if(item_id<0){
                return PermanentItemID();
            }
            return PermanentItemID(proc_id,item_id);
        }
        // All function bellow should be protected by packed_scene_mutex
        _FORCE_INLINE_ void bind_item_clear(const GlobalItemID bound_id);
        _FORCE_INLINE_ Transform3D bind_item_get_transform(const GlobalItemID bound_id) const;
        _FORCE_INLINE_ void bind_item_modify_transform(const GlobalItemID bound_id,const Transform3D& new_transform);
        _FORCE_INLINE_ bool bind_item_get_disable(const GlobalItemID bound_id) const;
        _FORCE_INLINE_ void bind_item_set_disable(const GlobalItemID bound_id,const bool disable);
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
    static std::mutex packed_scene_mutex;
    static bool is_updating;
    static bool is_octree_inserted;
    static uint16_t oct_id;
    static int32_t last_oct_point_id;
    static Vector<ApplyInfo> apply_info;
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
    // Debug Tools
    static Dictionary get_debug_info();


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
    bool is_init_scene() const;
    void set_hlod(Ref<MHlod> input);
    Ref<MHlod> get_hlod();
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
        std::conditional_t<UseLock,std::lock_guard<std::mutex>,MDummyType<std::mutex>> lock(MHlodScene::update_mutex);
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
        #ifdef DEBUG_ENABLED
        if(cached_triangled_mesh.is_valid()){
            cached_triangled_mesh.unref();
        }
        #endif
        if(!is_init_procs()){
            return;
        }
        std::conditional_t<UseLock,std::lock_guard<std::mutex>,MDummyType<std::mutex>> lock(MHlodScene::update_mutex);
        is_init = false;
        get_root_proc()->disable(true,true,true);
        flush();
        procs.resize(1);
    }
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