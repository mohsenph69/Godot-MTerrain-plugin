#ifndef _MCURVE
#define _MCURVE

// These two bellow should match in number
// Max conn should not be bigger than 127
#define MAX_CONN 4
#define conn_DEFAULT_VALUE {0,0,0,0}

#define CONN_ADDITIONAL_POINT_COUNT 8 // additional point for calculting better LOD
#define CONN_ADDITIONAL_POINT_LOD {-1,-1,-1,-1,-1,-1,-1,-1} // correct accordingly base on CONN_ADDITIONAL_POINT_COUNT
#define CONN_ADDITIONAL_POINT_INTERVAL_RATIO (1.0f/(CONN_ADDITIONAL_POINT_COUNT+1)) // Also start point

#define INIT_POINTS_BUFFER_SIZE 10
#define INC_POINTS_BUFFER_SIZE 10
#define INVALID_POINT_INDEX 0
#define LENGTH_POINT_SAMPLE_COUNT_BASIC 1 // exclude start and end point only middle
#define INVALID_POINT_LOD -1 // Must be bigger than MAX_LOD in octree -- Only for internal reason outside lod=-1 is invalid

// RULE ---> LENGTH_POINT_SAMPLE_COUNT % DISTANCE_BAKE_INTERVAL = 0 ... Please change two bellow base on prev rule 
#define LENGTH_POINT_SAMPLE_COUNT 128
// Each 3 point which get sampled one bake lenght will be added
#define DISTANCE_BAKE_INTERVAL 4 // Total_point_interrval = LENGTH_POINT_SAMPLE_COUNT / DISTANCE_BAKE_INTERVAL
#define DISTANCE_BAKE_TOTAL (LENGTH_POINT_SAMPLE_COUNT/DISTANCE_BAKE_INTERVAL)
#define RATIO_BAKE_INTERVAL (1.0f/DISTANCE_BAKE_TOTAL)

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/templates/vector.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/templates/hash_set.hpp>
#include <godot_cpp/templates/vmap.hpp>


#include <godot_cpp/variant/utility_functions.hpp>
#include "../moctree.h"

using namespace godot;

class MCurve;

class MCurveConnCollision : public RefCounted {
    friend MCurve;
    GDCLASS(MCurveConnCollision,RefCounted);
    bool _is_col = false;
    float _ratio;
    int64_t _conn_id;
    protected:
    static void _bind_methods();
    public:
    bool is_collided() const;
    float get_collision_ratio() const;
    int64_t get_conn_id() const;
};

/**
 * use set_override_entry and get_override_entry for setting and getting MCurveOverrideData
 * use get_point_conns_override_entries to get all override data for connection connected to a point
 * 
 * usefull for things like copying override data and undo a redo
 * Only run-time for temporary stuff not save or ...
 * 
 * set_override_entry, get_override_entry id can be id of conn or point
 * as id of conn or point will never collide
 */
class MCurveOverrideData : public RefCounted {
    GDCLASS(MCurveOverrideData,RefCounted);
    protected:
    static void _bind_methods(){};
    public:
    struct Entry {
        int user_id;
        Node* node;
        PackedByteArray data;
    };
    Vector<Entry> entries;
};
/*
    Each point has int32_t id
    Each has an array of next conn in conn!
    -------------- conn ----------------------
    Each conection can be interpolated in various ways
    In each bezier line interpolation between two point we use two position of Point A and B
    Then inside struct point A if in conn the B id is negated we use vector3 in in this interpolation!
    And if the B id is positive we use Vector3 out for this conn interpolation
    The same rule will apply inside B struct!
    -------------- conn unique ID ----------------------------
    Each conn will have unique ID which is define in Conn Union
    The way this Union defined it will generate one unique ID for each conn
    Each unique ID is defined as int64_t to also be consistate with Variant integer
    //////////////////////  INVALIDE ID INDEX RULE ///////////////////////////////////
    Due to nature of using negetive number we can not use point with id of 0
    So we use the point with id of 0 to be invalide point index
    In total id of 0 are not usable and they be left empty in points_buffer
*/  
class MCurve : public Resource{
    GDCLASS(MCurve,Resource);
    protected:
    static void _bind_methods();

