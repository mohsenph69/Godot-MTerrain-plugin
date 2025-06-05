#ifndef __MCURVEINSTANCE
#define __MCURVEINSTANCE

#include <godot_cpp/classes/worker_thread_pool.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/packed_scene.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/classes/random_number_generator.hpp>
#include <godot_cpp/classes/shape3d.hpp>
#include <godot_cpp/classes/physics_material.hpp>
#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/classes/physics_server3d.hpp>

#include "mpath.h"
#include "mcurve.h"
#include "../octmesh/mmesh_lod.h"
#include "../util/mbyte_float.h"
//#include "../utility/mnode.h"

#include <mutex>

#define M_CURVE_CONNECTION_INSTANCE_COUNT 4
#define M_CURVE_ELEMENT_COUNT 16
#define M_CURVE_INSTANCE_EPSILON 0.001

using namespace godot;

class MCurveInstance;

class MCurveInstanceElement : public Resource {
    friend MCurveInstance;
    GDCLASS(MCurveInstanceElement,Resource);
    private:
    static constexpr int transform_count = 30;
    bool middle = false;
    bool include_end = false;
    bool mirror = false;
    bool mirror_rotation = false;
    bool curve_align = true;
    int8_t shape_lod_cutoff = 2;
    float interval = 2.0;
    int seed = 101;
    Vector3 offset  = Vector3(0,0,0);
    Vector3 rotation = Vector3(0,0,0);
    Vector3 scale = Vector3(1,1,1);
    // pos rand
    Vector3 rand_offset_start = Vector3(0,0,0);
    Vector3 rand_offset_end = Vector3(0,0,0);
    Vector3 rand_rotation_start = Vector3(0,0,0);
    Vector3 rand_rotation_end = Vector3(0,0,0);
    Vector3 rand_scale_start = Vector3(1,1,1);
    Vector3 rand_scale_end = Vector3(1,1,1);
    float rand_uniform_scale_start = 1.0f;
    float rand_uniform_scale_end = 1.0f;
    Ref<MMeshLod> mesh;
    Ref<Shape3D> shape;
    Vector3 shape_local_position;
    Basis shape_local_basis;
    // Contain basis and offset including randomness and non-randomness like offset combined
    Basis bases[transform_count];
    Vector3 offsets[transform_count]; // generated in _generate_transforms()
    float random_numbers[transform_count]; // this also will be generated in _generate_transforms()
    ///////////// Render Setting
    RenderingServer::ShadowCastingSetting shadow_setting = RenderingServer::ShadowCastingSetting::SHADOW_CASTING_SETTING_ON;
    uint32_t render_layers = 1;
    ///////////// Physics Settings
    Ref<PhysicsMaterial> physics_material;
    int32_t collision_layer=1;
    int32_t collision_mask=1;
    //////////////////////////////////
    void _generate_transforms();
    protected:
    static void _bind_methods();
    public:
    inline Transform3D modify_transform(const Transform3D& t, int index) const{
        index = index%transform_count;
        Vector3 __offset = offsets[index];
        Vector3 origin = t.origin + t.basis.get_column(0)*__offset.x + t.basis.get_column(1)*__offset.y + t.basis.get_column(2)*__offset.z;
        if(curve_align){
            return Transform3D(t.basis*bases[index],origin);
        }
        return Transform3D(bases[index],origin);
    }

    inline Transform3D modify_transform_mirror(const Transform3D& t, int index) const{
        index = (index+transform_count*2)%transform_count;
        Vector3 __offset = offsets[index];
        __offset.z *= -1.0;
        Vector3 origin = t.origin + t.basis.get_column(0)*__offset.x + t.basis.get_column(1)*__offset.y + t.basis.get_column(2)*__offset.z;
        Basis b = mirror_rotation ? bases[index].rotated(Vector3(0,1,0),3.14159265359) : bases[index];
        if(curve_align){
            return Transform3D(t.basis*b,origin);
        }
        return Transform3D(b,origin);
    }

