#ifndef __MHLOD__
#define __MHLOD__

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/templates/vector.hpp>
#include <godot_cpp/templates/vset.hpp>
#include <godot_cpp/templates/hash_set.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/physics_server3d.hpp>
#include "mhlod_collision_setting.h"

#include <godot_cpp/classes/resource_loader.hpp>
#include "mhlod_item.h"

using namespace godot;

#define MHLOD_CONST_GI_MODE_DISABLED 0
#define MHLOD_CONST_GI_MODE_STATIC 1
#define MHLOD_CONST_GI_MODE_DYNAMIC 2
#define MHLOD_CONST_GI_MODE_STATIC_DYNAMIC 3

class MHlod : public Resource{
    GDCLASS(MHlod, Resource);

    protected:
    static void _bind_methods();

    public:
    static inline int64_t physic_space = 0; // RID will crash so using this
    struct PhysicBodyInfo
    {
        RID rid;
        // bellow contain ItemGlobalIDs
        // index of it is the shape index in PhysicsServer
        Vector<int64_t> shapes;
        _FORCE_INLINE_ PhysicBodyInfo(RID body_rid):rid(body_rid){}
    };
    struct ItemResource {
        RID rid;
        PackedScene* packed_scene = nullptr;
        _FORCE_INLINE_ ItemResource(const RID p_rid){
            rid = p_rid;
        }
        _FORCE_INLINE_ ItemResource(PackedScene* p_packed_scene){
            packed_scene = p_packed_scene;
        }
    };
    static inline const char* type_string = "NONE,MESH,COLLISION,LIGHT,PACKED_SCENE,DECAL";
    enum GIMode : uint8_t {
        GI_MODE_DISABLED = MHLOD_CONST_GI_MODE_DISABLED,
        GI_MODE_STATIC = MHLOD_CONST_GI_MODE_STATIC,
        GI_MODE_DYNAMIC = MHLOD_CONST_GI_MODE_DYNAMIC,
        GI_MODE_STATIC_DYNAMIC = MHLOD_CONST_GI_MODE_STATIC_DYNAMIC
    };
    enum Type : uint8_t {NONE,MESH,COLLISION,COLLISION_COMPLEX,LIGHT,PACKED_SCENE,DECAL};
    struct Item
    {
        friend MHlod;
        Type type = NONE; // 0
        bool is_bound = false;
        int8_t lod = -1; // 1
        uint16_t item_layers = 0;
        int32_t transform_index = -1; // Same as unique id for each Item with different LOD
        int32_t user_count = 0;
        union {
            MHLodItemMesh mesh;
            MHLodItemCollision collision;
            MHLodItemCollisionComplex collision_complex;
            MHLodItemLight light;
            MHLodItemPackedScene packed_scene;
            MHLodItemDecal decal;
        };
        void create();
        void copy(const Item& other);
        void clear();
        public:
        Item();
        Item(Type _type);
        ~Item();
        Item(const Item& other);
        Item& operator=(const Item& other);
        
        _FORCE_INLINE_ int16_t get_physics_body();
        _FORCE_INLINE_ ItemResource get_res_and_add_user();
        _FORCE_INLINE_ void remove_user();

        void set_data(const Dictionary& d);
        Dictionary get_data() const;
    };
    private:
    // -1 is default static body any invalid id use default body
    // -2 is invalid static body
    static inline HashMap<int16_t,PhysicBodyInfo> physic_bodies;


    /* Item List structure
        [itemA_lod0,itemA_lod1,itemA_lod2, .... , itemB_lod0,itemB_lod1,itemB_lod2]
        the start index (in this case index of itemA_lod0) is the id of that item
        one LOD can be droped if it is a duplicate Base on this if item LOD does not exist we pick the last existing one
        Only two neghbor similar lod can be detected
    */
    public:
    MHlod() = default;
    ~MHlod() = default;
    MByteFloat<false,1024> v1;
    void set_v1(float input){
        v1 = input;
    }
    float get_v1(){
        return v1;
    }
    int join_at_lod = -1;
    #ifdef DEBUG_ENABLED
    String baker_path;
    #endif
    AABB aabb;
    Vector<Item> item_list;
    Vector<Transform3D> transforms;
    Vector<VSet<int32_t>> lods;
    Vector<Transform3D> sub_hlods_transforms;
    Vector<Ref<MHlod>> sub_hlods;
    Vector<uint16_t> sub_hlods_scene_layers;