    public:
    struct PointSave;
    struct Point // Index zero is considerd to be null
    {
        int8_t lod = INVALID_POINT_LOD;
        int32_t conn[MAX_CONN] = conn_DEFAULT_VALUE;
        float tilt = 0.0;
        float scale = 1.0;
        Vector3 up;
        Vector3 in;
        Vector3 out;
        Vector3 position;
        Point() = default;
        Point(Vector3 _position,Vector3 _in,Vector3 _out);
        PointSave get_point_save();
        inline bool is_connected_to(int32_t p_id) const {
            for(int i=0; i < MAX_CONN; i++){
                if(conn[i]!=0 && std::abs(conn[i])==p_id){
                    return true;
                }
            }
            return false;
        }
        inline int get_conn_count() const {
            int count = 0;
            for(int i=0; i < MAX_CONN; i++){
                if(conn[i]!=0){
                    count++;
                }
            }
            return count;
        }
    };

    union Conn
    {
        struct {
            int32_t a;
            int32_t b;
        } p;
        int64_t id = 0;
        // p0 and p1 should be always positive and can't be equale
        Conn(int32_t p0, int32_t p1);
        Conn(int64_t _id);
        Conn() = default;
        ~Conn() = default;
        inline bool is_connection(){
            return p.b!=0;
        }
        inline String str(){
            return String("Conn(") + itos(p.a) + " , " + itos(p.b) + ")";
        }
    };
    private:
    /**
     * ConnData contain additional point for sending to octree for more accurate LOD calculation
     * octree id of each point will be calculated base on ConnData position in array and CONN_ADDITIONAL_POINT_COUNT
     * octree_id = -(CONN_ADDITIONAL_POINT_COUNT*conn_id + i)
     * Also octree_id of each point is negetive to not collide with point IDs
     * 
     * additional point in octree is -> (conn_id32*CONN_ADDITIONAL_POINT_COUNT) + additonal_index;
     * additonal_index is between [0,CONN_ADDITIONAL_POINT_COUNT-1]
     * 
     * Keep the lod and conn_id of ConnAdditionalPoints with the same index in data
     * seperated as accessing each one require at different time and there is no need to both loaded at the same time
     */
    struct ConnAdditional {
        int8_t lod[CONN_ADDITIONAL_POINT_COUNT] = CONN_ADDITIONAL_POINT_LOD;
        int64_t conn_id;
    };
    public:
    enum ConnType {
        CONN_NONE = 0,
        OUT_IN = 1,
        IN_OUT = 2,
        IN_IN = 3,
        OUT_OUT = 4
    };

    struct ConnUpdateInfo {
        int8_t last_lod;
        int8_t current_lod;
        int64_t conn_id;
    };

    struct PointUpdateInfo {
        int8_t last_lod;
        int8_t current_lod;
        int32_t point_id;
    };

    struct ConnDistances {
        float dis[DISTANCE_BAKE_TOTAL];
    };

    struct PointSave
    {
        int32_t prev;
        int32_t conn[MAX_CONN];
        float tilt;
        float scale;
        Vector3 in;
        Vector3 out;
        Vector3 position;
        Point get_point(){
            Point p;
            for(int8_t i=0; i < MAX_CONN; i++){
                p.conn[i] = conn[i];
            }
            p.tilt = tilt;
            p.scale = scale;
            p.in = in;
            p.out = out;
            p.position = position;
            return p;
        }
    };

    private:
    bool is_init_insert = false;
    bool is_waiting_for_user = false;
    int8_t active_lod_limit = 2;
    uint16_t oct_id = 0;
    PackedInt32Array free_buffer_indicies;
    void _increase_points_buffer_size(size_t q);
    /// Conn additional points
    void _increase_conn_data_buffer_size(size_t q);
    /// positions is the pointer to a block of memory with Vector3 ptrw[CONN_ADDITIONAL_POINT_COUNT]
    _FORCE_INLINE_ void _get_additional_points(Vector3* positions,const Vector3& a,const Vector3& b,const Vector3& a_control, const Vector3& b_control) const;
    /// More slow version of _get_additional_points for handling light stuff
    void _get_conn_additional_points(ino64_t conn_id,Vector3* positions) const;
    /////////////////// _init_conn_additional_points for init_insert
    ///////// Warning _init_conn_additional_points do the least error checking
    /// use for start to at load time and it assume that conn_addition_point does not exist and it is empty
    /// conn_id must exist it will not check if it exist or not
    _FORCE_INLINE_ void _init_conn_additional_points(const int64_t conn_id,PackedVector3Array& positions,PackedInt32Array& ids);
    /// this will not use at load time it should be called at each connection modification
    /// it is not inlined and optimized as usually use for editor during curve modification and will be called for few connection each time
    /// IMPORTANT: this will asume you calculate point LOD before calling this and this will take care of conn_list and active_conn
    /// No need to old_positions for add new or remove conn_id can be set to nullptr (only move need that)
    void _update_conn_additional_points(const int64_t conn_id,Vector3* old_positions=nullptr);
    //PackedInt32Array root_ids;
    static MOctree* octree;
    int32_t last_curve_id = 0;
    VMap<int32_t,Node*> curve_users;
    VSet<int32_t> processing_users;
    VSet<int32_t> active_points;
    VSet<int64_t> active_conn;
    //Vector<int32_t> force_reupdate_points;
    HashMap<int64_t,int32_t> conn_id32;
    Vector<int32_t> conn_free_id32;
    Vector<ConnAdditional> conn_additional;
    HashMap<int64_t,int8_t> conn_list; // Key -> conn, Value -> LOD
    HashMap<int64_t,AABB> conn_aabb; // Cached conn aabb
    HashMap<int64_t,ConnDistances> conn_distances;