    inline Transform3D modify_transform_shape(const Transform3D& item_transform) const{
        return Transform3D(item_transform.basis*shape_local_basis,shape_local_position+item_transform.origin);
    }

    inline Transform3D modify_transform_mirror_shape(const Transform3D& item_transform_mirror) const{
        return Transform3D(item_transform_mirror.basis*shape_local_basis,shape_local_position+item_transform_mirror.origin);
    }

    inline bool index_exist(int index,float remove_possibility) const {
        float rnum = random_numbers[index%transform_count];
        return remove_possibility < rnum;
    }

    inline bool index_exist_mirror(int index,float remove_possibility) const {
        float rnum = random_numbers[(index+21)%transform_count];
        return remove_possibility < rnum;
    }

    inline RID get_mesh_lod(int lod) const {
        if(mesh.is_null()){
            return RID();
        }
        TypedArray<Mesh> meshes = mesh->get_meshes();
        if(lod >= meshes.size()){
            lod = meshes.size() - 1;
        }
        Ref<Mesh> m = meshes[lod];
        if(m.is_null()){
            return RID();
        }
        return m->get_rid();
    }

    inline RID get_shape_rid() const{
        if(shape.is_null()){
            return RID();
        }
        return shape->get_rid();
    }

    void emit_elements_changed();

    void set_element_name(const String& input);
    String get_element_name();

    void set_mesh(Ref<MMeshLod> input);
    Ref<MMeshLod> get_mesh() const;

    void set_shape(Ref<Shape3D> input);
    Ref<Shape3D> get_shape() const;

    void set_shape_lod_cutoff(int8_t input);
    int8_t get_shape_lod_cutoff() const;

    void set_seed(int input);
    int get_seed() const;

    void set_middle(bool input);
    bool get_middle() const;

    void set_include_end(bool input);
    bool get_include_end() const;

    void set_mirror_rotation(bool input);
    bool get_mirror_rotation() const;

    void set_mirror(bool input);
    bool get_mirror() const;

    void set_curve_align(bool input);
    bool get_curve_align() const;

    void set_interval(float input);
    float get_interval() const;

    void set_offset(const Vector3& input);
    Vector3 get_offset() const;

    void set_rotation(const Vector3& input);
    Vector3 get_rotation() const;

    void set_scale(const Vector3& input);
    Vector3 get_scale() const;

    // rand
    void set_rand_offset_start(const Vector3& input);
    Vector3 get_rand_offset_start() const;

    void set_rand_offset_end(const Vector3& input);
    Vector3 get_rand_offset_end() const;

    void set_rand_rotation_start(const Vector3& input);
    Vector3 get_rand_rotation_start() const;

    void set_rand_rotation_end(const Vector3& input);
    Vector3 get_rand_rotation_end() const;

    void set_rand_scale_start(const Vector3& input);
    Vector3 get_rand_scale_start() const;

    void set_rand_scale_end(const Vector3& input);
    Vector3 get_rand_scale_end() const;

    void set_rand_uniform_scale_start(float input);
    float get_rand_uniform_scale_start() const;

    void set_rand_uniform_scale_end(float input);
    float get_rand_uniform_scale_end() const;

    void set_shape_local_position(const Vector3& input);
    Vector3 get_shape_local_position() const;

    void set_shape_local_basis(const Basis& input);
    Basis get_shape_local_basis() const;

    /////////// Render
    void set_shadow_setting(RenderingServer::ShadowCastingSetting input);
    RenderingServer::ShadowCastingSetting get_shadow_setting();
    void set_render_layers(uint32_t input);
    uint32_t get_render_layers() const;
    /////////// Physics
    void set_physics_material(Ref<PhysicsMaterial> input);
    Ref<PhysicsMaterial> get_physics_material() const;

    void set_collision_layer(uint32_t input);
    uint32_t get_collision_layer() const;

