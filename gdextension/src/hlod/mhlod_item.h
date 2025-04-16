#ifndef __MHLODITEM__
#define __MHLODITEM__

#include <godot_cpp/classes/packed_scene.hpp>
#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/classes/material.hpp>
#include <godot_cpp/classes/geometry_instance3d.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/classes/shape3d.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/templates/vmap.hpp>

#include "mmesh.h"
#include "mdecal.h"
#include "../util/mbyte_float.h"

#include <godot_cpp/variant/utility_functions.hpp>

#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/physics_server3d.hpp>
#include <godot_cpp/classes/rendering_server.hpp>

#define RS RenderingServer::get_singleton()


#define M_ASSET_ROOT_DIR "res://massets/"
#define M_MESH_ROOT_DIR "res://massets/meshes/"
#define M_PHYSICS_SETTINGS_DIR "res://massets/collision_setting/"
#define M_GET_MESH_PATH(mesh_id) String(M_MESH_ROOT_DIR) + itos(mesh_id) + String(".res")
#define M_GET_PHYSIC_SETTING_PATH(id) String(M_PHYSICS_SETTINGS_DIR) + itos(id) + String(".res")
#define M_SHAPE_PARAM_ROUND(num) std::round(num * 100.0f) / 100.0f

#define M_PACKED_SCENE_BIND_COUNT 2
#define M_PACKED_SCENE_ARG_COUNT 3

#define M_COLLISION_ROOT_DIR "res://massets/collissions/"
#define M_GET_COLLISION_PATH(id) String(M_COLLISION_ROOT_DIR) + itos(id) + String(".res")

#define M_PACKEDSCENE_ROOT_DIR "res://massets/packed_scenes/"
#define M_GET_PACKEDSCENE_PATH(id) String(M_PACKEDSCENE_ROOT_DIR) + itos(id) + String(".tscn")

#define M_DECAL_ROOT_DIR "res://massets/decals/"
#define M_GET_DECAL_PATH(id) String(M_DECAL_ROOT_DIR) + itos(id) + String(".res")

#define M_HLOD_ROOT_DIR "res://massets/hlod/"
#define M_GET_HLODL_PATH(id) String(M_HLOD_ROOT_DIR) + itos(id) + String(".res")

#define RL ResourceLoader::get_singleton()
using namespace godot;

class MHlod;

struct MHLodItemMesh {
    uint8_t shadow_setting;
    uint8_t gi_mode;
    int8_t material_id;
    int32_t render_layers;
    int32_t mesh_id=-1;
    Ref<MMesh> mesh;
    //Vector<Material> surface_material;

    MHLodItemMesh()=default;
    ~MHLodItemMesh()=default;
    _FORCE_INLINE_ bool has_material_ovveride(){
        return mesh.is_valid() && mesh->has_material_override() && material_id >= 0;
    }
    _FORCE_INLINE_ bool has_cache() const {
        return mesh.is_valid() || RL->has_cached(M_GET_MESH_PATH(mesh_id));
    }
    _FORCE_INLINE_ void load(){
        ERR_FAIL_COND(mesh_id==-1);
        ERR_FAIL_COND_MSG(mesh.is_valid(),"Mesh valid on load!");
        String mpath = M_GET_MESH_PATH(mesh_id);
        if(RL->has_cached(mpath)){
            mesh = RL->get_cached_ref(mpath);
        } else {
            mesh = RL->load_threaded_request(mpath);
        }
    }
    _FORCE_INLINE_ void unload(){
        if(has_material_ovveride()){
            mesh->remove_user(material_id);
        }
        mesh.unref();
    }
    _FORCE_INLINE_ RID get_mesh() {
        if(mesh.is_valid()){
            return mesh->get_mesh_rid();
        }
        String mpath = M_GET_MESH_PATH(mesh_id);
        ResourceLoader::ThreadLoadStatus ls = RL->load_threaded_get_status(mpath);
        if(ls==ResourceLoader::ThreadLoadStatus::THREAD_LOAD_IN_PROGRESS || ls==ResourceLoader::ThreadLoadStatus::THREAD_LOAD_LOADED){
            mesh = RL->load_threaded_get(mpath);
            if(has_material_ovveride()){
                mesh->add_user(material_id);
            }
        }
        if(mesh.is_null()){
            return RID();
        }
        return mesh->get_mesh_rid();
    }