    float bake_interval = 0.2;

    // Only editor and in debug version
    //#ifdef DEBUG_ENABLED
    HashMap<int64_t,PackedVector3Array> baked_lines;
    //#endif

    public:
    Vector<ConnUpdateInfo> conn_update;
    Vector<PointUpdateInfo> point_update;
    static void set_octree(MOctree* input);
    static MOctree* get_octree();
    Vector<MCurve::Point> points_buffer;
    MCurve();
    ~MCurve();
    void set_override_entry(int64_t id,Ref<MCurveOverrideData> override_data);
    Ref<MCurveOverrideData> get_override_entry(int64_t id) const;
    void set_override_entries_and_apply(PackedInt64Array ids,TypedArray<MCurveOverrideData> override_data_array,bool is_conn_override);
    int get_points_count();
    // Users
    int32_t get_curve_users_id(Node* node);
    void remove_curve_user_id(int32_t user_id);

    // In case prev_conn = -1 this will insert as root node and if a root node exist this will give an error
    int32_t add_point(const Vector3& position,const Vector3& in,const Vector3& out, const int32_t prev_conn,Ref<MCurveOverrideData> point_override_data,Ref<MCurveOverrideData> conn_override_data);
    int32_t add_point_conn_point(const Vector3& position,const Vector3& in,const Vector3& out,const Array& conn_types,const PackedInt32Array& conn_points,Ref<MCurveOverrideData> point_override=nullptr,TypedArray<MCurveOverrideData> conn_overrides=TypedArray<MCurveOverrideData>());
    // important this should be called when conn change or remove
    void clear_conn_cache_data(int64_t conn_id);
    /// break a connection into two connection by adding a point on top of that
    /// t is ratio
    int32_t add_point_conn_split(int64_t conn_id,float t);
    bool connect_points(int32_t p0,int32_t p1,ConnType con_type=CONN_NONE,Ref<MCurveOverrideData> conn_ov_data=nullptr);
    bool disconnect_conn(int64_t conn_id);
    bool disconnect_points(int32_t p0,int32_t p1);
    void remove_point(const int32_t point_index);
    void clear_points();
    void init_insert();
    void _octree_update_finish();
    void user_finish_process(int32_t user_id);


    public:
    int64_t get_conn_id(int32_t p0, int32_t p1);
    PackedInt32Array get_conn_points(int64_t conn_id);
    PackedInt64Array get_conn_ids_exist(const PackedInt32Array points);
    int8_t get_conn_lod(int64_t conn_id);
    int8_t get_point_lod(int64_t p_id);
    PackedInt32Array get_active_points();
    PackedVector3Array get_active_points_positions();
    PackedInt64Array get_active_conns();
    PackedVector3Array get_conn_baked_points(int64_t input_conn);
    PackedVector3Array get_conn_baked_line(int64_t input_conn);

    public:
    void toggle_conn_type(int32_t point, int64_t conn_id);
    private:
    /// Return zero if not exist
    _FORCE_INLINE_ int32_t _get_conn_id32(int64_t conn_id) const;
    /// Will remove if cid32 is zero
    _FORCE_INLINE_ void _set_conn_id32(int64_t conn_id,int32_t cid32);
    _FORCE_INLINE_ int8_t _calculate_conn_lod(const int64_t conn_id) const;
    void _validate_points(const VSet<int32_t>& points);
    /// if conn is removed handle it!
    /// recalculate LOD base on conn points and update conn_list and active_conn accordingly
    void _validate_conns(const VSet<int64_t>& conns);
    void _swap_points(const int32_t p_a,const int32_t p_b,VSet<int64_t>& affected_conns);
    public:
    void swap_points(const int32_t p_a,const int32_t p_b);
    /**
        sort increasing or decreasing
        if _selected_points is empty it will sort in all points
        this will return new root point as that will change during sorting
    */
    int32_t sort_from(int32_t root_point,bool increasing);
    void move_point(int p_index,const Vector3& pos);
    void move_point_in(int p_index,const Vector3& pos);
    void move_point_out(int p_index,const Vector3& pos);

