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
    
    enum Type : uint8_t {NONE,MESH,COLLISION,LIGHT};
    struct Item
    {
        friend MHlod;
        Type type = NONE; // 0
        int8_t lod = -1; // 1
        uint16_t item_layers = 0;
        int32_t transform_index = -1; // Same as unique id for each Item with different LOD
        int32_t user_count = 0;
        union {
            MHLodItemMesh mesh;
            MHLodItemCollision collision;
            MHLodItemLight light;
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
        
        _FORCE_INLINE_ RID get_rid_and_add_user();
        _FORCE_INLINE_ void remove_user();

        void set_data(const Dictionary& d);
        Dictionary get_data() const;
    };
    private:
    // -1 is default static body any invalid id use default body
    // -2 is invalid static body
    static inline HashMap<int,PhysicBodyInfo> physic_bodies;


    /* Item List structure
        [itemA_lod0,itemA_lod1,itemA_lod2, .... , itemB_lod0,itemB_lod1,itemB_lod2]
        the start index (in this case index of itemA_lod0) is the id of that item
        one LOD can be droped if it is a duplicate Base on this if item LOD does not exist we pick the last existing one
        Only two neghbor similar lod can be detected
    */
    public:
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
    static _FORCE_INLINE_ MHlod::PhysicBodyInfo& get_physic_body(int id);

    void set_join_at_lod(int input);
    int get_join_at_lod();
    int get_sub_hlod_size_rec();
    void add_sub_hlod(const Transform3D& transform,Ref<MHlod> hlod,uint16_t scene_layers);
    int add_mesh_item(const Transform3D& transform,const PackedInt64Array& mesh,const PackedInt32Array& material,const PackedByteArray& shadow_settings,const PackedByteArray& gi_modes,int32_t render_layers,int32_t hlod_layers);
    Dictionary get_mesh_item(int item_id);
    PackedInt32Array get_mesh_items_ids() const;
    int get_last_lod_with_mesh() const;

    void insert_item_in_lod_table(int item_id,int lod);
    Array get_lod_table();
    void clear();


    /// Physics
    int shape_add_sphere(const Transform3D& _transform,float radius,int body_id=-1);
    int shape_add_box(const Transform3D& _transform,const Vector3& size,int body_id=-1);
    int shape_add_capsule(const Transform3D& _transform,float radius,float height,int body_id=-1);
    int shape_add_cylinder(const Transform3D& _transform,float radius,float height,int body_id=-1);

    int light_add(Object* light_node,const Transform3D transform);

    void set_baker_path(const String& input);
    String get_baker_path();
    #ifdef DEBUG_ENABLED
    Dictionary get_used_mesh_ids() const;
    #endif


    void start_test(){
        MHLodItemLight l = item_list[61].light;
        UtilityFunctions::print("energy ",l.energy);
        UtilityFunctions::print("light_indirect_energy ",l.light_indirect_energy);
        UtilityFunctions::print("light_volumetric_fog_energy ",l.light_volumetric_fog_energy);
        UtilityFunctions::print("size ",l.size);
        UtilityFunctions::print("negetive ",l.negetive);
        UtilityFunctions::print("specular ",l.specular);
        UtilityFunctions::print("range ",l.range);
        UtilityFunctions::print("attenuation ",l.attenuation);
        UtilityFunctions::print("shadow_mode ",l.shadow_mode);

        return;
        UtilityFunctions::print("size of light ",sizeof(MHLodItemLight));
        UtilityFunctions::print("so of MHLodItemMesh  ",sizeof(MHLodItemMesh));
        UtilityFunctions::print("so of MHLodItemCollision  ",sizeof(MHLodItemCollision));
        UtilityFunctions::print("so of Item  ",sizeof(Item));
    }

    void _set_data(const Dictionary& data);
    Dictionary _get_data() const;
};


_FORCE_INLINE_ RID MHlod::Item::get_rid_and_add_user(){
    user_count++;
    if(user_count==1){
        switch (type)
        {
        case Type::MESH:
            return mesh.load();
            break;
        case Type::COLLISION:
            return collision.load();
            break;
        case Type::LIGHT:
            return light.load();
            break;
        default:
            ERR_FAIL_V_MSG(RID(),"Undefine Item Type!");
            break;
        }
    } else {
        switch (type)
        {
        case Type::MESH:
            return mesh.get_mesh();
            break;
        case Type::COLLISION:
            return collision.get_shape();
            break;
        case Type::LIGHT:
            return light.get_light();
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
        case Type::LIGHT:
            light.unload();
            break;
        default:
            ERR_FAIL_MSG("Undefine Item Type!"); 
            break;
        }
    }
}

_FORCE_INLINE_ MHlod::PhysicBodyInfo& MHlod::get_physic_body(int id){
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
    String spath = M_GET_MESH_PATH(id);
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
#endif