    _FORCE_INLINE_ void get_material(Vector<RID>& material_rids){
        if(!has_material_ovveride()){
            return;
        }
        mesh->get_materials(material_id,material_rids);
    }
    _FORCE_INLINE_ GeometryInstance3D::ShadowCastingSetting get_shadow_setting(){
        return (GeometryInstance3D::ShadowCastingSetting)shadow_setting;
    }
    _FORCE_INLINE_ GeometryInstance3D::GIMode get_gi_mode(){
        return (GeometryInstance3D::GIMode)gi_mode;
    }
    _FORCE_INLINE_ void set_data(int64_t _mesh,int8_t _material,uint8_t _shadow_setting,uint8_t _gi_mode,int32_t _render_layers){
        mesh_id = _mesh;
        material_id = _material;
        shadow_setting = _shadow_setting;
        gi_mode = _gi_mode;
        render_layers = _render_layers;
    }
    _FORCE_INLINE_ int get_data_size() const{
        return 14; // Total saved size
    }
    _FORCE_INLINE_ void set_data(const PackedByteArray& d,int head){
        ERR_FAIL_COND(d.size()<14+head);
        shadow_setting = d[0+head];
        gi_mode = d[1+head];
        material_id = d.decode_s32(2+head);
        render_layers = d.decode_s32(6+head);
        mesh_id = d.decode_s32(10+head);
    }
    _FORCE_INLINE_ PackedByteArray get_data() const{
        PackedByteArray d;
        d.resize(14);
        d[0] = shadow_setting;
        d[1] = gi_mode;
        d.encode_s32(2,material_id);
        d.encode_s32(6,render_layers);
        d.encode_s32(10,mesh_id);
        return d;
    }
};

struct MHLodItemDecal {
    int32_t decal_id;
    int32_t render_layers;
    Ref<MDecal> decal;
    _FORCE_INLINE_ bool has_cache() const {
        return decal.is_valid() || RL->has_cached(M_GET_DECAL_PATH(decal_id));
    }
    _FORCE_INLINE_ void load(){
        ERR_FAIL_COND_MSG(decal.is_valid(),"Decal valid on load!");
        String dpath = M_GET_DECAL_PATH(decal_id);
        if(RL->has_cached(dpath)){
            decal = RL->get_cached_ref(dpath);
        } else {
            decal = RL->load_threaded_request(dpath);
        }
    }
    _FORCE_INLINE_ RID get_decal(){
        if(decal.is_valid()){
            return decal->get_decal_rid();
        }
        String dpath = M_GET_DECAL_PATH(decal_id);
        ResourceLoader::ThreadLoadStatus ls = RL->load_threaded_get_status(dpath);
        if(ls==ResourceLoader::ThreadLoadStatus::THREAD_LOAD_IN_PROGRESS || ls==ResourceLoader::ThreadLoadStatus::THREAD_LOAD_LOADED){
            decal = RL->load_threaded_get(dpath);
        }
        if(decal.is_valid()){
            return decal->get_decal_rid();
        }
        return RID();
    }
    _FORCE_INLINE_ void unload(){
        if(decal.is_valid()){
            decal.unref();
        }
    }
    _FORCE_INLINE_ void set_data(int32_t _decal_id,int32_t _render_layers){
        render_layers = _render_layers;
        decal_id = _decal_id;
    }
    _FORCE_INLINE_ int get_data_size() const{
        return 8; // Total saved size
    }
    _FORCE_INLINE_ void set_data(const PackedByteArray& d,int head){
        ERR_FAIL_COND(d.size()<8+head);
        decal_id = d.decode_s32(0+head);
        render_layers = d.decode_s32(4+head);
    }
    _FORCE_INLINE_ PackedByteArray get_data() const{
        PackedByteArray out;
        out.resize(8);
        out.encode_s32(0,decal_id);
        out.encode_s32(4,render_layers);
        return out;
    }
};