    void set_collision_mask(uint32_t input);
    uint32_t get_collision_mask() const;
};

class MCurveInstanceOverride : public Resource {
    friend MCurveInstance;
    GDCLASS(MCurveInstanceOverride,Resource);
    protected:
    static void _bind_methods();
    public:
    /// EXCLUDE is a special case flag which will be same for all instance_index
    enum FLAG {
        // EXCLUDE = 1 << 0, // not part of enum set by set_exclude and get exclude
        REVERSE_OFFSET = 1 << 1
        // 6 more can be added before data structure change
    };
    struct OverrideData
    {
        int8_t element_ovveride[M_CURVE_CONNECTION_INSTANCE_COUNT];
        MByteFloat<false,1> start_offset[M_CURVE_CONNECTION_INSTANCE_COUNT];
        MByteFloat<false,1> end_offset[M_CURVE_CONNECTION_INSTANCE_COUNT];
        MByteFloat<false,1> random_remove[M_CURVE_CONNECTION_INSTANCE_COUNT];
        uint8_t flags[M_CURVE_CONNECTION_INSTANCE_COUNT];
        OverrideData();
        inline bool has_any_element() const {
            for(int i=0; i < M_CURVE_CONNECTION_INSTANCE_COUNT ; i++){
                if(element_ovveride[i]>=0){
                    return true;
                }
            }
            return false;
        }
        inline void set_exclude(bool value){
            uint8_t ex_flag = 1;
            if(value){
                flags[0] |= ex_flag;
            } else {
                flags[0] &= ~ex_flag;
            }
        }
        inline bool get_exclude() const {
            uint8_t ex_flag = 1;
            return (flags[0] & ex_flag) != 0;
        }
        /// return true and usually use for cases which tell us if we have any override for conn_id
        /// so we should keep our override if this return false in many cases override data will be removed
        inline bool has_any_override() const {
            // any none default override
            if(has_any_element() || get_exclude()){
                return true;
            }
            return false;
        }
        inline int get_instance_index(int element_index) const {
            for(int i=0; i < M_CURVE_CONNECTION_INSTANCE_COUNT; i++){
                if(element_ovveride[i]==element_index){
                    return i;
                }
            }
            return -1;
        }
        inline void set_flag(int instance_index,FLAG flag,bool value){
            if(value){
                flags[instance_index] |= flag;
            } else {
                flags[instance_index] &= ~flag;
            }
        }
        inline bool get_flag(int instance_index,FLAG flag) const {
            return (flags[instance_index] & flag) != 0;
        }
    };
    
    private:
    HashMap<int64_t,OverrideData> data;
    public:
    void set_exclude(int64_t conn_id,bool value);
    bool get_exclude(int64_t conn_id) const;

    void set_flag(int64_t conn_id,int element_index,FLAG flag,bool value);
    bool get_flag(int64_t conn_id,int element_index,FLAG flag) const;
    void emit_connection_changed(int64_t conn_id);
    int get_conn_element_capacity(int64_t conn_id) const;
    void add_element(int64_t conn_id,int element_index);
    void remove_element(int64_t conn_id,int element_index);
    PackedByteArray get_elements(int64_t conn_id) const;
    bool has_element(int64_t conn_id,int8_t element_index) const;
    void clear_to_default(int64_t conn_id);
    bool has_override(int64_t conn_id) const;
    // set override setting
    void set_start_offset(int64_t conn_id,int element_index,float val);
    float get_start_offset(int64_t conn_id,int element_index) const;
    void set_end_offset(int64_t conn_id,int element_index,float val);
    float get_end_offset(int64_t conn_id,int element_index) const;
    void set_rand_remove(int64_t conn_id,int element_index,float val);
    float get_rand_remove(int64_t conn_id,int element_index) const;
    // Data
    void set_data(const PackedByteArray& input);
    PackedByteArray get_data() const;
};

VARIANT_ENUM_CAST(MCurveInstanceOverride::FLAG);

