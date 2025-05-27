#ifndef __MCURVEINSTANCE
#define __MCURVEINSTANCE

#include <godot_cpp/classes/worker_thread_pool.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/packed_scene.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/classes/random_number_generator.hpp>

#include "mpath.h"
#include "mcurve.h"
#include "../octmesh/mmesh_lod.h"
#include "../util/mbyte_float.h"
//#include "../utility/mnode.h"

#include <mutex>

#define M_CURVE_CONNECTION_INSTANCE_COUNT 4
#define M_CURVE_ELEMENT_COUNT 10
#define M_CURVE_INSTANCE_EPSILON 0.001

using namespace godot;

class MCurveInstance;

class MCurveInstanceElement : public Resource {
    friend MCurveInstance;
    GDCLASS(MCurveInstanceElement,Resource);
    private:
    static constexpr int transform_count = 30;
    bool mirror = false;
    bool mirror_rotation = false;
    bool middle = false;
    bool include_end = false;
    bool curve_align = true;
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
    // Contain basis and offset including randomness and non-randomness like offset combined
    Basis bases[transform_count];
    Vector3 offsets[transform_count]; // generated in _generate_transforms()
    float random_numbers[transform_count]; // this also will be generated in _generate_transforms()
    // mesh
    Ref<MMeshLod> mesh;
    void _generate_transforms();
    protected:
    static void _bind_methods();
    public:
    inline Transform3D modify_transform(const Transform3D& t, int index) const{
        index = index%transform_count;
        Vector3 __offset = offsets[index];
        Vector3 origin = t.origin + t.basis.get_column(0)*__offset.x + t.basis.get_column(1)*__offset.y + t.basis.get_column(2)*__offset.z;
        return Transform3D(bases[index]*t.basis,origin);
    }

    inline Transform3D modify_transform_mirror(const Transform3D& t, int index) const{
        index = (index+transform_count*2)%transform_count;
        Vector3 __offset = offsets[index];
        __offset.z *= -1.0;
        Vector3 origin = t.origin + t.basis.get_column(0)*__offset.x + t.basis.get_column(1)*__offset.y + t.basis.get_column(2)*__offset.z;
        Basis b = mirror_rotation ? bases[index].rotated(Vector3(0,1,0),3.14159265359) : bases[index];
        return Transform3D(b,origin);
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

    void emit_elements_changed();

    void set_element_name(const String& input);
    String get_element_name();

    void set_mesh(Ref<MMeshLod> input);
    Ref<MMeshLod> get_mesh() const;

    void set_seed(int input);
    int get_seed() const;

    void set_mirror_rotation(bool input);
    bool get_mirror_rotation() const;

    void set_mirror(bool input);
    bool get_mirror() const;

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
};

class MCurveInstanceOverride : public Resource {
    friend MCurveInstance;
    GDCLASS(MCurveInstanceOverride,Resource);
    protected:
    static void _bind_methods();
    public:
    struct OverrideData
    {
        bool is_exclude = false;
        int8_t element_ovveride[M_CURVE_CONNECTION_INSTANCE_COUNT];
        MByteFloat<false,1> start_offset = 0;
        MByteFloat<false,1> end_offset = 0;
        MByteFloat<false,1> random_remove = 0;
        OverrideData();
    };
    
    private:
    HashMap<int64_t,OverrideData> data;
    public:
    void emit_connection_changed(int64_t conn_id);
    int get_conn_element_capacity(int64_t conn_id) const;
    void set_exclude_connection(int64_t conn_id,bool value);
    bool is_exclude_connection(int64_t conn_id) const;
    void add_element(int64_t conn_id,int element_index);
    void remove_element(int64_t conn_id,int element_index);
    PackedByteArray get_elements(int64_t conn_id) const;
    bool has_element(int64_t conn_id,int8_t element_index) const;
    void clear_to_default(int64_t conn_id);
    bool has_override(int64_t conn_id) const;
    // set override setting
    void set_start_offset(int64_t conn_id,float val);
    float get_start_offset(int64_t conn_id) const;
    void set_end_offset(int64_t conn_id,float val);
    float get_end_offset(int64_t conn_id) const;
    void set_rand_remove(int64_t conn_id,float val);
    float get_rand_remove(int64_t conn_id) const;
    // Data
    void set_data(const PackedByteArray& input);
    PackedByteArray get_data() const;
};

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
        inline static int mcurve_instance_count = 0;
        Instance(){
            mcurve_instance_count++;
        }
        ~Instance(){
            mcurve_instance_count--;
        }
        struct Scene
        {
            int row;
            //MNode* node;
        };
        