struct MHLodItemCollision {
    // Enum numbers should match CollisionType in MAssetTable
    enum Type : int8_t {NONE=0,SHPERE=1,CYLINDER=2,CAPSULE=3,BOX=4};
    struct Param
    {
        Type type = NONE;
        float param_1;
        float param_2;
        float param_3;

        static _FORCE_INLINE_ uint32_t hash(const Param &__p) {
            uint32_t hash = 2166136261u;
            hash ^= (uint32_t)__p.type;
            hash <<= 2;
            //hash *= 0x5bd1e995;
            float param_1 = __p.param_1;
            float param_2 = __p.param_2;
            float param_3 = __p.param_3;
            hash ^= *reinterpret_cast<uint32_t*>(&param_1);
            hash = hash << 3;
            hash ^= *reinterpret_cast<uint32_t*>(&param_2);
            hash = hash >> 1;
            hash ^= *reinterpret_cast<uint32_t*>(&param_3);
            return hash;
        }

        static _FORCE_INLINE_ bool compare(const Param &l, const Param &r) {
            return l.param_1==r.param_1 && l.param_2==r.param_2 && l.param_3==r.param_3 && l.type==r.type;
        }
    };
    struct ShapeData
    {
        RID rid;
        int64_t user_count = 1;
        ShapeData()=default;
        _FORCE_INLINE_ ShapeData(RID rid): rid(rid){}
    };
    private:
    int16_t static_body = -1;
    Param param;
    public:
    MHLodItemCollision() = default;
    ~MHLodItemCollision() = default;
    _FORCE_INLINE_ MHLodItemCollision(const Type type){
        param.type = type;
    }
    _FORCE_INLINE_ void set_type(const Type type){
        param.type = type;
    }
    _FORCE_INLINE_ void set_param(const float param_1){
        param.param_1 = M_SHAPE_PARAM_ROUND(param_1);
    }
    _FORCE_INLINE_ void set_param(const float param_1,const float param_2){
        param.param_1 = M_SHAPE_PARAM_ROUND(param_1);
        param.param_2 = M_SHAPE_PARAM_ROUND(param_2);
    }
    _FORCE_INLINE_ void set_param(const float param_1,const float param_2,const float param_3){
        param.param_1 = M_SHAPE_PARAM_ROUND(param_1);
        param.param_2 = M_SHAPE_PARAM_ROUND(param_2);
        param.param_3 = M_SHAPE_PARAM_ROUND(param_3);
    }
    _FORCE_INLINE_ void set_body_id(const int16_t body_id){
        static_body = body_id;
    }
    _FORCE_INLINE_ int get_body_id() const{
        return static_body;
    }
    _FORCE_INLINE_ bool has_cache() const {
        return true;
    }
    _FORCE_INLINE_ void load(){
        if(shapes_list.has(param)){
            shapes_list.getptr(param)->user_count++;
            return;
        }
        RID shape;
        switch (param.type)
        {
        case Type::SHPERE:
            shape = PhysicsServer3D::get_singleton()->sphere_shape_create();
            PhysicsServer3D::get_singleton()->shape_set_data(shape,param.param_1);
            break;
        case Type::BOX:
            shape = PhysicsServer3D::get_singleton()->box_shape_create();
            // in case of box we devided param /2 on insert
            PhysicsServer3D::get_singleton()->shape_set_data(shape,Vector3(param.param_1,param.param_2,param.param_3));
            break;
        case Type::CYLINDER:
            shape = PhysicsServer3D::get_singleton()->cylinder_shape_create();
            {
                Dictionary d;
                d["radius"] = param.param_1;
                d["height"] = param.param_2;
                PhysicsServer3D::get_singleton()->shape_set_data(shape,d);
            }
            break;
        case Type::CAPSULE:
            shape = PhysicsServer3D::get_singleton()->capsule_shape_create();
            {
                Dictionary d;
                d["radius"] = param.param_1;
                d["height"] = param.param_2;
                PhysicsServer3D::get_singleton()->shape_set_data(shape,d);
            }
            break;
        default:
            ERR_FAIL_MSG("Invalid shape type");
        }
        shapes_list.insert(param,ShapeData(shape));
    }
    _FORCE_INLINE_ void unload(){
        if(shapes_list.has(param)){
            shapes_list.getptr(param)->user_count--;
            if(shapes_list.getptr(param)->user_count==0){
                PhysicsServer3D::get_singleton()->free_rid(shapes_list[param].rid);
                shapes_list.erase(param);
            }
        } else {
            ERR_FAIL_MSG("No rid found with param in unload");
        }
    }
    _FORCE_INLINE_ RID get_shape(){
        #ifdef DEBUG_ENABLED
        ERR_FAIL_COND_V(!shapes_list.has(param),RID());
        #endif
        return shapes_list[param].rid;
    }
    /*
    0 -> float -> param1
    4 -> float -> param2
    8 -> float -> param3
    12 -> float -> physics body ID
    16 -> Type
    */
    _FORCE_INLINE_ int get_data_size() const{
        return 17; // Total saved size
    }
    _FORCE_INLINE_ void set_data(const PackedByteArray& d,int head){
        ERR_FAIL_COND(d.size()<get_data_size()+head);
        param.param_1 = d.decode_float(0+head);
        param.param_2 = d.decode_float(4+head);
        param.param_3 = d.decode_float(8+head);
        static_body = d.decode_s32(12+head);
        param.type = (Type)d[16+head];
    }
    _FORCE_INLINE_ PackedByteArray get_data() const{
        PackedByteArray out;
        out.resize(get_data_size());
        out.encode_float(0,param.param_1);
        out.encode_float(4,param.param_2);
        out.encode_float(8,param.param_3);
        out.encode_s32(12,static_body);
        out.set(16,(int8_t)param.type);
        return out;
    }
    private:
    static inline HashMap<Param,ShapeData,Param,Param> shapes_list;
};