    bool has_point(int p_index) const;
    bool has_conn(int64_t conn_id) const;
    bool is_point_connected(int32_t pa,int32_t pb) const;
    ConnType get_conn_type(int64_t conn_id) const;
    Array get_point_conn_types(int32_t p_index) const;
    int get_point_conn_count(int32_t p_index) const;
    PackedInt32Array get_point_conn_points_exist(int32_t p_index) const;
    PackedInt32Array get_point_conn_points(int32_t p_index) const;
    TypedArray<MCurveOverrideData> get_point_conn_overrides(int32_t p_index) const;
    /*
        output is in order of IDs
    */
    VSet<int32_t> get_point_conn_points_recursive(int32_t p_index) const;
    /*
        Above function for gdscript as gdscript not recognize VSet<int32_t>
    */
    PackedInt32Array get_point_conn_points_recursive_gd(int32_t p_index) const;
    PackedInt64Array get_point_conns(int32_t p_index) const;
    /// Return OverrideData which can be set by set_override_entry
    /// p_index is point index
    /// Dictionary key is conn_id connected to point
    /// Dictionary value is OverrideData
    /// For grabing single OverrideData data for point or conn use get_override_entry
    Dictionary get_point_conns_override_entries(int32_t p_index) const;
    PackedInt64Array get_point_conns_inc_neighbor_points(int32_t p_index) const;
    PackedInt64Array growed_conn(PackedInt64Array conn_ids) const;
    Vector3 get_point_position(int p_index);
    Vector3 get_point_in(int p_index);
    Vector3 get_point_out(int p_index);
    float get_point_tilt(int p_index);
    void set_point_tilt(int p_index,float input);
    float get_point_scale(int p_index);
    void set_point_scale(int p_index,float input);
    void commit_point_update(int p_index);
    void commit_conn_update(int64_t conn_id);


    public:
    /// Function bellow should be thread safe in case is called from another thread
    Vector3 get_conn_position(int64_t conn_id,float t);
    AABB get_conn_aabb(int64_t conn_id);
    AABB get_conns_aabb(const PackedInt64Array& conn_ids);
    float get_closest_ratio_to_point(int64_t conn_id,Vector3 pos) const;
    /// first is ratio and second is distance
    float get_closest_ratio_to_line(int64_t conn_id,Vector3 line_pos,Vector3 line_dir) const;
    Vector3 get_point_order_tangent(int32_t point_a,int32_t point_b,float t);
    Vector3 get_conn_tangent(int64_t conn_id,float t);
    Transform3D get_point_order_transform(int32_t point_a,int32_t point_b,float t,bool tilt=true,bool scale=true);
    Transform3D get_conn_transform(int64_t conn_id,float t,bool apply_tilt=true,bool apply_scale=true);
    void get_conn_transforms(int64_t conn_id,const Vector<float>& t,Vector<Transform3D>& transforms,bool apply_tilt=true,bool apply_scale=true);
    float get_conn_lenght(int64_t conn_id);
    Pair<float,float> conn_ratio_limit_to_dis_limit(int64_t conn_id,const Pair<float,float>& limits);
    float get_point_order_distance_ratio(int32_t point_a,int32_t point_b,float distance);
    float get_conn_distance_ratio(int64_t conn_id,float distance);
    Pair<int,int> get_conn_distances_ratios(int64_t conn_id,const Vector<float>& distances,Vector<float>& t);
    private:
    _FORCE_INLINE_ float _get_conn_ratio_distance(const float* baked_dis,const float ratio) const;
    _FORCE_INLINE_ float _get_conn_distance_ratios(const float* baked_dis,const float distance) const;
    _FORCE_INLINE_ float* _bake_conn_distance(int64_t conn_id);
    // End of thread safe
    public:
    int32_t ray_active_point_collision(const Vector3& org,Vector3 dir,float threshold); // Maybe later optmize this
    Ref<MCurveConnCollision> ray_active_conn_collision(const Vector3& org,Vector3 dir,float threshold);
    void _set_data(const PackedByteArray& input);
    PackedByteArray _get_data();

    void set_bake_interval(float input);
    float get_bake_interval();
    void set_active_lod_limit(int input);
    int get_active_lod_limit();
    