class MCurveInstance : public Node {
    GDCLASS(MCurveInstance, Node);
    /**
     * max number of connection multimesh instance that can have
     * instance index known are 0,1, ... , connection_instance_count - 1
     * each curve connection can have multiple instance which we id with instance index
     */
    using OverrideData = MCurveInstanceOverride::OverrideData;
    protected:
    static void _bind_methods();

    private:    
    struct Instance
    {
        Instance(){
        }
        ~Instance(){
        }
        struct Scene
        {
            int row;
            //MNode* node;
        };
        
        public:
        int count = 0;
        public:
        RID mesh_rid; // curently bound mesh
        RID instance;
        RID multimesh;
        // physics shape
        RID shape;
        RID body;
        
        inline void ensure_render_instance_exist(RID scenario,const uint32_t layers,const RenderingServer::ShadowCastingSetting shadow_setting){
            if(!instance.is_valid()){
                ERR_FAIL_COND_MSG(multimesh.is_valid(),"instance and multimesh should create and destroy together");
                instance = RenderingServer::get_singleton()->instance_create();
                RenderingServer::get_singleton()->instance_set_scenario(instance,scenario);
                multimesh = RenderingServer::get_singleton()->multimesh_create();
                RenderingServer::get_singleton()->instance_set_base(instance,multimesh);
                RenderingServer::get_singleton()->instance_set_layer_mask(instance,layers);
                RenderingServer::get_singleton()->instance_geometry_set_cast_shadows_setting(instance,shadow_setting);
            }
        }

        inline void ensure_physics_body_exist(RID space,uint32_t layer,uint32_t mask,Ref<PhysicsMaterial> physics_material){
            if(!body.is_valid()){
                body = PhysicsServer3D::get_singleton()->body_create();
                PhysicsServer3D::get_singleton()->body_set_mode(body,PhysicsServer3D::BodyMode::BODY_MODE_STATIC);
                PhysicsServer3D::get_singleton()->body_set_space(body,space);
                PhysicsServer3D::get_singleton()->body_set_collision_layer(body,layer);
                PhysicsServer3D::get_singleton()->body_set_collision_mask(body,mask);
                if(physics_material.is_valid()){
                    float friction = physics_material->is_rough() ? - physics_material->get_friction() : physics_material->get_friction();
                    float bounce = physics_material->is_absorbent() ? - physics_material->get_bounce() : physics_material->get_bounce();
                    PhysicsServer3D::get_singleton()->body_set_param(body,PhysicsServer3D::BODY_PARAM_BOUNCE,bounce);
                    PhysicsServer3D::get_singleton()->body_set_param(body,PhysicsServer3D::BODY_PARAM_FRICTION,friction);
                }
            }
        }

        inline void remove_physics() {
            if(body.is_valid()){
                PhysicsServer3D::get_singleton()->free_rid(body);
                body = RID();
                shape = RID();
            }
        }

        inline void remove_render_instance() {
            if(multimesh.is_valid()){
                RenderingServer::get_singleton()->free_rid(multimesh);
                multimesh = RID();
            }
            if(instance.is_valid()){
                RenderingServer::get_singleton()->free_rid(instance);
                instance = RID();
            }
        }
    };

    struct Instances {
        Instance instances[M_CURVE_CONNECTION_INSTANCE_COUNT];
        inline Instance& operator[](const size_t index){
            return instances[index];
        }
        inline bool has_valid_instance() const {
            for(int i=0; i < M_CURVE_CONNECTION_INSTANCE_COUNT; i++){
                if(instances[i].multimesh.is_valid() || instances[i].instance.is_valid() || instances[i].body.is_valid()){
                    return true;
                }
            }
            return false;
        }
    };

    bool is_thread_updating = false;
    int default_element[M_CURVE_CONNECTION_INSTANCE_COUNT];
    int32_t curve_user_id;
    WorkerThreadPool::TaskID thread_task_id;
    // Don't access directrly use get_override_data function
    Ref<MCurveInstanceOverride> override_data;
    Ref<MCurveInstanceElement> elements[M_CURVE_ELEMENT_COUNT];
    MPath* path=nullptr;
    Ref<MCurve> curve;
    