struct MHLodItemCollisionComplex {
    int16_t static_body = -1;
    int32_t id = -1;
    Ref<Shape3D> shape;
    _FORCE_INLINE_ bool has_cache() const {
        return shape.is_valid() || RL->has_cached(M_GET_COLLISION_PATH(id));
    }
    _FORCE_INLINE_ void load(){
        ERR_FAIL_COND_MSG(shape.is_valid(),"Load on valid shape MHLodItemCollisionComplex");
        String spath = M_GET_COLLISION_PATH(id);
        if(RL->has_cached(spath)){
            shape = RL->get_cached_ref(spath);
        } else {
            RL->load_threaded_request(spath);
        }
    }
    _FORCE_INLINE_ RID get_shape(){
        if(shape.is_valid()){
            return shape->get_rid();
        }
        String spath = M_GET_COLLISION_PATH(id);
        ResourceLoader::ThreadLoadStatus ls = RL->load_threaded_get_status(spath);
        if(ls==ResourceLoader::ThreadLoadStatus::THREAD_LOAD_IN_PROGRESS || ls==ResourceLoader::ThreadLoadStatus::THREAD_LOAD_LOADED){
            shape = RL->load_threaded_get(spath);
        }
        if(shape.is_valid()){
            return shape->get_rid();
        }
        return RID();
    }
    _FORCE_INLINE_ int16_t get_body_id() const{
        return static_body;
    }
    _FORCE_INLINE_ void unload(){
        shape.unref();
    }
    _FORCE_INLINE_ int get_data_size() const{
        return 6; // Total saved size
    }
    _FORCE_INLINE_ void set_data(const PackedByteArray& data,int head){
        ERR_FAIL_COND(data.size()<6+head);
        id = data.decode_s32(0+head);
        static_body = data.decode_s16(4+head);
    }
    _FORCE_INLINE_ PackedByteArray get_data() const{
        PackedByteArray out;
        out.resize(6);
        out.encode_s32(0,id);
        out.encode_s16(4,static_body);
        return out;
    }
};