    private:
    _FORCE_INLINE_ float  get_length_between_basic(const Point* a, const Point* b,const Vector3& a_control, const Vector3& b_control);
    
    #define BEZIER_EPSILON 0.1f
    _FORCE_INLINE_ Vector3 _get_bezier_extreme_t(const Vector3& a,const Vector3& b,const Vector3& a_control, const Vector3& b_control){
        return (2*a_control - (b_control + a))/(b - a + 3*(a_control - b_control));
    }
    /// Return the second derivative of bezier curve (not normlized)
    /// not used in _get_bezier_transform, as it can create problems
    _FORCE_INLINE_ Vector3 _get_bezier_normal(const Vector3& a,const Vector3& b,const Vector3& a_control, const Vector3& b_control,const float t){
        float u = 1 - t;
        return 6*(u*(b_control - 2*a_control + a) + t*(b - 2*b_control + a_control));
    }
    _FORCE_INLINE_ Vector3 _get_bezier_tangent(const Vector3& a,const Vector3& b,const Vector3& a_control, const Vector3& b_control,const float t){

        float u = 1 - t;
        float tt = t * t;
        float uu = u * u;
        float ut = u * t;

        Vector3 tangent;
        // Handling tangent zero points
        if( t < BEZIER_EPSILON && a.is_equal_approx(a_control)){
            Vector3 pos2 = a.bezier_interpolate(a_control,b_control,b,BEZIER_EPSILON);
            Vector3 pos = uu*u*a + 3*ut*u*a_control + 3*ut*t*b_control + tt*t*b;
            tangent = pos2 - pos;
        } else if( 1.0f - t < BEZIER_EPSILON && b.is_equal_approx(b_control)){
            Vector3 pos = uu*u*a + 3*ut*u*a_control + 3*ut*t*b_control + tt*t*b;
            Vector3 pos2 = a.bezier_interpolate(a_control,b_control,b,1.0f - BEZIER_EPSILON);
            tangent = pos - pos2;
        } else {
            tangent = 3*uu*(a_control - a) + 6*ut*(b_control - a_control) + 3*tt*(b - b_control);
        }
        tangent.normalize();
        return tangent;
    }
    // This function must not be called with completly straight Up_Vector line
    // It can handle if small part of line has a perpendiculare part
    _FORCE_INLINE_ Transform3D _get_bezier_transform(const Vector3& a,const Vector3& b,const Vector3& a_control, const Vector3& b_control,const Vector3& init_up_vec,float t){
        t = Math::clamp(t, 0.0f, 1.0f);
        float u = 1 - t;
        float tt = t * t;
        float uu = u * u;
        float ut = u * t;

        Vector3 pos = uu*u*a + 3*ut*u*a_control + 3*ut*t*b_control + tt*t*b;
        Vector3 tangent;
        Vector3 normal;
        // normal by derivative which does not work unfortunatly
        // normal = 6*u*(b_control - 2*a_control + a) + 6*t*(b - 2*b_control + a_control);

        // Handling tangent zero points
        if(unlikely(t < BEZIER_EPSILON && a.is_equal_approx(a_control))){
            Vector3 pos2 = a.bezier_interpolate(a_control,b_control,b,BEZIER_EPSILON);
            tangent = pos2 - pos;
        } else if(unlikely(1.0f - t < BEZIER_EPSILON && b.is_equal_approx(b_control))){
            Vector3 pos2 = a.bezier_interpolate(a_control,b_control,b,1.0f - BEZIER_EPSILON);
            tangent = pos - pos2;
        } else {
            tangent = 3*uu*(a_control - a) + 6*ut*(b_control - a_control) + 3*tt*(b - b_control);
        }
        tangent.normalize();
        // Handling small section Up_vector tangent
        if(unlikely(abs(tangent.y) > 0.999)){
            if(t > BEZIER_EPSILON * 10){
                Vector3 etangent = _get_bezier_tangent(a,b,a_control,b_control,t - BEZIER_EPSILON);
                normal = etangent.cross(init_up_vec);
            } else {
                Vector3 etangent = _get_bezier_tangent(a,b,a_control,b_control,t + BEZIER_EPSILON);
                normal = etangent.cross(init_up_vec);
            }
        } else {
            normal = tangent.cross(init_up_vec);
        }
        normal.normalize();

        Vector3 binormal = normal.cross(tangent);
        return Transform3D(tangent,binormal,normal,pos);
    }


};

VARIANT_ENUM_CAST(MCurve::ConnType);

#endif