    void _get_sub_hlod_size_rec(int& size);
    public:
    static String get_asset_root_dir();
    static String get_mesh_root_dir();
    static String get_physics_settings_dir();
    static String get_physic_setting_path(int id);
    static String get_mesh_path(int64_t mesh_id);
    static String get_packed_scene_root_dir();
    static String get_packed_scene_path(int id);
    static String get_decal_root_dir();
    static String get_decal_path(int id);
    static String get_collision_root_dir();
    static String get_collsion_path(int id);
    static String get_hlod_root_dir();
    static String get_hlod_path(int id);
    static _FORCE_INLINE_ MHlod::PhysicBodyInfo& get_physic_body(int16_t id);
    static _FORCE_INLINE_ void clear_physic_body();

    MHlod::Type get_item_type(int32_t item_id) const;
    void set_aabb(const AABB& aabb);
    const AABB& get_aabb() const;
    int get_item_count() const;
    void set_join_at_lod(int input);
    int get_join_at_lod();
    int get_sub_hlod_size_rec();
    void add_sub_hlod(const Transform3D& transform,Ref<MHlod> hlod,uint16_t scene_layers);
    int add_mesh_item(const Transform3D& transform,const PackedInt32Array& mesh,const PackedInt32Array& material,const PackedByteArray& shadow_settings,const PackedByteArray& gi_modes,int32_t render_layers,int32_t hlod_layers);
    Dictionary get_mesh_item(int item_id);
    PackedInt32Array get_mesh_items_ids() const;
    int get_last_lod_with_mesh() const;

    void insert_item_in_lod_table(int item_id,int lod);
    Array get_lod_table();
    void clear();

    void get_last_valid_item_ids(Type type,PackedInt32Array& ids);
    int32_t get_mesh_id(int32_t item_id,bool current_lod,bool lowest_lod) const;

    /// Physics
    int shape_add_sphere(const Transform3D& _transform,float radius,uint16_t layers,int body_id=-1);
    int shape_add_box(const Transform3D& _transform,const Vector3& size,uint16_t layers,int body_id=-1);
    int shape_add_capsule(const Transform3D& _transform,float radius,float height,uint16_t layers,int body_id=-1);
    int shape_add_cylinder(const Transform3D& _transform,float radius,float height,uint16_t layers,int body_id=-1);
    int shape_add_complex(const int32_t id,const Transform3D& _transform,uint16_t layers,int body_id=-1);

    int packed_scene_add(const Transform3D& _transform,int32_t id,int32_t arg0,int32_t arg1,int32_t arg2,uint16_t layers);
    void packed_scene_set_bind_items(int32_t packed_scene_item_id,int32_t bind0,int32_t bind1);

    int light_add(Object* light_node,const Transform3D transform,uint16_t layers);
    int decal_add(int32_t decal_id,const Transform3D transform,int32_t render_layer,uint16_t variation_layer);

    void set_baker_path(const String& input);
    String get_baker_path();
    #ifdef DEBUG_ENABLED
    Dictionary get_used_mesh_ids() const;
    Ref<ArrayMesh> get_joined_mesh(bool for_triangle_mesh,bool best_mesh_quality) const;
    #endif


    void start_test(){        
    }

    void _set_data(const Dictionary& data);
    Dictionary _get_data() const;
};


_FORCE_INLINE_ int16_t MHlod::Item::get_physics_body(){
    switch (type)
    {
        case Type::COLLISION:
            return collision.get_body_id();
        case Type::COLLISION_COMPLEX:
            return collision_complex.get_body_id();
    }
    return -1;
}

_FORCE_INLINE_ MHlod::ItemResource MHlod::Item::get_res_and_add_user(){
    user_count++;
    if(user_count==1){
        switch (type)
        {
        case Type::MESH:
            return ItemResource(mesh.load());
            break;
        case Type::COLLISION:
            return ItemResource(collision.load());
            break;
        case Type::COLLISION_COMPLEX:
            return ItemResource(collision_complex.load());
            break;
        case Type::LIGHT:
            return ItemResource(light.load());
            break;
        case Type::DECAL:
            return ItemResource(decal.load());
            break;
        case Type::PACKED_SCENE:
            return ItemResource(packed_scene.load());
            break;
        default:
            ERR_FAIL_V_MSG(RID(),"Undefine Item Type!");
            break;
        }
    } else {
        switch (type)
        {
        case Type::MESH:
            return ItemResource(mesh.get_mesh());
            break;
        case Type::COLLISION:
            return ItemResource(collision.get_shape());
            break;
        case Type::COLLISION_COMPLEX:
            return ItemResource(collision_complex.get_shape());
            break;
        case Type::LIGHT:
            return ItemResource(light.get_light());
        case Type::DECAL:
            return ItemResource(decal.get_decal());
            break;
        case Type::PACKED_SCENE:
            return ItemResource(packed_scene.get_packed_scene());
            break;
        default:
            ERR_FAIL_V_MSG(RID(),"Undefine Item Type!");
            break;
        }
    }
    return RID();
}