struct MHLodItemLight { // No more memebr or increase item size
    //Bellow light rid keeped here to reducing memory size
    // if change this and put it inside struct set_data and get_data should be corrected also
    static inline VMap<MHLodItemLight*,RID> lights_list;
    enum Type {SPOT=0,OMNI=1};
    unsigned int distance_fade_enabled:1; // 1 true 0 false
    unsigned int shadow_enabled:1;
    unsigned int shadow_reverse_cull_face:1;
    unsigned int negetive:1;
    unsigned int shadow_mode:1; // 0 -> SHADOW_DUAL_PARABOLOID, 1 -> SHADOW_CUBE
    Type type:2;
    // Color
    MByteFloat<false,1> red;
    MByteFloat<false,1> green;
    MByteFloat<false,1> blue;
    // params
    MByteFloat<false,64> energy;
    MByteFloat<false,64> light_indirect_energy;
    MByteFloat<false,64> light_volumetric_fog_energy;
    MByteFloat<false,4> size;
    MByteFloat<false,4> specular;
    MByteFloat<false,512> range;
    MByteFloat<false,4> attenuation;
    MByteFloat<false,180> spot_angle;
    MByteFloat<false,4> spot_attenuation;
    //Shadow
    MByteFloat<false,8> shadow_bias;
    MByteFloat<false,8> shadow_normal_bias;
    MByteFloat<false,1> shadow_opacity;
    MByteFloat<false,1> shadow_blur;
    // distance fade
    MByteFloat<false,1024> distance_fade_begin;
    MByteFloat<false,1024> distance_fade_shadow;
    MByteFloat<false,1024> distance_fade_length;
    int16_t cull_mask;
    int16_t layers;
    _FORCE_INLINE_ bool has_cache() const {
        return true;
    }
    _FORCE_INLINE_ void load(){
        ERR_FAIL_COND_MSG(lights_list.has(this),"Load light but exist!");
        RID light;
        switch (type)
        {
        case Type::SPOT:
            light = RS->spot_light_create();
            break;
        case Type::OMNI:
            light = RS->omni_light_create();
            // Only two mode
            RS->light_omni_set_shadow_mode(light,(RenderingServer::LightOmniShadowMode)shadow_mode);
            break;
        default:
            ERR_FAIL_MSG("Unkown light type "+itos((int)type));
            break;
        }
        // color
        RS->light_set_color(light,Color(red.get_float(),green.get_float(),blue.get_float()));
        // cull mask
        RS->light_set_cull_mask(light,cull_mask);
        // booleans
        RS->light_set_shadow(light,(bool)shadow_enabled);
        RS->light_set_reverse_cull_face_mode(light,(bool)shadow_reverse_cull_face);
        RS->light_set_negative(light,(bool)negetive);
        // Params
        RS->light_set_param(light,RenderingServer::LIGHT_PARAM_ENERGY,energy.get_float());
        RS->light_set_param(light,RenderingServer::LIGHT_PARAM_INDIRECT_ENERGY,light_indirect_energy.get_float());
        RS->light_set_param(light,RenderingServer::LIGHT_PARAM_VOLUMETRIC_FOG_ENERGY,light_volumetric_fog_energy.get_float());
        RS->light_set_param(light,RenderingServer::LIGHT_PARAM_SIZE,size.get_float());
        RS->light_set_param(light,RenderingServer::LIGHT_PARAM_SPECULAR,specular.get_float());
        RS->light_set_param(light,RenderingServer::LIGHT_PARAM_RANGE,range.get_float());
        RS->light_set_param(light,RenderingServer::LIGHT_PARAM_ATTENUATION,attenuation.get_float());
        // spot light param
        RS->light_set_param(light,RenderingServer::LIGHT_PARAM_SPOT_ANGLE,spot_angle.get_float());
        RS->light_set_param(light,RenderingServer::LIGHT_PARAM_SPOT_ATTENUATION,spot_attenuation.get_float());
        // shadow
        RS->light_set_param(light,RenderingServer::LIGHT_PARAM_SHADOW_BIAS,shadow_bias.get_float());
        RS->light_set_param(light,RenderingServer::LIGHT_PARAM_SHADOW_NORMAL_BIAS,shadow_normal_bias.get_float());
        RS->light_set_param(light,RenderingServer::LIGHT_PARAM_SHADOW_OPACITY,shadow_opacity.get_float());
        RS->light_set_param(light,RenderingServer::LIGHT_PARAM_SHADOW_BLUR,shadow_blur.get_float());
        // distance fade
        RS->light_set_distance_fade(light,(bool)distance_fade_enabled,distance_fade_begin,distance_fade_shadow,distance_fade_length);
        lights_list.insert(this,light);
    }

