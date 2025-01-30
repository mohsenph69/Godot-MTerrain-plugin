#ifndef __MHLODITEM__
#define __MHLODITEM__

#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/classes/material.hpp>
#include <godot_cpp/classes/geometry_instance3d.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/classes/shape3d.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/templates/vmap.hpp>

#include "mmesh.h"
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

#define RL ResourceLoader::get_singleton()
using namespace godot;

class MHlod;

struct MHLodItemMesh {
    uint8_t shadow_setting;
    uint8_t gi_mode;
    int8_t material_id;
    int32_t render_layers;
    int32_t mesh_id;
    Ref<MMesh> mesh;
    //Vector<Material> surface_material;

    MHLodItemMesh()=default;
    ~MHLodItemMesh()=default;
    _FORCE_INLINE_ bool has_material_ovveride(){
        return mesh.is_valid() && mesh->has_material_override() && material_id >= 0;
    }
    _FORCE_INLINE_ RID load(){
        if(mesh.is_null()){
            mesh = RL->load(M_GET_MESH_PATH(mesh_id));
        }
        if(has_material_ovveride()){
            mesh->add_user(material_id);
        }
        if(mesh.is_valid()){
            return mesh->get_mesh_rid();
        }
        return RID();
    }
    _FORCE_INLINE_ void unload(){
        if(has_material_ovveride()){
            mesh->remove_user(material_id);
        }
        mesh.unref();
    }
    _FORCE_INLINE_ RID get_mesh() const{
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
    _FORCE_INLINE_ void set_data(const PackedByteArray& d){
        ERR_FAIL_COND(d.size()!=14);
        shadow_setting = d[0];
        gi_mode = d[1];
        material_id = d.decode_s32(2);
        render_layers = d.decode_s32(6);
        mesh_id = d.decode_s32(10);
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
    int32_t static_body = -1;
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
    _FORCE_INLINE_ void set_body_id(const int body_id){
        static_body = body_id;
    }
    _FORCE_INLINE_ int get_body_id() const{
        return static_body;
    }
    _FORCE_INLINE_ RID load(){
        if(shapes_list.has(param)){
            shapes_list.getptr(param)->user_count++;
            return shapes_list[param].rid;
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
            ERR_FAIL_V_MSG(RID(),"Invalid shape type");
        }
        shapes_list.insert(param,ShapeData(shape));
        return shape;
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
    _FORCE_INLINE_ void set_data(const PackedByteArray& d){
        ERR_FAIL_COND(d.size()!=get_data_size());
        param.param_1 = d.decode_float(0);
        param.param_2 = d.decode_float(4);
        param.param_3 = d.decode_float(8);
        param.type = (Type)d[16];
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
    MByteFloat<false,4> spot_angle;
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

    _FORCE_INLINE_ RID load(){
        if(lights_list.has(this)){
            WARN_PRINT("Loading lights but exist already!");
            return lights_list[this];
        }
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
            ERR_FAIL_V_MSG(RID(),"Unkown light type "+itos((int)type));
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
        return light;
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

    _FORCE_INLINE_ void set_data(const PackedByteArray& d){
        ERR_FAIL_COND(d.size()==sizeof(MHLodItemLight));
        memcpy(this,d.ptr(),sizeof(MHLodItemLight));
    }

    _FORCE_INLINE_ PackedByteArray get_data() const{
        PackedByteArray d;
        d.resize(sizeof(MHLodItemLight));
        memcpy(d.ptrw(),this,sizeof(MHLodItemLight));
        return d;
    }
};
#endif