        public:
        int multimesh_count = 0;
        private:
        int scene_count = 0;
        // Row number start from zero at start of connection
        // and increase up to end of connection
        // Here we determine which of instances is not part of multimesh and is a scene
        Instance::Scene* scenes = nullptr;
        public:
        RID mesh_rid;
        RID instance;
        RID multimesh;
        _FORCE_INLINE_ int get_scene_count(){return scene_count;}
        //void insert_scene(int row,MNode* node);
        //MNode* get_scene(int row);
        bool has_scene(int row);
        void remove_scene(int row);
    };

    struct Instances {
        Instance instances[M_CURVE_CONNECTION_INSTANCE_COUNT];
        inline Instance& operator[](const size_t index){
            return instances[index];
        }
        inline bool has_valid_instance() const {
            for(int i=0; i < M_CURVE_CONNECTION_INSTANCE_COUNT; i++){
                if(instances[i].multimesh.is_valid() || instances[i].instance.is_valid()){
                    return true;
                }
            }
            return false;
        }
    };

    struct MultimeshUpdate
    {
        int64_t conn_id;
        RID multimesh;
    };
    bool is_thread_updating = false;
    bool keep_default = false;
    int default_element = 0;
    int32_t curve_user_id;
    WorkerThreadPool::TaskID thread_task_id;
    Ref<MCurveInstanceElement> elements[M_CURVE_ELEMENT_COUNT];
    MPath* path=nullptr;
    Ref<MCurve> curve;
    Ref<RandomNumberGenerator> rand_gen;
    
    Ref<MCurveInstanceOverride> override_data;
    Vector<MultimeshUpdate> multimesh_updates;
    HashMap<int64_t,MCurveInstance::Instances> curve_instance_instances;

    public:
    std::recursive_mutex update_mutex;
    MCurveInstance();
    ~MCurveInstance();
    void _on_connections_updated();
    static void thread_update(void* input);
    /// Decide what element should be added and calling _generate_connection_element
    void _generate_connection(const MCurve::ConnUpdateInfo& update_info,bool immediate_update=false);
    private:
    /// Do not call directly bellow use _generate_connection instead
    bool _generate_connection_element(Ref<MCurveInstanceElement> element,MCurveInstance::Instance& curve_instance,const MCurveInstanceOverride::OverrideData& ov,int64_t conn_id);
    public:
    void _connection_force_update(int64_t conn_id);
    void _connection_remove(int64_t conn_id);
    void _recreate();
    // in case instance_index=-1 all instance will be removed
    void _remove_instance(int64_t conn_id,int instance_index=-1,bool rm_curve_instance_instances=true);
    void _remove_all_instance();
    void set_override(Ref<MCurveInstanceOverride> input);
    OverrideData get_default_override_data() const;
    Ref<MCurveInstanceOverride> get_override() const;
    void set_keep_default(bool input);
    bool get_keep_default() const;
    void set_default_element(int input);
    int get_default_element() const;


    void _on_curve_changed();
    void _process_tick();
    void _notification(int p_what);
    PackedStringArray _get_configuration_warnings() const;

    void set_element(int instance_index,Ref<MCurveInstanceElement> input);
    Ref<MCurveInstanceElement> get_element(int instance_index) const;

    static int get_instance_count();
    static int get_element_count();
};
#endif