    HashMap<int64_t,MCurveInstance::Instances> curve_instance_instances;
    _FORCE_INLINE_ void _set_multimesh_buffer(PackedFloat32Array& multimesh_buffer,const Transform3D& t,int& buffer_index) const;
    // return override data if exist or default override data if not exist
    _FORCE_INLINE_ OverrideData get_override_data(int64_t conn_id) const;
    public:
    std::recursive_mutex update_mutex;
    MCurveInstance();
    ~MCurveInstance();
    void _on_connections_updated();
    static void thread_update(void* input);
    /// Decide what element should be added and calling _generate_connection_element
    void _generate_connection(const MCurve::ConnUpdateInfo& update_info,bool immediate_update=false);
    void _update_visibilty();
    void _connection_force_update(int64_t conn_id);
    void _connection_remove(int64_t conn_id);
    void _recreate();
    // in case instance_index=-1 all instance will be removed
    void _remove_instance(int64_t conn_id,int instance_index=-1,bool rm_curve_instance_instances=true);
    void _remove_all_instance();
    void set_override(Ref<MCurveInstanceOverride> input);
    Ref<MCurveInstanceOverride> get_override() const;
    void set_default_element(int instance_index,int input);
    int get_default_element(int instance_index) const;


    void _on_curve_changed();
    void _process_tick();
    void _notification(int p_what);
    PackedStringArray _get_configuration_warnings() const;

    void set_element(int instance_index,Ref<MCurveInstanceElement> input);
    Ref<MCurveInstanceElement> get_element(int instance_index) const;

    static int get_instance_count();
    static int get_element_count();

    void _set_dummy(bool input){}
    bool _get_dummy()const{ return true;}
};

void MCurveInstance::_set_multimesh_buffer(PackedFloat32Array& multimesh_buffer,const Transform3D& t,int& buffer_index) const{
    multimesh_buffer.resize(multimesh_buffer.size()+12);
    multimesh_buffer.set(buffer_index,t.basis[0][0]);
    multimesh_buffer.set(buffer_index+1,t.basis[0][1]);
    multimesh_buffer.set(buffer_index+2,t.basis[0][2]);
    multimesh_buffer.set(buffer_index+3,t.origin[0]);

    multimesh_buffer.set(buffer_index+4,t.basis[1][0]);
    multimesh_buffer.set(buffer_index+5,t.basis[1][1]);
    multimesh_buffer.set(buffer_index+6,t.basis[1][2]);
    multimesh_buffer.set(buffer_index+7,t.origin[1]);

    multimesh_buffer.set(buffer_index+8,t.basis[2][0]);
    multimesh_buffer.set(buffer_index+9,t.basis[2][1]);
    multimesh_buffer.set(buffer_index+10,t.basis[2][2]);
    multimesh_buffer.set(buffer_index+11,t.origin[2]);
    buffer_index += 12;
}

MCurveInstance::OverrideData MCurveInstance::get_override_data(int64_t conn_id) const{
    OverrideData ov;
    if(override_data.is_valid()){
        HashMap<int64_t,OverrideData>::ConstIterator it = override_data->data.find(conn_id);
        if(it!=override_data->data.end()){
            ov = it->value;
        }
    }
    if(!ov.has_any_element()){
        for(int i=0; i < M_CURVE_CONNECTION_INSTANCE_COUNT; i++){
            // Avoiding duplicate
            bool has_element = false;
            for(int j=0; j < i; j++){
                if(default_element[i] == default_element[j]){
                    has_element = true;
                    break;
                }
            }
            if(has_element){
                ov.element_ovveride[i] = -1;
            } else {
                ov.element_ovveride[i] = default_element[i];
            }
        }
    }
    return ov;
}

#endif