    _FORCE_INLINE_ RID get_light(){
        ERR_FAIL_COND_V(!lights_list.has(this),RID());
        return lights_list[this];
    }

    _FORCE_INLINE_ void unload(){
        ERR_FAIL_COND(!lights_list.has(this));
        RS->free_rid(lights_list[this]);
        lights_list.erase(this);
    }
    _FORCE_INLINE_ int get_data_size() const{
        return sizeof(MHLodItemLight); // Total saved size
    }
    _FORCE_INLINE_ void set_data(const PackedByteArray& d,int head){
        ERR_FAIL_COND(d.size()<sizeof(MHLodItemLight)+head);
        memcpy(this,d.ptr()+head,sizeof(MHLodItemLight));
    }

    _FORCE_INLINE_ PackedByteArray get_data() const{
        PackedByteArray d;
        d.resize(sizeof(MHLodItemLight));
        memcpy(d.ptrw(),this,sizeof(MHLodItemLight));
        return d;
    }
};


struct MHLodItemPackedScene {
    static inline VMap<MHLodItemPackedScene*,Ref<PackedScene>> packed_scenes;
    int32_t id = -1;
    int32_t bind_items[M_PACKED_SCENE_BIND_COUNT] = {-1};
    int32_t args[M_PACKED_SCENE_ARG_COUNT];
    _FORCE_INLINE_ bool has_cache() const {
        return RL->has_cached(M_GET_PACKEDSCENE_PATH(id));
    }
    _FORCE_INLINE_ void load(){
        ERR_FAIL_COND_MSG(packed_scenes.has(this),"PackedScene exist on Load!");
        String ppath = M_GET_PACKEDSCENE_PATH(id);
        if(RL->has_cached(ppath)){
            Ref<PackedScene> pscene = RL->get_cached_ref(ppath);
            packed_scenes.insert(this,pscene);
        } else {
            RL->load_threaded_request(ppath);
        }
    }

    _FORCE_INLINE_ Ref<PackedScene> get_packed_scene(){
        if(packed_scenes.has(this)){
            return packed_scenes[this];
        }
        String ppath = M_GET_PACKEDSCENE_PATH(id);
        ResourceLoader::ThreadLoadStatus ls = RL->load_threaded_get_status(ppath);
        if(ls==ResourceLoader::ThreadLoadStatus::THREAD_LOAD_IN_PROGRESS || ls==ResourceLoader::ThreadLoadStatus::THREAD_LOAD_LOADED){
            Ref<PackedScene> pscene = RL->load_threaded_get(ppath);
            packed_scenes.insert(this,pscene);
            return pscene;
        }
        return nullptr;
    }

    _FORCE_INLINE_ void unload(){
        packed_scenes.erase(this);
    }

    _FORCE_INLINE_ int get_data_size() const{
        return sizeof(MHLodItemPackedScene); // Total saved size
    }

    _FORCE_INLINE_ void set_data(const PackedByteArray& d,int head){
        ERR_FAIL_COND(d.size()<sizeof(MHLodItemPackedScene) + head);
        memcpy(this,d.ptr()+head,sizeof(MHLodItemPackedScene));
    }

    _FORCE_INLINE_ PackedByteArray get_data() const{
        PackedByteArray d;
        d.resize(sizeof(MHLodItemPackedScene));
        memcpy(d.ptrw(),this,sizeof(MHLodItemPackedScene));
        return d;
    }
};
#endif