_FORCE_INLINE_ void MHlod::Item::remove_user(){
    ERR_FAIL_COND(user_count==0);
    user_count--;
    if(user_count==0){
        switch (type)
        {
        case Type::MESH:
            mesh.unload();
            break;
        case Type::COLLISION:
            collision.unload();
            break;
        case Type::COLLISION_COMPLEX:
            collision_complex.unload();
            break;
        case Type::LIGHT:
            light.unload();
            break;
        case Type::DECAL:
            decal.unload();
            break;
        default:
            ERR_FAIL_MSG("Undefine Item Type!"); 
            break;
        }
    }
}

_FORCE_INLINE_ MHlod::PhysicBodyInfo& MHlod::get_physic_body(int16_t id){
    if(physic_bodies.has(id)){
        return *physic_bodies.getptr(id);
    }
    if(unlikely(physic_space==0)){
        if(!physic_bodies.has(-2)){
            physic_bodies.insert(-2,PhysicBodyInfo(RID()));
        }
        ERR_FAIL_V_MSG(*physic_bodies.getptr(-2),"Invalid physic space");
    }
    RID space_rid;
    memcpy(&space_rid,&physic_space,sizeof(physic_space));
    if(id==-1){
        RID r = PhysicsServer3D::get_singleton()->body_create();
        PhysicsServer3D::get_singleton()->body_set_mode(r,PhysicsServer3D::BodyMode::BODY_MODE_STATIC);
        PhysicsServer3D::get_singleton()->body_set_space(r,space_rid);
        MHlod::PhysicBodyInfo p(r);
        physic_bodies.insert(id,p);
        return *physic_bodies.getptr(id);
    }
    String spath = M_GET_PHYSIC_SETTING_PATH(id);
    Ref<MHlodCollisionSetting> setting = RL->load(spath);
    ERR_FAIL_COND_V_MSG(setting.is_null(),*physic_bodies.getptr(-1),"Physic Setting does not load: "+spath);
    RID r = PhysicsServer3D::get_singleton()->body_create();
    PhysicsServer3D::get_singleton()->body_set_mode(r,PhysicsServer3D::BodyMode::BODY_MODE_STATIC);
    PhysicsServer3D::get_singleton()->body_set_space(r,space_rid);
    PhysicsServer3D::get_singleton()->body_set_collision_layer(r,setting->collision_layer);
    PhysicsServer3D::get_singleton()->body_set_collision_mask(r,setting->collision_mask);
    if(setting->physics_material.is_valid()){
        float friction = setting->physics_material->is_rough() ? - setting->physics_material->get_friction() : setting->physics_material->get_friction();
        float bounce = setting->physics_material->is_absorbent() ? - setting->physics_material->get_bounce() : setting->physics_material->get_bounce();
        PhysicsServer3D::get_singleton()->body_set_param(r,PhysicsServer3D::BODY_PARAM_BOUNCE,bounce);
        PhysicsServer3D::get_singleton()->body_set_param(r,PhysicsServer3D::BODY_PARAM_FRICTION,friction);
    }
    PhysicsServer3D::get_singleton()->body_set_constant_force(r,setting->constant_linear_velocity);
    PhysicsServer3D::get_singleton()->body_set_constant_torque(r,setting->constant_angular_velocity);
    MHlod::PhysicBodyInfo p(r);
    physic_bodies.insert(id,p);
    physic_bodies.insert(id,r);
    return *physic_bodies.getptr(id);
}

_FORCE_INLINE_ void MHlod::clear_physic_body(){
    for(HashMap<int16_t,PhysicBodyInfo>::Iterator it=physic_bodies.begin();it!=physic_bodies.end();++it){
        PhysicsServer3D::get_singleton()->free_rid(it->value.rid);
    }
    physic_bodies.clear();
}

VARIANT_ENUM_CAST(MHlod::Type);
VARIANT_ENUM_CAST(MHlod::GIMode);
#endif