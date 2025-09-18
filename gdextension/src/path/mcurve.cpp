#include "mcurve.h"

#include <stack>

#include <godot_cpp/variant/utility_functions.hpp>

#include "mpath.h"
#include "mcurve_mesh.h"
#include "mcurve_instance.h"



MOctree* MCurve::octree = nullptr;


void MCurveConnCollision::_bind_methods(){
    ClassDB::bind_method(D_METHOD("is_collided"), &MCurveConnCollision::is_collided);
    ClassDB::bind_method(D_METHOD("get_collision_ratio"), &MCurveConnCollision::get_collision_ratio);
    ClassDB::bind_method(D_METHOD("get_conn_id"), &MCurveConnCollision::get_conn_id);
}

bool MCurveConnCollision::is_collided() const{
    return _is_col;
}

float MCurveConnCollision::get_collision_ratio() const{
    return _ratio;
}

int64_t MCurveConnCollision::get_conn_id() const{
    return _conn_id;
}


void MCurve::set_octree(MOctree* input){
    if(input==nullptr){
        octree = nullptr;
    }
    ERR_FAIL_COND_MSG(octree!=nullptr,"Only one octree can udpate MPath");
    octree = input;
}

MOctree* MCurve::get_octree(){
    return octree;
}

void MCurve::_bind_methods(){
    /// signals
    ADD_SIGNAL(MethodInfo("curve_updated"));
    ADD_SIGNAL(MethodInfo("connection_updated")); // chech after this point_update and connection_update
    //// Mostly use for editor update when moving or removing a point
    ADD_SIGNAL(MethodInfo("force_update_point",PropertyInfo(Variant::INT,"point_id")));
    ADD_SIGNAL(MethodInfo("force_update_connection",PropertyInfo(Variant::INT,"conn_id")));
    ADD_SIGNAL(MethodInfo("remove_point",PropertyInfo(Variant::INT,"point_id")));
    ADD_SIGNAL(MethodInfo("remove_connection",PropertyInfo(Variant::INT,"conn_id")));
    ADD_SIGNAL(MethodInfo("swap_point_id",PropertyInfo(Variant::INT,"p_a"),PropertyInfo(Variant::INT,"p_b")));
    ADD_SIGNAL(MethodInfo("recreate"));
    // end of signals
    ClassDB::bind_method(D_METHOD("emit_recreate"), &MCurve::emit_recreate);
    
    ClassDB::bind_method(D_METHOD("set_override_entry","id","override_data"), &MCurve::set_override_entry);
    ClassDB::bind_method(D_METHOD("get_override_entry","id"), &MCurve::get_override_entry);
    ClassDB::bind_method(D_METHOD("set_override_entries_and_apply","ids","override_data_array","is_conn_override"), &MCurve::set_override_entries_and_apply);

    ClassDB::bind_method(D_METHOD("get_points_count"), &MCurve::get_points_count);

    ClassDB::bind_method(D_METHOD("add_point","position","in","out","prev_conn","point_override","conn_override"), &MCurve::add_point,DEFVAL(0),DEFVAL(nullptr),DEFVAL(nullptr));
    ClassDB::bind_method(D_METHOD("add_point_conn_point","position","in","out","conn_types","conn_points","point_override","conn_overrides"), &MCurve::add_point_conn_point, DEFVAL(nullptr),DEFVAL(nullptr));
    ClassDB::bind_method(D_METHOD("add_point_conn_split","conn_id","t"), &MCurve::add_point_conn_split);
    ClassDB::bind_method(D_METHOD("connect_points","p0","p1","conn_type","conn_ov_data"), &MCurve::connect_points,DEFVAL(nullptr));
    ClassDB::bind_method(D_METHOD("disconnect_conn","conn_id"), &MCurve::disconnect_conn);
    ClassDB::bind_method(D_METHOD("disconnect_points","p0","p1"), &MCurve::disconnect_points);
    ClassDB::bind_method(D_METHOD("remove_point","point_index"), &MCurve::remove_point);
    ClassDB::bind_method(D_METHOD("remove_points","point_ids"), &MCurve::remove_points);
    ClassDB::bind_method(D_METHOD("clear_points"), &MCurve::clear_points);

    ClassDB::bind_method(D_METHOD("get_conn_id","p0","p1"), &MCurve::get_conn_id);
    ClassDB::bind_method(D_METHOD("get_conn_next","conn_id"), &MCurve::get_conn_next);
    ClassDB::bind_method(D_METHOD("get_conn_prev","conn_id"), &MCurve::get_conn_prev);
    ClassDB::bind_method(D_METHOD("get_conn_id","p0","p1"), &MCurve::get_conn_id);
    ClassDB::bind_method(D_METHOD("get_conn_points","conn_id"), &MCurve::get_conn_points);
    ClassDB::bind_method(D_METHOD("get_conn_ids_exist","points"), &MCurve::get_conn_ids_exist);
    ClassDB::bind_method(D_METHOD("get_conn_lod","conn_id"), &MCurve::get_conn_lod);
    ClassDB::bind_method(D_METHOD("get_active_points"), &MCurve::get_active_points);
    ClassDB::bind_method(D_METHOD("get_active_points_positions"), &MCurve::get_active_points_positions);
    ClassDB::bind_method(D_METHOD("get_active_conns"), &MCurve::get_active_conns);
    ClassDB::bind_method(D_METHOD("get_conn_baked_points","conn"), &MCurve::get_conn_baked_points);
    ClassDB::bind_method(D_METHOD("get_conn_baked_line","conn"), &MCurve::get_conn_baked_line);

    ClassDB::bind_method(D_METHOD("_octree_update_finish"), &MCurve::_octree_update_finish);


    ClassDB::bind_method(D_METHOD("has_point","p_index"), &MCurve::has_point);
    ClassDB::bind_method(D_METHOD("has_conn","conn_id"), &MCurve::has_conn);
    ClassDB::bind_method(D_METHOD("is_point_connected","pa","pb"), &MCurve::is_point_connected);
    ClassDB::bind_method(D_METHOD("get_conn_type","conn_id"), &MCurve::get_conn_type);
    ClassDB::bind_method(D_METHOD("get_point_conn_count","p_index"), &MCurve::get_point_conn_count);
    ClassDB::bind_method(D_METHOD("get_point_conn_points","p_index"), &MCurve::get_point_conn_points);
    ClassDB::bind_method(D_METHOD("get_point_conn_overrides","p_index"), &MCurve::get_point_conn_overrides);
    ClassDB::bind_method(D_METHOD("get_point_conn_points_recursive","p_index"), &MCurve::get_point_conn_points_recursive_gd);
    ClassDB::bind_method(D_METHOD("get_point_conns","p_index"), &MCurve::get_point_conns);
    ClassDB::bind_method(D_METHOD("get_point_conns_override_entries","p_index"), &MCurve::get_point_conns_override_entries);
    ClassDB::bind_method(D_METHOD("get_point_conns_inc_neighbor_points","p_index"), &MCurve::get_point_conns_inc_neighbor_points);
    ClassDB::bind_method(D_METHOD("growed_conn","conn_ids"), &MCurve::growed_conn);
    ClassDB::bind_method(D_METHOD("get_point_conn_types","p_index"), &MCurve::get_point_conn_types);
    ClassDB::bind_method(D_METHOD("get_point_position","p_index"), &MCurve::get_point_position);
    ClassDB::bind_method(D_METHOD("get_point_in","p_index"), &MCurve::get_point_in);
    ClassDB::bind_method(D_METHOD("get_point_out","p_index"), &MCurve::get_point_out);
    ClassDB::bind_method(D_METHOD("get_point_tilt","p_index"), &MCurve::get_point_tilt);
    ClassDB::bind_method(D_METHOD("set_point_tilt","p_index","val"), &MCurve::set_point_tilt);
    ClassDB::bind_method(D_METHOD("get_point_scale","p_index"), &MCurve::get_point_scale);
    ClassDB::bind_method(D_METHOD("set_point_scale","p_index","val"), &MCurve::set_point_scale);
    ClassDB::bind_method(D_METHOD("commit_point_update","p_index"), &MCurve::commit_point_update);
    ClassDB::bind_method(D_METHOD("commit_conn_update","conn_id"), &MCurve::commit_conn_update);

    ClassDB::bind_method(D_METHOD("get_point_order_tangent","point_a","point_b","t"), &MCurve::get_point_order_tangent);
    ClassDB::bind_method(D_METHOD("get_conn_tangent","conn_id","t"), &MCurve::get_conn_tangent);
    ClassDB::bind_method(D_METHOD("get_point_order_transform","point_a","point_b","t","tilt","scale"), &MCurve::get_point_order_transform);
    ClassDB::bind_method(D_METHOD("get_conn_transform","conn_id","t","tilt","scale"), &MCurve::get_conn_transform);

    ClassDB::bind_method(D_METHOD("toggle_conn_type","point","conn_id"), &MCurve::toggle_conn_type);
    ClassDB::bind_method(D_METHOD("swap_points","p_a","p_b"), &MCurve::swap_points);
    ClassDB::bind_method(D_METHOD("sort_from","root_id","increasing"), &MCurve::sort_from);
    ClassDB::bind_method(D_METHOD("move_point","p_index","pos"), &MCurve::move_point);
    ClassDB::bind_method(D_METHOD("move_point_in","p_index","pos"), &MCurve::move_point_in);
    ClassDB::bind_method(D_METHOD("move_point_out","p_index","pos"), &MCurve::move_point_out);

    ClassDB::bind_method(D_METHOD("get_conn_position","conn_id","t"), &MCurve::get_conn_position);
    ClassDB::bind_method(D_METHOD("get_conn_aabb","conn_id"), &MCurve::get_conn_aabb);
    ClassDB::bind_method(D_METHOD("get_conns_aabb","conn_ids"), &MCurve::get_conns_aabb);
    ClassDB::bind_method(D_METHOD("get_closest_ratio_to_point","conn_id","pos"), &MCurve::get_closest_ratio_to_point);
    ClassDB::bind_method(D_METHOD("get_closest_ratio_to_line","conn_id","line_pos","line_dir"), &MCurve::get_closest_ratio_to_line);
    ClassDB::bind_method(D_METHOD("get_conn_lenght","conn_id"), &MCurve::get_conn_lenght);
    ClassDB::bind_method(D_METHOD("get_conn_distance_ratio","conn_id","distance"), &MCurve::get_conn_distance_ratio);

    ClassDB::bind_method(D_METHOD("ray_active_point_collision","org","dir","threshold"), &MCurve::ray_active_point_collision);
    ClassDB::bind_method(D_METHOD("ray_active_conn_collision","org","dir","threshold"), &MCurve::ray_active_conn_collision);
    ClassDB::bind_method(D_METHOD("_set_data","input"), &MCurve::_set_data);
    ClassDB::bind_method(D_METHOD("_get_data"), &MCurve::_get_data);
    ADD_PROPERTY(PropertyInfo(Variant::PACKED_BYTE_ARRAY,"_data",PROPERTY_HINT_NONE,"",PROPERTY_USAGE_STORAGE),"_set_data","_get_data");

    ClassDB::bind_method(D_METHOD("set_bake_interval","input"), &MCurve::set_bake_interval);
    ClassDB::bind_method(D_METHOD("get_bake_interval"), &MCurve::get_bake_interval);
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT,"bake_interval"),"set_bake_interval","get_bake_interval");

    ClassDB::bind_method(D_METHOD("set_active_lod_limit","input"), &MCurve::set_active_lod_limit);
    ClassDB::bind_method(D_METHOD("get_active_lod_limit"), &MCurve::get_active_lod_limit);
    ADD_PROPERTY(PropertyInfo(Variant::INT,"active_lod_limit"), "set_active_lod_limit","get_active_lod_limit");

    BIND_ENUM_CONSTANT(CONN_NONE);
    BIND_ENUM_CONSTANT(OUT_IN);
    BIND_ENUM_CONSTANT(IN_OUT);
    BIND_ENUM_CONSTANT(IN_IN);
    BIND_ENUM_CONSTANT(OUT_OUT);
}

MCurve::Point::Point(Vector3 _position,Vector3 _in,Vector3 _out):
position(_position),out(_out),in(_in){
}

MCurve::PointSave MCurve::Point::get_point_save(){
    PointSave ps;
    for(int8_t i=0; i < MAX_CONN; i++){
        ps.conn[i] = conn[i];
    }
    ps.tilt = tilt;
    ps.scale = scale;
    ps.in = in;
    ps.out = out;
    ps.position = position;
    return ps;
}

// p0 and p1 should be always positive and can't be equale
MCurve::Conn::Conn(int32_t p0, int32_t p1){
    if(p0 < p1){
        p.a = p0;
        p.b = p1;
    } else {
        p.a = p1;
        p.b = p0;
    }
}

MCurve::Conn::Conn(int64_t _id):id(_id){
}

MCurve::MCurve(){
    _increase_points_buffer_size(INIT_POINTS_BUFFER_SIZE);
}

MCurve::~MCurve(){
    if(octree){
        octree->remove_oct_id(oct_id);
    }
}

void MCurve::emit_recreate() {
    emit_signal("curve_updated");
    emit_signal("recreate");
}

void MCurve::set_override_entry(int64_t id,Ref<MCurveOverrideData> override_data){
    ERR_FAIL_COND(override_data.is_null());
    for(int i=0; i < override_data->entries.size(); i++){
        const MCurveOverrideData::Entry& entry = override_data->entries[i];
        Node* node = get_curve_user_by_name(entry.node_name);
        ERR_CONTINUE_MSG(node==nullptr,"Curve user by name \""+entry.node_name+"\" not found!");
        MCurveMesh* curve_mesh = Object::cast_to<MCurveMesh>(node);
        MCurveInstance* curve_instance = Object::cast_to<MCurveInstance>(node);
        if(curve_mesh){
            ERR_FAIL_COND(entry.type!=MCurveOverrideData::CURVE_MESH);
            if(curve_mesh->get_overrides().is_null()){
                Ref<MCurveMeshOverride> ov;
                ov.instantiate();
                curve_mesh->set_overrides(ov);
            }
            curve_mesh->get_overrides()->set_override_entry(id,entry.data);
        } else if(curve_instance){
            ERR_FAIL_COND(entry.type!=MCurveOverrideData::CURVE_INSTANCE);
            if(curve_instance->get_override().is_null()){
                Ref<MCurveInstanceOverride> ov;
                ov.instantiate();
                curve_instance->set_override(ov);
            }
            curve_instance->get_override()->set_override_entry(id,entry.data);
        } else {
            ERR_CONTINUE_MSG(true,"Invalid User Type!");
        }
    }
}

Ref<MCurveOverrideData> MCurve::get_override_entry(int64_t id) const{
    Ref<MCurveOverrideData> out;
    out.instantiate();
    for(int i=0; i < curve_users.size(); i++){
        MCurveOverrideData::Entry entry;
        Node* node = curve_users.get_array()[i].value;
        int user_id = curve_users.get_array()[i].key;
        entry.node_name = node->get_name();
        MCurveMesh* curve_mesh = Object::cast_to<MCurveMesh>(node);
        MCurveInstance* curve_instance = Object::cast_to<MCurveInstance>(node);
        if(curve_mesh){
            entry.type=MCurveOverrideData::CURVE_MESH;
            if(curve_mesh->get_overrides().is_null()){
                continue; // no data
            } else {
                entry.data = curve_mesh->get_overrides()->get_override_entry(id);
            }
        } else if(curve_instance){
            entry.type=MCurveOverrideData::CURVE_INSTANCE;
            if(curve_instance->get_override().is_null()){
                continue; // not data
            } else {
                entry.data = curve_instance->get_override()->get_override_entry(id);
            }
        } else {
            ERR_CONTINUE_MSG(true,"Invalid User Type!");
        }
        out->entries.push_back(entry);
    }
    return out;
}

void MCurve::set_override_entries_and_apply(PackedInt64Array ids,TypedArray<MCurveOverrideData> override_data_array,bool is_conn_override){
    ERR_FAIL_COND(ids.size()!=override_data_array.size());
    for(int i=0; i < ids.size(); i++){
        set_override_entry(ids[i],override_data_array[i]);
        if(is_conn_override){
            emit_signal("force_update_connection",ids[i]);
        } else {
            emit_signal("force_update_point",ids[i]);
        }
    }
}


int MCurve::get_points_count(){
    // -1 because 0 index is always empty
    return points_buffer.size() - free_buffer_indicies.size() - 1;
}

void MCurve::_increase_points_buffer_size(size_t q){
    if(q<=0){
        return;
    }
    int64_t lsize = points_buffer.size();
    godot::Error err = points_buffer.resize(lsize + q);
    ERR_FAIL_COND_MSG(err!=godot::Error::OK,"Can't increase point buffer size, possible fragmentation error!");
    for(int64_t i=points_buffer.size() - 1; i >= lsize ; i--){
        if(i==INVALID_POINT_INDEX){
            continue;
        }
        free_buffer_indicies.push_back(i);
    }
}

void MCurve::_increase_conn_data_buffer_size(size_t q){
    if(q<=0){
        return;
    }
    int64_t lsize = conn_additional.size();
    conn_additional.resize(lsize + q);
    for(int64_t i=conn_additional.size() - 1; i >= lsize ; i--){
        if(i==0 || i==1){
            continue;
        }
        conn_free_id32.push_back(i);
    }
}

void MCurve::_get_additional_points(Vector3* positions,const Vector3& a,const Vector3& b,const Vector3& a_control, const Vector3& b_control) const {
    float current_ratio = 0.0f;
    for(int i=0; i < CONN_ADDITIONAL_POINT_COUNT; i++){
        current_ratio += CONN_ADDITIONAL_POINT_INTERVAL_RATIO;
        positions[i] = a.bezier_interpolate(a_control,b_control,b,current_ratio);
    }
}

void MCurve::_get_conn_additional_points(int64_t conn_id,Vector3* positions) const{
    ERR_FAIL_COND(!has_conn(conn_id));
    Conn conn(conn_id);
    bool is_connected = false;
    const Point& a = points_buffer[conn.p.a];
    const Point& b = points_buffer[conn.p.b];
    const Vector3* a_control;
    const Vector3* b_control;
    for(int i=0; i < MAX_CONN; i++){
        if(std::abs(a.conn[i])==conn.p.b){
            a_control = a.conn[i]==conn.p.b ? &a.out : &a.in;
        }
        if(std::abs(b.conn[i])==conn.p.a){
            b_control = b.conn[i]==conn.p.a ? &b.out : &b.in;
        }
    }
    _get_additional_points(positions,a.position,b.position,*a_control,*b_control);
}

void MCurve::_init_conn_additional_points(const int64_t conn_id,PackedVector3Array& positions,PackedInt32Array& ids){
    Conn conn(conn_id);
    const Point& a = points_buffer[conn.p.a];
    const Point& b = points_buffer[conn.p.b];
    const Vector3* a_control;
    const Vector3* b_control;
    for(int i=0; i < MAX_CONN; i++){
        if(std::abs(a.conn[i])==conn.p.b){
            // means not negated a.conn[i]==conn.p.b
            a_control = a.conn[i]==conn.p.b ? &a.out : &a.in;
        }
        if(std::abs(b.conn[i])==conn.p.a){
            b_control = b.conn[i]==conn.p.a ? &b.out : &b.in;
        }
    }
    if(conn_free_id32.size()==0){
        _increase_conn_data_buffer_size(10);
    }
    ERR_FAIL_COND(conn_free_id32.size()==0);
    int32_t free_index = conn_free_id32[conn_free_id32.size()-1];
    conn_free_id32.remove_at(conn_free_id32.size()-1);
    _set_conn_id32(conn_id,free_index);
    Vector3 additional_positions[CONN_ADDITIONAL_POINT_COUNT];
    _get_additional_points(additional_positions,a.position,b.position,*a_control,*b_control);
    int32_t base_index = free_index*CONN_ADDITIONAL_POINT_COUNT;
    for(int i=0; i < CONN_ADDITIONAL_POINT_COUNT; i++){
        int32_t oindex = base_index + i;
        positions.push_back(additional_positions[i]);
        ids.push_back(-oindex);
    }
}

void MCurve::_update_conn_additional_points(const int64_t conn_id,Vector3* old_positions){
    ERR_FAIL_COND(octree==nullptr);
    Conn conn(conn_id);
    bool is_connected = false;
    const Point& a = points_buffer[conn.p.a];
    const Point& b = points_buffer[conn.p.b];
    const Vector3* a_control;
    const Vector3* b_control;
    if(has_point(conn.p.a) && has_point(conn.p.b)){
        for(int i=0; i < MAX_CONN; i++){
            if(std::abs(a.conn[i])==conn.p.b){
                is_connected = true;
                // means not negated a.conn[i]==conn.p.b 
                a_control = a.conn[i]==conn.p.b ? &a.out : &a.in;
            }
            if(std::abs(b.conn[i])==conn.p.a){
                is_connected = true;
                b_control = b.conn[i]==conn.p.a ? &b.out : &b.in;
            }
        }
    }
    auto it_cid32 = conn_id32.find(conn_id);
    //////////////////////////
    // Remove
    //////////////////////////
    if(!is_connected){
        if(it_cid32!=conn_id32.end()){
            _remove_conn_additional_points(it_cid32->value);
            conn_id32.erase(conn_id);
            conn_free_id32.push_back(it_cid32->value);
        }
        return;
    }
    ConnAdditional* __additional;
    //////////////////////////
    // if is new
    //////////////////////////
    if(it_cid32==conn_id32.end()){
        // grab a free index
        if(conn_free_id32.size()==0){
            _increase_conn_data_buffer_size(10);
        }
        ERR_FAIL_COND(conn_free_id32.size()==0);
        int32_t free_index = conn_free_id32[conn_free_id32.size()-1];
        conn_free_id32.remove_at(conn_free_id32.size()-1);
        _set_conn_id32(conn_id,free_index);
        __additional = conn_additional.ptrw() + free_index;
        Vector3 new_positions[CONN_ADDITIONAL_POINT_COUNT];
        _get_additional_points(new_positions,a.position,b.position,*a_control,*b_control);
        // Inserting and updating lod in classic mode
        int32_t base_octree_point_id = free_index*CONN_ADDITIONAL_POINT_COUNT;
        for(int p=0; p < CONN_ADDITIONAL_POINT_COUNT; p++){
            int32_t octree_point_id = -(base_octree_point_id + p);
            __additional->lod[p] = octree->get_pos_lod_classic(new_positions[p]);
            octree->insert_point(new_positions[p],octree_point_id,oct_id);
        }
        //// Recalculating conn LOD
        int8_t conn_lod = _calculate_conn_lod(conn_id);
        if(conn_lod > active_lod_limit || conn_lod==-1){
            active_conn.erase(conn_id);
            conn_list.erase(conn_id);
        } else {
            active_conn.insert(conn_id);
            conn_list.insert(conn_id,conn_lod);
        }
        return;
    }
    ERR_FAIL_COND_MSG(old_positions==nullptr,"old_position need for move");
    ///////////////////////////
    // update position (OR move)
    ///////////////////////////
    __additional = conn_additional.ptrw() + it_cid32->value;
    int32_t base_octree_point_id = it_cid32->value*CONN_ADDITIONAL_POINT_COUNT;
    ///////////// recalculating LOD
    int8_t conn_lod = _calculate_conn_lod(conn_id);
    if(conn_lod > active_lod_limit || conn_lod==-1){
        active_conn.erase(conn_id);
        conn_list.erase(conn_id);
    } else {
        active_conn.insert(conn_id);
        conn_list.insert(conn_id,conn_lod);
    }
    ////////////
    Vector3 new_positions[CONN_ADDITIONAL_POINT_COUNT];
    _get_additional_points(new_positions,a.position,b.position,*a_control,*b_control);
    for(int p=0; p < CONN_ADDITIONAL_POINT_COUNT; p++){
        MOctree::PointMoveReq mv_req;
        mv_req.p_id = -(base_octree_point_id + p);
        mv_req.oct_id = oct_id;
        mv_req.old_pos = old_positions[p];
        mv_req.new_pos = new_positions[p];
        __additional->lod[p] = octree->get_pos_lod_classic(old_positions[p]);
        octree->add_move_req(mv_req);
    }
}

void MCurve::_remove_conn_additional_points(const int32_t cid32) {
    ConnAdditional& __additional = conn_additional.ptrw()[cid32];
    int32_t base_oct_id = cid32*CONN_ADDITIONAL_POINT_COUNT;
    for(int a=0; a < CONN_ADDITIONAL_POINT_COUNT; a++){
        octree->remove_point_no_pos(-(base_oct_id+a),oct_id);
        __additional.lod[a] = -1; // reseting lod back to -1
        __additional.conn_id = 0;
    }
}

Node* MCurve::get_curve_user_by_name(String user_name){
    for(int i=0; i < curve_users.size(); i++){
        Node* n = curve_users.get_array()[i].value;
        ERR_CONTINUE(n==nullptr);
        if(n->get_name()==user_name && n->is_inside_tree()){
            return n;
        }
    }
    return nullptr;
}

int32_t MCurve::get_curve_users_id(Node* node){
    last_curve_id++;
    curve_users.insert(last_curve_id,node);
    return last_curve_id;
}
void MCurve::remove_curve_user_id(int32_t user_id){
    curve_users.erase(user_id);
    if(is_waiting_for_user){
        user_finish_process(user_id);
    }
}


int32_t MCurve::add_point(const Vector3& position,const Vector3& in,const Vector3& out, const int32_t prev_conn,Ref<MCurveOverrideData> point_override_data,Ref<MCurveOverrideData> conn_override_data){
    // In case of prev_conn==INVALID_POINT_INDEX this is a single point in space
    ERR_FAIL_COND_V(is_vec3_nan(position),INVALID_POINT_INDEX);
    ERR_FAIL_COND_V(is_vec3_nan(in),INVALID_POINT_INDEX);
    ERR_FAIL_COND_V(is_vec3_nan(out),INVALID_POINT_INDEX);
    ERR_FAIL_COND_V(!has_point(prev_conn) && prev_conn!=INVALID_POINT_INDEX,INVALID_POINT_INDEX);
    if(free_buffer_indicies.size() == 0){
        _increase_points_buffer_size(INC_POINTS_BUFFER_SIZE);
        ERR_FAIL_COND_V(free_buffer_indicies.size()==0,INVALID_POINT_INDEX);
    }
    int32_t free_index = free_buffer_indicies[free_buffer_indicies.size() - 1];
    Point new_point(position,in,out);
    if(octree){
        new_point.lod = octree->get_pos_lod_classic(new_point.position);
    }
    bool has_prev_point = has_point(prev_conn);
    Conn conn_prev(0);
    if(has_prev_point){ // if this statement not run this means this is a single point in space
        Point* prev_point = points_buffer.ptrw() + prev_conn;
        // Check if prev_conn has free slot, As we are creating new point my slot defently has free slot
        int8_t prev_conn_free_slot = -1;
        for(int8_t i=0; i < MAX_CONN ; i++){
            if(prev_point->conn[i]==INVALID_POINT_INDEX){
                prev_conn_free_slot = i;
                break;
            }
        }
        ERR_FAIL_COND_V_EDMSG(prev_conn_free_slot==-1,INVALID_POINT_INDEX,"Maximum number of conn is "+itos(MAX_CONN));
        prev_point->conn[prev_conn_free_slot] = free_index;
        new_point.conn[0] = -prev_conn;
        Conn __conn(prev_conn,free_index);
        conn_prev.id = __conn.id;
        /// Adding Override Entry if exist
        if(conn_override_data.is_valid()){
            set_override_entry(__conn.id,conn_override_data);
        }
    }
    if(new_point.lod <= active_lod_limit){
        active_points.insert(free_index);
    }
    points_buffer.set(free_index,new_point);
    free_buffer_indicies.remove_at(free_buffer_indicies.size() - 1);
    if(point_override_data.is_valid()){
        set_override_entry(free_index,point_override_data);
    }
    if(is_init_insert && octree != nullptr){
        octree->insert_point(position,free_index,oct_id);
    }
    if(has_prev_point){
        emit_signal("force_update_point",prev_conn);
    }
    emit_signal("force_update_point",free_index);
    if(conn_prev.id!=0){
        _update_conn_additional_points(conn_prev.id);
        emit_signal("force_update_connection",conn_prev.id);
    }
    return free_index;
}

/*
    mostly has only for undo-redo use
*/
int32_t MCurve::add_point_conn_point(const Vector3& position,const Vector3& in,const Vector3& out,const Array& conn_types,const PackedInt32Array& conn_points,Ref<MCurveOverrideData> point_override,TypedArray<MCurveOverrideData> conn_overrides){
    ERR_FAIL_COND_V(conn_types.size() != conn_points.size(),INVALID_POINT_INDEX);
    ERR_FAIL_COND_V(conn_overrides.size() != conn_points.size() && conn_overrides.size()!=0,INVALID_POINT_INDEX);
    ERR_FAIL_COND_V(conn_types.size() > MAX_CONN,INVALID_POINT_INDEX);
    ERR_FAIL_COND_V(is_vec3_nan(position),INVALID_POINT_INDEX);
    ERR_FAIL_COND_V(is_vec3_nan(in),INVALID_POINT_INDEX);
    ERR_FAIL_COND_V(is_vec3_nan(out),INVALID_POINT_INDEX);
    if(free_buffer_indicies.size() == 0){
        _increase_points_buffer_size(INC_POINTS_BUFFER_SIZE);
        ERR_FAIL_COND_V(free_buffer_indicies.size()==0,INVALID_POINT_INDEX);
    }
    int32_t free_index = free_buffer_indicies[free_buffer_indicies.size() - 1];
    Point new_points(position,in,out);
    if(octree){
        new_points.lod = octree->get_pos_lod_classic(new_points.position);
        if(new_points.lod <= active_lod_limit){
            active_points.insert(free_index);
        }
    }
    points_buffer.set(free_index,new_points);
    free_buffer_indicies.remove_at(free_buffer_indicies.size() - 1);
    // force update singal point will be sended by connect_points
    for(int8_t i=0; i < conn_points.size() ; i++){
        if(conn_points[i] == INVALID_POINT_INDEX){
            continue;
        }
        if(conn_overrides.size()==0){
            connect_points(free_index,conn_points[i],(ConnType)((int)conn_types[i]));
        } else {
            connect_points(free_index,conn_points[i],(ConnType)((int)conn_types[i]),conn_overrides[i]);
        }
    }
    /// Correcting connection types
    if(point_override.is_valid()){
        set_override_entry(free_index,point_override);
    }
    if(is_init_insert && octree != nullptr){
        octree->insert_point(position,free_index,oct_id);
    }
    return free_index;
}

void MCurve::clear_conn_cache_data(int64_t conn_id){
    baked_lines.erase(conn_id);
    conn_distances.erase(conn_id);
    conn_aabb.erase(conn_id);
}

int32_t MCurve::add_point_conn_split(int64_t conn_id,float t){
    ERR_FAIL_COND_V(!has_conn(conn_id),INVALID_POINT_INDEX);
    if(free_buffer_indicies.size() == 0){
        _increase_points_buffer_size(INC_POINTS_BUFFER_SIZE);
        ERR_FAIL_COND_V(free_buffer_indicies.size()==0,INVALID_POINT_INDEX);
    }
    Conn conn(conn_id);
    Point* a = points_buffer.ptrw() + conn.p.a;
    Point* b = points_buffer.ptrw() + conn.p.b;
    bool a_use_in = true;
    bool b_use_in = true;
    Vector3 a_control = a->in;
    Vector3 b_control = b->in;
    for(int8_t i=0; i < MAX_CONN; i++){
        if(a->conn[i] == conn.p.b){
            a_control = a->out;
            a_use_in = false;
        }
        if(b->conn[i] == conn.p.a){
            b_control = b->out;
            b_use_in = false;
        }
    }
    /// Creating npoint
    Point npoint;
    npoint.position =  a->position.bezier_interpolate(a_control,b_control,b->position,t);
    Vector3 tangent = get_conn_tangent(conn_id,t);
    Vector3 normal = _get_bezier_normal(a->position,b->position,a_control,b_control,t);
    float n_handl_len = normal.length()/24.0f;
    tangent.normalize();
    npoint.in = npoint.position - tangent*n_handl_len;
    npoint.out = npoint.position + tangent*n_handl_len;
    //// Removing current connection
    Ref<MCurveOverrideData> ov_data = get_override_entry(conn.id); // Caching override data to apply on two other created connections
    int freed_conn_index_a = -1;
    int freed_conn_index_b = -1;
    for(int8_t c=0; c < MAX_CONN; c++){
        if(abs(a->conn[c]) == conn.p.b){
            a->conn[c] = INVALID_POINT_INDEX; // Everything is positive here correcting connections types down
            freed_conn_index_a = c;
        }
        if(abs(b->conn[c]) == conn.p.a){
            b->conn[c] = INVALID_POINT_INDEX; // Everything is positive here correcting connections types down
            freed_conn_index_b = c;
        }
    }
    ERR_FAIL_COND_V(freed_conn_index_a==-1,INVALID_POINT_INDEX);
    ERR_FAIL_COND_V(freed_conn_index_b==-1,INVALID_POINT_INDEX);
    active_conn.erase(conn.id);
    conn_list.erase(conn.id);
    clear_conn_cache_data(conn.id);
    _update_conn_additional_points(conn.id);
    emit_signal("remove_connection",conn.id);
    //// Adding new conns and point
    if(free_buffer_indicies.size() == 0){
        _increase_points_buffer_size(INC_POINTS_BUFFER_SIZE);
        ERR_FAIL_COND_V(free_buffer_indicies.size()==0,INVALID_POINT_INDEX);
    }
    int32_t npid = free_buffer_indicies[free_buffer_indicies.size() - 1];
    free_buffer_indicies.remove_at(free_buffer_indicies.size() - 1);
    // connecting
    npoint.conn[0] = -conn.p.a; // using in to connect to a (this is why negetive)
    npoint.conn[1] = conn.p.b;  // using out to connect to b
    a->conn[freed_conn_index_a] = a_use_in ? -npid : npid;
    b->conn[freed_conn_index_b] = b_use_in ? -npid : npid;
    if(octree){
        npoint.lod = octree->get_pos_lod_classic(npoint.position);
        if(npoint.lod <= active_lod_limit){
            active_points.insert(npid);
        }
    }
    points_buffer.set(npid,npoint);
    ////// New Conn IDs
    Conn nconn_a(conn.p.a,npid);
    Conn nconn_b(conn.p.b,npid);
    _update_conn_additional_points(nconn_a.id);
    _update_conn_additional_points(nconn_b.id);
    ///////// putting same override data into new connections
    set_override_entry(nconn_a.id,ov_data);
    set_override_entry(nconn_b.id,ov_data);
    //////////////////////////////////
    emit_signal("force_update_point",npid);
    emit_signal("force_update_point",conn.p.a);
    emit_signal("force_update_point",conn.p.b);
    emit_signal("force_update_connection",nconn_a.id);
    emit_signal("force_update_connection",nconn_b.id);
    if(is_init_insert && octree != nullptr){
        octree->insert_point(npoint.position,npid,oct_id);
    }
    return npid;
}
/*
    ConnType conn_a_type = a_use_in ? IN_IN : OUT_IN;
    ConnType conn_b_type = b_use_in ? OUT_IN : OUT_OUT;
    Array conn_types;
    conn_types.resize(2);
    conn_types[0] = conn_a_type;
    conn_types[1] = conn_b_type;
    PackedInt32Array points = {conn.p.a,conn.p.b};
    int32_t pid = add_point_conn_point(npos,nin,nout,conn_types,points);
*/
bool MCurve::connect_points(int32_t p0,int32_t p1,ConnType con_type,Ref<MCurveOverrideData> conn_ov_data){
    Conn conn(p0,p1); // Making the order right
    ERR_FAIL_COND_V(has_conn(conn.id), false);
    Point* a = points_buffer.ptrw() + conn.p.a;
    Point* b = points_buffer.ptrw() + conn.p.b;
    int8_t a_conn_index = -1;
    int8_t b_conn_index = -1;
    // Setting connections
    for(int8_t c=0; c < MAX_CONN; c++){
        if(a->conn[c] == INVALID_POINT_INDEX && a_conn_index == -1){
            a->conn[c] = conn.p.b; // Everything is positive here correcting connections types down
            a_conn_index = c;
        }
        if(b->conn[c] == INVALID_POINT_INDEX  && b_conn_index == -1){
            b->conn[c] = conn.p.a; // Everything is positive here correcting connections types down
            b_conn_index = c;
        }
    }
    // Removing Connection in case of error of MAX_CONN
    if(a_conn_index==-1 || b_conn_index==-1){
        if(a_conn_index!=-1){
            a->conn[a_conn_index] = INVALID_POINT_INDEX;
        }
        if(b_conn_index!=-1){
            b->conn[b_conn_index] = INVALID_POINT_INDEX;
        }
        ERR_FAIL_V_MSG("MAX Connection reached",false);
        return false;
    }

    // In case there is not error and both are set correcting types
    if(con_type == CONN_NONE){
        con_type = OUT_IN;
    }
    switch (con_type)
    {
    case OUT_IN:
        b->conn[b_conn_index] *= -1;
        break;
    case IN_OUT:
        a->conn[a_conn_index] *= -1;
        break;
    case IN_IN:
        a->conn[a_conn_index] *= -1;
        b->conn[b_conn_index] *= -1;
        break;
    //case OUT_OUT: // Nothing to do here has both will remain positive
    //    break;
    default: break;
    }
    /// Calculating LOD and force updateds
    int8_t clod = a->lod < b->lod ? a->lod : b->lod;
    conn_list.insert(conn.id,clod);
    if(clod <= active_lod_limit){
        active_conn.insert(conn.id);
    }
    if(conn_ov_data.is_valid()){
        set_override_entry(conn.id,conn_ov_data);
    }
    _update_conn_additional_points(conn.id);
    emit_signal("force_update_point",conn.p.a);
    emit_signal("force_update_point",conn.p.b);
    emit_signal("force_update_connection",conn.id);
    emit_signal("curve_updated");
    return true;
}

bool MCurve::disconnect_conn(int64_t conn_id){
    Conn cc(conn_id);
    return disconnect_points(cc.p.a,cc.p.b);
}

bool MCurve::disconnect_points(int32_t p0,int32_t p1){
    ERR_FAIL_COND_V(!has_point(p0), false);
    ERR_FAIL_COND_V(!has_point(p1), false);
    Point* a = points_buffer.ptrw() + p0;
    Point* b = points_buffer.ptrw() + p1;
    bool is_removed = false;
    for(int8_t c=0; c < MAX_CONN; c++){
        if(abs(a->conn[c]) == p1){
            a->conn[c] = INVALID_POINT_INDEX; // Everything is positive here correcting connections types down
            is_removed = true;
        }
        if(abs(b->conn[c]) == p0){
            b->conn[c] = INVALID_POINT_INDEX; // Everything is positive here correcting connections types down
            is_removed = true;
        }
    }
    Conn conn(p0,p1);
    conn_list.erase(conn.id);
    active_conn.erase(conn.id);
    clear_conn_cache_data(conn.id);
    _update_conn_additional_points(conn.id);
    emit_signal("curve_updated");
    emit_signal("remove_connection",conn.id);
    return is_removed;
}


void MCurve::remove_point(const int32_t point_index){
    ERR_FAIL_COND(!has_point(point_index));
    const Point* p = points_buffer.ptr() + point_index;
    // Removing from conn
    Vector<int64_t> removed_conns;
    for(int8_t i=0; i < MAX_CONN; i++){
        if(p->conn[i]!=INVALID_POINT_INDEX){
            int32_t conn_point_id = std::abs(p->conn[i]);
            ERR_FAIL_INDEX(conn_point_id, points_buffer.size());
            Conn conn(point_index,conn_point_id);
            active_conn.erase(conn.id);
            conn_list.erase(conn.id);
            clear_conn_cache_data(conn.id);
            Point* conn_p = points_buffer.ptrw() + conn_point_id;
            for(int8_t c=0; c < MAX_CONN; c++){
                if(std::abs(conn_p->conn[c]) == point_index){
                    conn_p->conn[c] = INVALID_POINT_INDEX;
                    break;
                }
            }
            removed_conns.push_back(conn.id);
        }
    }
    if(is_init_insert){
        ERR_FAIL_COND(octree==nullptr);
        octree->remove_point(point_index,p->position,oct_id);
    }
    free_buffer_indicies.push_back(point_index);
    active_points.erase(point_index);
    for(int8_t i=0; i < MAX_CONN; i++){
        if(p->conn[i]!=INVALID_POINT_INDEX){
            emit_signal("force_update_point",std::abs(p->conn[i]));
        }
    }
    for(int c=0; c < removed_conns.size(); c++){
        _update_conn_additional_points(removed_conns[c]);
        emit_signal("remove_connection",removed_conns[c]);
    }
    emit_signal("curve_updated");
    emit_signal("remove_point",point_index);
}

void MCurve::remove_points(const PackedInt32Array &pids) {
    HashSet<int64_t> rm_conns;
    HashSet<int32_t> rm_oct_points;
    for(int32_t pid : pids){
        ERR_CONTINUE(!has_point(pid));
        rm_oct_points.insert(pid);
        const Point& point = points_buffer[pid];
        ////////////////// adding conn
        for(int i=0; i < MAX_CONN; i++){
            if(point.conn[i]!=0){
                Conn conn(pid,std::abs(point.conn[i]));
                active_conn.erase(conn.id);
                conn_list.erase(conn.id);
                baked_lines.erase(conn.id);
                conn_aabb.erase(conn.id);
                if(!rm_conns.has(conn.id)){
                    rm_conns.insert(conn.id);
                    //////////// Adding extra conn points
                    auto c32_it = conn_id32.find(conn.id);
                    if(c32_it!=conn_id32.end()){
                        int32_t cid32 = c32_it->value;
                        ConnAdditional& __additional = conn_additional.ptrw()[cid32];
                        int32_t base_oct_id = cid32*CONN_ADDITIONAL_POINT_COUNT;
                        for(int a=0; a < CONN_ADDITIONAL_POINT_COUNT; a++){
                            rm_oct_points.insert(-(base_oct_id+a));
                            __additional.lod[a] = -1; // reseting lod back to -1
                            __additional.conn_id = 0;
                        }
                        conn_id32.remove(c32_it);
                        conn_free_id32.push_back(c32_it->value);
                    }
                    ////////////END  Adding extra conn points
                }
            }
        }
        //////////////////End adding conn
        free_buffer_indicies.push_back(pid);
        active_points.erase(pid);
    }
    /// End adding points
    if(octree){
        bool res = octree->remove_points(rm_oct_points,oct_id);
        if(!res){
            WARN_PRINT(itos(rm_oct_points.size()) + " Points can't be find to be removed!");
        }
    }
}

void MCurve::clear_points(){
    if(octree){
        octree->clear_oct_id(oct_id);
    }
    points_buffer.clear();
    free_buffer_indicies.clear();
    last_curve_id = 0;
    conn_free_id32.clear();
    if(is_init_insert){
        ERR_FAIL_COND(octree==nullptr);
        octree->clear_oct_id(oct_id);
    }
    for(int i=active_points.size() - 1; i >= 0; i--){
        int64_t cid = active_points[i];
        active_points.erase(cid);
    }
    for(int i=active_conn.size()-1;i>=0;i--){
        active_conn.erase(active_conn[active_conn.size()-1]);
    }
    for(int i=active_points.size()-1;i>=0;i--){
        active_points.erase(active_points[active_points.size()-1]);
    }
    conn_aabb.clear();
    conn_list.clear();
    conn_distances.clear();
    baked_lines.clear();
    conn_id32.clear();
    emit_signal("recreate");
}

void MCurve::init_insert(){
    if(is_init_insert){
        return;
    }
    ERR_FAIL_COND_MSG(octree==nullptr,"No octree asigned to update curves, please asign a octree by calling enable_as_curve_updater and restart Godot");
    // inserting points into octree
    PackedVector3Array positions;
    PackedInt32Array ids;
    HashSet<int64_t> handled_conn; // for additional conn positions
    for (int i=0; i < points_buffer.size(); i++){
        if(free_buffer_indicies.has(i) || i == INVALID_POINT_INDEX){
            continue;
        }
        positions.push_back(points_buffer[i].position);
        ids.push_back(i);
        /// Aditional conn positions
        for(int c=0; c < MAX_CONN; c++){
            if(points_buffer[i].conn[c]==0){
                continue;
            }
            Conn conn(i,std::abs(points_buffer[i].conn[c]));
            if(handled_conn.has(conn.id)){
                continue;
            }
            _init_conn_additional_points(conn.id,positions,ids);
            handled_conn.insert(conn.id);
        }
    }
    oct_id = octree->get_oct_id();
    is_init_insert = true;
    octree->connect("update_finished", Callable(this,"_octree_update_finish"));
    octree->insert_points(positions,ids,oct_id);
}

void MCurve::_octree_update_finish(){
    Vector<MOctree::PointUpdate> update_info = octree->get_point_update(oct_id);
    if(update_info.size()==0){
        octree->call_deferred("point_process_finished",oct_id);
        return;
    }
    conn_update.clear();
    point_update.clear();
    Point* ptrw = points_buffer.ptrw();
    HashSet<int64_t> updated_conn_set;
    for(int i=0; i < update_info.size(); i++){
        ////////////////////////////////////////////
        /////////// Updating Additional Conn Points
        ////////////////////////////////////////////
        if(update_info[i].id < 0){
            int32_t oct_point_id = -update_info[i].id;
            int32_t cid32 = (oct_point_id/CONN_ADDITIONAL_POINT_COUNT);
            ERR_FAIL_INDEX(cid32,conn_additional.size());
            int32_t oindex = oct_point_id%CONN_ADDITIONAL_POINT_COUNT;
            conn_additional.ptrw()[cid32].lod[oindex] = update_info[i].lod;
            updated_conn_set.insert(conn_additional.ptrw()[cid32].conn_id);
            Conn conn(conn_additional.ptrw()[cid32].conn_id);
            continue;
        }
        ////////////////////////////////////////////
        /////////// Updating Points
        ////////////////////////////////////////////
        ERR_CONTINUE(!has_point(update_info[i].id));
        // see if the lod is not active remove that!
        Point* p = points_buffer.ptrw() + update_info[i].id;
        // Updating LOD of point
        // Updating active points
        PointUpdateInfo point_update_info;
        if(update_info[i].lod > active_lod_limit){
            if(p->lod > active_lod_limit){
                continue; // Same as before was deactive
            }
            active_points.erase(update_info[i].id);
            point_update_info.current_lod = -1;
        } else {
            active_points.insert(update_info[i].id);
            point_update_info.current_lod = update_info[i].lod;
        }
        ////// Creating Point Update info
        point_update_info.last_lod = update_info[i].last_lod > active_lod_limit ? -1 : update_info[i].last_lod;
        point_update_info.point_id = update_info[i].id;
        point_update.push_back(point_update_info);
        //updated_points.push_back(update_info[i].id);
        p->lod = update_info[i].lod;
        for(int t=0; t < MAX_CONN; t++){
            if(p->conn[t]!=0){
                Conn conn(update_info[i].id,std::abs(p->conn[t]));
                updated_conn_set.insert(conn.id);
            }
        }
    }
    for(HashSet<int64_t>::Iterator it=updated_conn_set.begin();it!=updated_conn_set.end();++it){
        int64_t conn_id = *(it);
        int8_t new_conn_lod = _calculate_conn_lod(conn_id);
        if(new_conn_lod > active_lod_limit){
            new_conn_lod = -1;
        }
        auto it_conn_list = conn_list.find(conn_id);
        int8_t old_conn_lod = it_conn_list!=conn_list.end() ? it_conn_list->value : -1;
        if(new_conn_lod==old_conn_lod){
            continue;
        }
        if(new_conn_lod == -1){
            conn_list.erase(conn_id);
            active_conn.erase(conn_id);
            clear_conn_cache_data(conn_id);
        } else {
            conn_list.insert(conn_id,new_conn_lod);
            active_conn.insert(conn_id);
        }
        ConnUpdateInfo cuinfo;
        cuinfo.current_lod = new_conn_lod;
        cuinfo.last_lod = old_conn_lod;
        cuinfo.conn_id = conn_id;
        conn_update.push_back(cuinfo);
    }
    for(int i=0; i < curve_users.size();i++){
        processing_users.insert(curve_users.get_array()[i].key);
    }
    emit_signal("curve_updated");
    is_waiting_for_user = true;
    emit_signal("connection_updated"); // for both point and conn
    if(curve_users.size()==0){
        octree->call_deferred("point_process_finished",oct_id);
    }
}

void MCurve::user_finish_process(int32_t user_id){
    ERR_FAIL_COND(!is_waiting_for_user);
    processing_users.erase(user_id);
    if(processing_users.size()==0){
        is_waiting_for_user = false;
        octree->call_deferred("point_process_finished",oct_id);
    }
}

int64_t MCurve::get_conn_id(int32_t p0, int32_t p1) const{
    Conn c(p0,p1);
    return c.id;
}

PackedInt64Array MCurve::get_conn_next(int64_t conn_id) const{
    PackedInt64Array out;
    Conn conn(conn_id);
    ERR_FAIL_COND_V(!has_point(conn.p.b),out);
    const Point& p = points_buffer[conn.p.b];
    for(int i=0; i < MAX_CONN; i++){
        int32_t other = std::abs(p.conn[i]);
        if(other!=conn.p.a){
            Conn cc(conn.p.b,other);
            out.push_back(cc.id);
        }
    }
    return out;
}

PackedInt64Array MCurve::get_conn_prev(int64_t conn_id) const{
    PackedInt64Array out;
    Conn conn(conn_id);
    ERR_FAIL_COND_V(!has_point(conn.p.a),out);
    const Point& p = points_buffer[conn.p.a];
    for(int i=0; i < MAX_CONN; i++){
        int32_t other = std::abs(p.conn[i]);
        if(other!=conn.p.b){
            Conn cc(conn.p.b,other);
            out.push_back(cc.id);
        }
    }
    return out;
}

PackedInt32Array MCurve::get_conn_points(int64_t conn_id) const{
    Conn conn(conn_id);
    PackedInt32Array ids = {conn.p.a,conn.p.b};
    return ids;
}

PackedInt64Array MCurve::get_conn_ids_exist(const PackedInt32Array points) const{
    PackedInt64Array out;
    if(points.size() < 2){
        return out;
    }
    for(int i=0; i < points.size() - 1; i++){
        int32_t pi = points[i];
        for(int j=i+1; j < points.size(); j++){
            int32_t pj = points[j];
            Conn conn(pi,pj);
            if(!out.has(conn.id) && has_conn(conn.id)){
                out.push_back(conn.id);
            }
        }
    }
    return out;
}

int8_t MCurve::get_conn_lod(int64_t conn_id) const{
    auto it = conn_list.find(conn_id);
    return it==conn_list.end() ? -1 : it->value;
}

int8_t MCurve::get_point_lod(int64_t p_id) const{
    ERR_FAIL_COND_V(!has_point(p_id),-1);
    int8_t out = points_buffer[p_id].lod;
    if(out > active_lod_limit){
        return -1;
    }
    return out;
}

PackedInt32Array MCurve::get_active_points() const{
    PackedInt32Array out;
    out.resize(active_points.size());
    for(int i=0; i < out.size(); i++){
        out.set(i,active_points[i]);
    }
    return out;
}

PackedVector3Array MCurve::get_active_points_positions() const{
    PackedVector3Array out;
    out.resize(active_points.size());
    for(int i=0; i < out.size(); i++){
        int32_t p_index = active_points[i];
        ERR_FAIL_INDEX_V(p_index,points_buffer.size(),out);
        out.set(i,points_buffer[p_index].position);
    }
    return out;
}

PackedInt64Array MCurve::get_active_conns() const{
    PackedInt64Array out;
    out.resize(active_conn.size());
    for(int i=0; i < active_conn.size(); i++){
        out.set(i,active_conn[i]);
    }
    return out;
}

PackedVector3Array MCurve::get_conn_baked_points(int64_t input_conn){
    PackedVector3Array out;
    Conn conn(input_conn);
    ERR_FAIL_COND_V(!has_point(conn.p.a),out);
    ERR_FAIL_COND_V(!has_point(conn.p.b),out);
    const Point* a = points_buffer.ptr() + conn.p.a;
    const Point* b = points_buffer.ptr() + conn.p.b;
    // First we assume control is negetive and then in loop if we found positive we change that
    Vector3 a_control = a->in; 
    Vector3 b_control = b->in;
    for(int8_t i=0; i < MAX_CONN; i++){
        if(a->conn[i] == conn.p.b){
            a_control = a->out;
        }
        if(b->conn[i] == conn.p.a){
            b_control = b->out;
        }
    }
    float lenght = get_length_between_basic(a,b,a_control,b_control);
    int pcount = lenght/bake_interval; // This is only for middle points
    pcount = pcount == 0 ? 1 : pcount;
    out.resize(pcount + 1); // including start and end pos
    out.set(0,a->position);
    float nl = 1.0 / (float)pcount; // normalized_interval
    for(int i=1; i < pcount; i++){
        out.set(i,a->position.bezier_interpolate(a_control,b_control,b->position,i*nl));
    }
    out.set(pcount,b->position);
    return out;
}

PackedVector3Array MCurve::get_conn_baked_line(int64_t input_conn){
    if(baked_lines.has(input_conn)){
        return baked_lines[input_conn];
    }
    PackedVector3Array points = get_conn_baked_points(input_conn);
    PackedVector3Array line;
    line.resize((points.size()-1)*2);
    int lc = 0;
    for(int i=0; i < points.size() - 1; i++){
        line.set(lc,points[i]);
        lc++;
        line.set(lc,points[i+1]);
        lc++;
    }
    baked_lines.insert(input_conn,line);
    return line;
}

bool MCurve::has_point(int p_index) const{
    if(p_index < 1 || p_index >= points_buffer.size() || free_buffer_indicies.has(p_index)){ // As we don't have index 0
        return false;
    }
    return true;
}

bool MCurve::has_conn(int64_t conn_id) const{
    Conn conn(conn_id);
    if(!has_point(conn.p.a) || !has_point(conn.p.b)){
        return false;
    }
    const Point* a = points_buffer.ptr() + conn.p.a;
    const Point* b = points_buffer.ptr() + conn.p.b;
    bool has_in_a = false;
    bool has_in_b = false;
    for(int8_t i=0; i < MAX_CONN; i++){
        if(abs(a->conn[i]) == conn.p.b){
            has_in_a = true;
        }
        if(abs(b->conn[i]) == conn.p.a){
            has_in_b = true;
        }
    }
    return has_in_a && has_in_b;
}

bool MCurve::is_point_connected(int32_t pa,int32_t pb) const{
    Conn conn(pa,pb);
    return has_conn(conn.id);
}

MCurve::ConnType MCurve::get_conn_type(int64_t conn_id) const{
    Conn c(conn_id); // This make order of smaller and bigger right
    if(!has_point(c.p.a) || !has_point(c.p.b)){
        return CONN_NONE;
    }
    const Point* a = points_buffer.ptr() + c.p.a;
    const Point* b = points_buffer.ptr() + c.p.b;
    int a_b_sign = 0;
    int b_a_sign = 0;
    for(int8_t i=0; i < MAX_CONN; i++){
        if(abs(a->conn[i]) == c.p.b){
            a_b_sign = a->conn[i] > 0 ? 1 : -1;
        }
        if(abs(b->conn[i]) == c.p.a){
            b_a_sign = b->conn[i] > 0 ? 1 : -1;
        }
    }
    if(a_b_sign == 1 && b_a_sign -1){
        return OUT_IN;
    }
    if(a_b_sign == -1 && b_a_sign == 1){
        return IN_OUT;
    }
    if(a_b_sign == -1 && b_a_sign == -1){
        return IN_IN;
    }
    if(a_b_sign == 1 && b_a_sign == 1){
        return OUT_OUT;
    }
    return CONN_NONE;
}

Array MCurve::get_point_conn_types(int32_t p_index) const{
    Array out;
    ERR_FAIL_COND_V(!has_point(p_index),out);
    const Point* p = points_buffer.ptr() + p_index;
    for(int8_t i=0; i < MAX_CONN ; i++){
        Conn c(p_index,abs(p->conn[i]));
        out.push_back(get_conn_type(c.id));
    }
    return out;
}

int MCurve::get_point_conn_count(int32_t p_index) const{
    int out = 0;
    ERR_FAIL_COND_V(!has_point(p_index),out);
    const Point* p = points_buffer.ptr() + p_index;
    for(int8_t i=0; i < MAX_CONN ; i++){
        if(p->conn[i]!=0){
            out++;
        }
    }
    return out;
}

PackedInt32Array MCurve::get_point_conn_points_exist(int32_t p_index) const{
    PackedInt32Array out;
    ERR_FAIL_COND_V(!has_point(p_index),out);
    const Point* p = points_buffer.ptr() + p_index;
    for(int8_t i=0; i < MAX_CONN ; i++){
        if(p->conn[i] !=0){
            out.push_back(abs(p->conn[i]));
        }
    }
    return out;
}

PackedInt32Array MCurve::get_point_conn_points(int32_t p_index) const{
    PackedInt32Array out;
    ERR_FAIL_COND_V(!has_point(p_index),out);
    const Point* p = points_buffer.ptr() + p_index;
    for(int8_t i=0; i < MAX_CONN ; i++){
        out.push_back(abs(p->conn[i]));
    }
    return out;
}

TypedArray<MCurveOverrideData> MCurve::get_point_conn_overrides(int32_t p_index) const{
    TypedArray<MCurveOverrideData> out;
    ERR_FAIL_COND_V(!has_point(p_index),out);
    const Point* p = points_buffer.ptr() + p_index;
    for(int8_t i=0; i < MAX_CONN ; i++){
        Conn conn(p_index,abs(p->conn[i]));
        out.push_back(get_override_entry(conn.id));
    }
    return out;
}

VSet<int32_t> MCurve::get_point_conn_points_recursive(int32_t p_index) const {
    VSet<int32_t> out_set;
    ERR_FAIL_COND_V(!has_point(p_index),out_set);
    HashSet<int32_t> processed_points;
    PackedInt32Array stack = get_point_conn_points_exist(p_index);
    processed_points.insert(p_index);
    while (stack.size()!=0)
    {
        int32_t current_index = stack[stack.size()-1];
        const Point* current_point = points_buffer.ptr() + current_index;
        stack.remove_at(stack.size()-1);
        out_set.insert(current_index);
        processed_points.insert(current_index);
        for(int i=0;i < MAX_CONN; i++){
            if(current_point->conn[i] != 0){
                int32_t cp = std::abs(current_point->conn[i]);
                if(!processed_points.has(cp)){
                    stack.push_back(cp);
                }
            }
        }
    }
    out_set.insert(p_index);
    return out_set;
}

PackedInt32Array MCurve::get_point_conn_points_recursive_gd(int32_t p_index) const{
    VSet<int32_t> psets = get_point_conn_points_recursive(p_index);
    PackedInt32Array out;
    out.resize(psets.size());
    for(int i=0; i < out.size(); i++){
        out.set(i,psets[i]);
    }
    return out;
}

PackedInt64Array MCurve::get_point_conns(int32_t p_index) const{
    PackedInt64Array out;
    ERR_FAIL_COND_V(!has_point(p_index),out);
    const Point* p = points_buffer.ptr() + p_index;
    for(int8_t i=0; i < MAX_CONN ; i++){
        if(p->conn[i]!=0){
            int32_t other_index = std::abs(p->conn[i]);
            Conn cc(p_index,other_index);
            out.push_back(cc.id);
        }
    }
    return out;
}

Dictionary MCurve::get_point_conns_override_entries(int32_t p_index) const{
    Dictionary out;
    ERR_FAIL_COND_V(!has_point(p_index),out);
    const Point* p = points_buffer.ptr() + p_index;
    for(int8_t i=0; i < MAX_CONN ; i++){
        if(p->conn[i]!=0){
            int32_t other_index = std::abs(p->conn[i]);
            Conn cc(p_index,other_index);
            out[cc.id] = get_override_entry(cc.id);;
        }
    }
    return out;
}

PackedInt64Array MCurve::get_point_conns_inc_neighbor_points(int32_t p_index) const{
    PackedInt64Array out;
    ERR_FAIL_COND_V(!has_point(p_index),out);
    const Point* p = points_buffer.ptr() + p_index;
    PackedInt32Array conn_points;
    for(int8_t i=0; i < MAX_CONN ; i++){
        if(p->conn[i]!=0){
            int32_t other_index = std::abs(p->conn[i]);
            conn_points.push_back(other_index);
            Conn cc(p_index,other_index);
            out.push_back(cc.id);
        }
    }
    for(int j=0; j < conn_points.size(); j++){
        const Point* op = points_buffer.ptr() + conn_points[j];
        for(int8_t i=0; i < MAX_CONN ; i++){
            int32_t other_index = std::abs(op->conn[i]);
            if(other_index!=0 && other_index!=p_index){
                Conn cc(conn_points[j],other_index);
                if(true){
                    out.push_back(cc.id);
                }
            }
        }
    }
    return out;
}

PackedInt64Array MCurve::growed_conn(PackedInt64Array conn_ids) const{
    PackedInt64Array out;
    for(int i=0; i < conn_ids.size(); i++){
        Conn cc(conn_ids[i]);
        PackedInt64Array pc = get_point_conns(cc.p.a);
        pc.append_array(get_point_conns(cc.p.b));
        for(int j=0; j < pc.size(); j++){
            if(out.find(pc[j]==-1)){
                out.push_back(pc[j]);
            }
        }
    }
    return out;
}

Vector3 MCurve::get_point_position(int p_index){
    ERR_FAIL_COND_V(!has_point(p_index),Vector3());
    return points_buffer.get(p_index).position;
}
Vector3 MCurve::get_point_in(int p_index){
    ERR_FAIL_COND_V(!has_point(p_index),Vector3());
    return points_buffer.get(p_index).in;
}
Vector3 MCurve::get_point_out(int p_index){
    ERR_FAIL_COND_V(!has_point(p_index),Vector3());
    return points_buffer.get(p_index).out;
}
float MCurve::get_point_tilt(int p_index){
    ERR_FAIL_COND_V(!has_point(p_index),0.0f);
    return points_buffer.get(p_index).tilt;
}

void MCurve::set_point_tilt(int p_index,float input){
    ERR_FAIL_COND(!has_point(p_index));
    points_buffer.ptrw()[p_index].tilt = input;
}

float MCurve::get_point_scale(int p_index){
    ERR_FAIL_COND_V(!has_point(p_index),1.0);
    return points_buffer.get(p_index).scale;
}

void MCurve::set_point_scale(int p_index,float input){
    ERR_FAIL_COND(!has_point(p_index));
    points_buffer.ptrw()[p_index].scale = input;
}


void MCurve::commit_point_update(int p_index){
    ERR_FAIL_COND(!has_point(p_index));
    const Point* p = points_buffer.ptr() + p_index;
    VSet<int64_t> u_conn;
    VSet<int32_t> u_point;
    u_point.insert(p_index);
    for(int8_t i=0; i < MAX_CONN ; i++){
        int32_t pp = abs(p->conn[i]);
        if(pp!=0){
            ERR_CONTINUE(!has_point(p_index));
            u_point.insert(pp);
            Conn conn(pp,p_index);
            u_conn.insert(conn.id);
        }
    }
    for(int i=0; i < u_conn.size(); i++){
        // This will force them to rebake if the will needed later
        clear_conn_cache_data(u_conn[i]);
    }
    // Updating points
    for(int8_t i=0; i < u_point.size() ; i++){
        emit_signal("force_update_point",u_point[i]);
    }
    // updating connections
    for(int i=0; i < u_conn.size(); i++){
        emit_signal("force_update_connection",u_conn[i]);
    }
}

void MCurve::commit_conn_update(int64_t conn_id){
    ERR_FAIL_COND(!has_conn(conn_id));
    clear_conn_cache_data(conn_id);
    emit_signal("force_update_connection",conn_id);
}

Vector3 MCurve::get_conn_position(int64_t conn_id,float t){
    ERR_FAIL_COND_V(!has_conn(conn_id), Vector3());
    Conn conn(conn_id);
    const Point* a = points_buffer.ptr() + conn.p.a;
    const Point* b = points_buffer.ptr() + conn.p.b;
    Vector3 a_control = a->in; 
    Vector3 b_control = b->in;
    for(int8_t i=0; i < MAX_CONN; i++){
        if(a->conn[i] == conn.p.b){
            a_control = a->out;
        }
        if(b->conn[i] == conn.p.a){
            b_control = b->out;
        }
    }
    return a->position.bezier_interpolate(a_control,b_control,b->position,t);
}

////////
// https://iquilezles.org/articles/bezierbbox/
////////
AABB MCurve::get_conn_aabb(int64_t conn_id){
    ERR_FAIL_COND_V(!has_conn(conn_id),AABB());
    {
        auto it = conn_aabb.find(conn_id);
        if(it!=conn_aabb.end()){
            return it->value;
        }
    }
    Conn cc(conn_id);
    const Point* a = points_buffer.ptr() + cc.p.a;
    const Point* b = points_buffer.ptr() + cc.p.b;
    Vector3 a_control = a->in; 
    Vector3 b_control = b->in;
    for(int8_t i=0; i < MAX_CONN; i++){
        if(a->conn[i] == cc.p.b){
            a_control = a->out;
        }
        if(b->conn[i] == cc.p.a){
            b_control = b->out;
        }
    }
    //////// min max
    Vector3 mi = a->position.min(b->position);
    Vector3 ma = a->position.max(b->position);

    Vector3 _c = a_control - a->position;
    Vector3 _b = a->position - 2.0*a_control + b_control;
    Vector3 _a = -1.0*a->position + 3.0*a_control - 3.0*b_control + b->position;

    Vector3 h = _b*_b - _a*_c;
    if(h.x > 0.0){
        h.x = sqrt(h.x);
        float t = (-_b.x - h.x)/_a.x;
        if(t > 0.0 && t < 1.0){
            float s = 1.0f - t;
            float q = s*s*s*a->position.x + 3.0*s*s*t*a_control.x + 3.0*s*t*t*b_control.x + t*t*t*b->position.x;
            mi.x = MIN(mi.x,q);
            ma.x = MAX(ma.x,q);
        }
        t = (-_b.x + h.x)/_a.x;
        if(t > 0.0 && t < 1.0){
            float s = 1.0f - t;
            float q = s*s*s*a->position.x + 3.0*s*s*t*a_control.x + 3.0*s*t*t*b_control.x + t*t*t*b->position.x;
            mi.x = MIN(mi.x,q);
            ma.x = MAX(ma.x,q);
        }
    }
    if(h.y > 0.0){
        h.y = sqrt(h.y);
        float t = (-_b.y - h.y)/_a.y;
        if(t > 0.0 && t < 1.0){
            float s = 1.0f - t;
            float q = s*s*s*a->position.y + 3.0*s*s*t*a_control.y + 3.0*s*t*t*b_control.y + t*t*t*b->position.y;
            mi.y = MIN(mi.y,q);
            ma.y = MAX(ma.y,q);
        }
        t = (-_b.y + h.y)/_a.y;
        if(t > 0.0 && t < 1.0){
            float s = 1.0f - t;
            float q = s*s*s*a->position.y + 3.0*s*s*t*a_control.y + 3.0*s*t*t*b_control.y + t*t*t*b->position.y;
            mi.y = MIN(mi.y,q);
            ma.y = MAX(ma.y,q);
        }
    }
    if(h.z > 0.0){
        h.z = sqrt(h.z);
        float t = (-_b.z - h.z)/_a.z;
        if(t > 0.0 && t < 1.0){
            float s = 1.0f - t;
            float q = s*s*s*a->position.z + 3.0*s*s*t*a_control.z + 3.0*s*t*t*b_control.z + t*t*t*b->position.z;
            mi.z = MIN(mi.z,q);
            ma.z = MAX(ma.z,q);
        }
        t = (-_b.z + h.z)/_a.z;
        if(t > 0.0 && t < 1.0){
            float s = 1.0f - t;
            float q = s*s*s*a->position.z + 3.0*s*s*t*a_control.z + 3.0*s*t*t*b_control.z + t*t*t*b->position.z;
            mi.z = MIN(mi.z,q);
            ma.z = MAX(ma.z,q);
        }
    }
    AABB faabb(mi, ma - mi);
    conn_aabb.insert(conn_id,faabb);
    return faabb;
}

AABB MCurve::get_conns_aabb(const PackedInt64Array& conn_ids){
    ERR_FAIL_COND_V(conn_ids.size()==0,AABB());
    AABB faabb = get_conn_aabb(conn_ids[0]);
    for(int i=1; i < conn_ids.size(); i++){
        AABB taabb = get_conn_aabb(conn_ids[i]);
        faabb = faabb.merge(taabb);
    }
    return faabb;
}

float MCurve::get_closest_ratio_to_point(int64_t conn_id,Vector3 pos) const {
    ERR_FAIL_COND_V(!has_conn(conn_id), 0.0f);
    Conn conn(conn_id);
    const Point* a = points_buffer.ptr() + conn.p.a;
    const Point* b = points_buffer.ptr() + conn.p.b;
    Vector3 a_control = a->in; 
    Vector3 b_control = b->in;
    for(int8_t i=0; i < MAX_CONN; i++){
        if(a->conn[i] == conn.p.b){
            a_control = a->out;
        }
        if(b->conn[i] == conn.p.a){
            b_control = b->out;
        }
    }
    real_t low = 0.0f;
    real_t high = 1.0;
    while (high - low > 0.005f)
    {
        real_t step = (high - low)/8.0;
        //samples
        real_t s[9] {low,
                    low + step,
                    low + step * 2.0f,
                    low + step * 3.0f,
                    low + step * 4.0f,
                    low + step * 5.0f,
                    low + step * 6.0f,
                    low + step * 7.0f,
                    high
                    };
        Vector3 p0 = a->position.bezier_interpolate(a_control,b_control,b->position,s[0]);
        Vector3 p1 = a->position.bezier_interpolate(a_control,b_control,b->position,s[1]);
        Vector3 p2 = a->position.bezier_interpolate(a_control,b_control,b->position,s[2]);
        Vector3 p3 = a->position.bezier_interpolate(a_control,b_control,b->position,s[3]);
        Vector3 p4 = a->position.bezier_interpolate(a_control,b_control,b->position,s[4]);
        Vector3 p5 = a->position.bezier_interpolate(a_control,b_control,b->position,s[5]);
        Vector3 p6 = a->position.bezier_interpolate(a_control,b_control,b->position,s[6]);
        Vector3 p7 = a->position.bezier_interpolate(a_control,b_control,b->position,s[7]);
        Vector3 p8 = a->position.bezier_interpolate(a_control,b_control,b->position,s[8]);
        real_t dis[9] = {
            pos.distance_squared_to(p0),
            pos.distance_squared_to(p1),
            pos.distance_squared_to(p2),
            pos.distance_squared_to(p3),
            pos.distance_squared_to(p4),
            pos.distance_squared_to(p5),
            pos.distance_squared_to(p6),
            pos.distance_squared_to(p7),
            pos.distance_squared_to(p8)
        };
        real_t smallest = dis[0];
        int smallest_index = 0;
        for(int i=1; i < 9; i++){
            if(dis[i] < smallest){
                smallest = dis[i];
                smallest_index = i;
            }
        }
        if(smallest_index==0){
            high = s[1];
            continue;
        }
        if(smallest_index==8){
            low = s[7];
            continue;
        }
        if(dis[smallest_index-1] < dis[smallest_index+1]){
            low = s[smallest_index -1];
            high = s[smallest_index];
        } else {
            high = s[smallest_index +1];
            low = s[smallest_index];
        }
    }
    return (low+high)/2.0;
}

float MCurve::get_closest_ratio_to_line(int64_t conn_id,Vector3 line_pos,Vector3 line_dir) const{
    ERR_FAIL_COND_V(!has_conn(conn_id), 0.0f);
    // Creating Transform to view space
    line_dir.normalize();
    Vector3 up = std::abs(line_dir.y) < 0.9 ? Vector3(0,1,0) : Vector3(1,0,0);
    Vector3 side = -up.cross(line_dir);
    up = side.cross(line_dir);
    Transform3D t = Transform3D(Basis(side,up,line_dir),line_pos);
    t = t.inverse();
    ///////
    Conn conn(conn_id);
    const Point* a = points_buffer.ptr() + conn.p.a;
    const Point* b = points_buffer.ptr() + conn.p.b;
    Vector3 a_pos = a->position;
    Vector3 b_pos = b->position;
    Vector3 a_control = a->in; 
    Vector3 b_control = b->in;
    for(int8_t i=0; i < MAX_CONN; i++){
        if(a->conn[i] == conn.p.b){
            a_control = a->out;
        }
        if(b->conn[i] == conn.p.a){
            b_control = b->out;
        }
    }
    /// Converting to our space
    a_pos = t.xform(a_pos);
    b_pos = t.xform(b_pos);
    a_control = t.xform(a_control);
    b_control = t.xform(b_control);
    ///////////// Creating 2d
    Vector2 a_pos_2d(a_pos.x,a_pos.y);
    Vector2 b_pos_2d(b_pos.x,b_pos.y);
    Vector2 a_control_2d(a_control.x,a_control.y);
    Vector2 b_control_2d(b_control.x,b_control.y);
    ////////////////////////////
    ////////////////////////////
    real_t low = 0.0f;
    real_t high = 1.0;
    constexpr int sample_count = 16;
    float smallest_dis;
    while (high - low > 0.005f)
    {
        float step = (high-low)/sample_count;
        float _s[sample_count];
        float _dis[sample_count];
        for(int i=0; i < sample_count; i++){
            _s[i] = low + step*i;
            Vector2 _p_2d = a_pos_2d.bezier_interpolate(a_control_2d,b_control_2d,b_pos_2d,_s[i]);
            _dis[i] = _p_2d.length();
        }
        smallest_dis = _dis[0];
        int smallest_index = 0;
        for(int i=1; i < sample_count; i++){
            if(_dis[i] < smallest_dis){
                smallest_dis = _dis[i];
                smallest_index = i;
            }
        }
        if(smallest_index==0){
            high = _s[1];
            continue;
        }
        if(smallest_index==sample_count-1){
            low = _s[7];
            continue;
        }
        if(_dis[smallest_index-1] < _dis[smallest_index+1]){
            low = _s[smallest_index -1];
            high = _s[smallest_index];
        } else {
            high = _s[smallest_index +1];
            low = _s[smallest_index];
        }
    }
    return (low+high)/2.0f;
}
/*
    Other function always return the direction start from smaller point id index
    to bigger one
    This has the direction of point which you define
*/
Vector3 MCurve::get_point_order_tangent(int32_t point_a,int32_t point_b,float t){
    ERR_FAIL_COND_V(!has_point(point_a), Vector3());
    ERR_FAIL_COND_V(!has_point(point_b), Vector3());
    const Point* a = points_buffer.ptr() + point_a;
    const Point* b = points_buffer.ptr() + point_b;
    Vector3 a_control = a->in; 
    Vector3 b_control = b->in;
    for(int8_t i=0; i < MAX_CONN; i++){
        if(a->conn[i] == point_b){
            a_control = a->out;
        }
        if(b->conn[i] == point_a){
            b_control = b->out;
        }
    }
    return _get_bezier_tangent(a->position,b->position,a_control,b_control,t);
}

Vector3 MCurve::get_conn_tangent(int64_t conn_id,float t){
    ERR_FAIL_COND_V(!has_conn(conn_id), Vector3());
    Conn conn(conn_id);
    const Point* a = points_buffer.ptr() + conn.p.a;
    const Point* b = points_buffer.ptr() + conn.p.b;
    Vector3 a_control = a->in; 
    Vector3 b_control = b->in;
    for(int8_t i=0; i < MAX_CONN; i++){
        if(a->conn[i] == conn.p.b){
            a_control = a->out;
        }
        if(b->conn[i] == conn.p.a){
            b_control = b->out;
        }
    }
    return _get_bezier_tangent(a->position,b->position,a_control,b_control,t);
}

Transform3D MCurve::get_point_order_transform(int32_t point_a,int32_t point_b,float t,bool tilt,bool scale){
    ERR_FAIL_COND_V(!has_point(point_a), Transform3D());
    ERR_FAIL_COND_V(!has_point(point_b), Transform3D());
    const Point* a = points_buffer.ptr() + point_a;
    const Point* b = points_buffer.ptr() + point_b;
    Vector3 a_control = a->in; 
    Vector3 b_control = b->in;
    for(int8_t i=0; i < MAX_CONN; i++){
        if(a->conn[i] == point_b){
            a_control = a->out;
        }
        if(b->conn[i] == point_a){
            b_control = b->out;
        }
    }
    // See if is straight perpendiculare line which is not handled by _get_bezier_transform
    Transform3D ptrasform;
    if(a->position.is_equal_approx(a_control)
    &&b->position.is_equal_approx(b_control)
    && Math::is_equal_approx(a->position.x,b->position.x)
    && Math::is_equal_approx(a->position.z,b->position.z)){
        ptrasform = _get_bezier_transform(a->position,b->position,a_control,b_control,Vector3(0,0,1),t);
    }
    ptrasform = _get_bezier_transform(a->position,b->position,a_control,b_control,Vector3(0,1,0),t);
    // Applying tilt
    if(tilt){
        float current_tilt = Math::lerp(a->tilt,b->tilt,t);
        ptrasform.basis.rotate(ptrasform.basis[0],current_tilt); 
    }        
    // Applying scale
    if(scale){
        float current_scale = Math::lerp(a->scale,b->scale,t);
        ptrasform.basis.scale(Vector3(current_scale,current_scale,current_scale));
    }
    return ptrasform;
}

Transform3D MCurve::get_conn_transform(int64_t conn_id,float t,bool apply_tilt,bool apply_scale){
    ERR_FAIL_COND_V(!has_conn(conn_id), Transform3D());
    Conn conn(conn_id);
    const Point* a = points_buffer.ptr() + conn.p.a;
    const Point* b = points_buffer.ptr() + conn.p.b;
    Vector3 a_control = a->in; 
    Vector3 b_control = b->in;
    for(int8_t i=0; i < MAX_CONN; i++){
        if(a->conn[i] == conn.p.b){
            a_control = a->out;
        }
        if(b->conn[i] == conn.p.a){
            b_control = b->out;
        }
    }
    // See if is straight perpendiculare line which is not handled by _get_bezier_transform
    Transform3D ptrasform;
    if(a->position.is_equal_approx(a_control)
    &&b->position.is_equal_approx(b_control)
    && Math::is_equal_approx(a->position.x,b->position.x)
    && Math::is_equal_approx(a->position.z,b->position.z)){
        ptrasform = _get_bezier_transform(a->position,b->position,a_control,b_control,Vector3(0,0,1),t);
    }
    ptrasform = _get_bezier_transform(a->position,b->position,a_control,b_control,Vector3(0,1,0),t);
    if(apply_tilt)
    {
        float current_tilt = Math::lerp(a->tilt,b->tilt,t);
        ptrasform.basis.rotate(ptrasform.basis[0],current_tilt); 
    }                                            
    if(apply_scale){
        float current_scale = Math::lerp(a->scale,b->scale,t);
        ptrasform.basis.scale(Vector3(current_scale,current_scale,current_scale));
    }
    return ptrasform;
}

void MCurve::get_conn_transforms(int64_t conn_id,const Vector<float>& t,Vector<Transform3D>& transforms,bool apply_tilt,bool apply_scale){
    ERR_FAIL_COND(!has_conn(conn_id));
    transforms.resize(t.size());
    Conn conn(conn_id);
    const Point* a = points_buffer.ptr() + conn.p.a;
    const Point* b = points_buffer.ptr() + conn.p.b;
    Vector3 a_control = a->in; 
    Vector3 b_control = b->in;
    for(int8_t i=0; i < MAX_CONN; i++){
        if(a->conn[i] == conn.p.b){
            a_control = a->out;
        }
        if(b->conn[i] == conn.p.a){
            b_control = b->out;
        }
    }
    // See if is straight perpendiculare line which is not handled by _get_bezier_transform
    if(a->position.is_equal_approx(a_control)
    &&b->position.is_equal_approx(b_control)
    && Math::is_equal_approx(a->position.x,b->position.x)
    && Math::is_equal_approx(a->position.z,b->position.z)){
        for(int i=0; i < t.size(); i++){
            Transform3D ptrasform = _get_bezier_transform(a->position,b->position,a_control,b_control,Vector3(0,0,1),t[i]);
            float current_tilt = Math::lerp(a->tilt,b->tilt,t[i]);
            float current_scale = Math::lerp(a->scale,b->scale,t[i]);
            ptrasform.basis.rotate(ptrasform.basis[0],current_tilt);
            ptrasform.basis.scale(Vector3(current_scale,current_scale,current_scale));
            transforms.set(i,ptrasform);
        }
        return;
    }
    for(int i=0; i < t.size(); i++){
        Transform3D ptrasform = _get_bezier_transform(a->position,b->position,a_control,b_control,Vector3(0,1,0),t[i]);
        if(apply_tilt){
            float current_tilt = Math::lerp(a->tilt,b->tilt,t[i]);
            ptrasform.basis.rotate(ptrasform.basis[0],current_tilt);
        }
        if(apply_scale){
            float current_scale = Math::lerp(a->scale,b->scale,t[i]);
            ptrasform.basis.scale(Vector3(current_scale,current_scale,current_scale));
        }
        transforms.set(i,ptrasform);
    }
}

float MCurve::get_conn_lenght(int64_t conn_id){
    float* dis;
    if(conn_distances.has(conn_id)){
        dis = conn_distances[conn_id].dis;
    } else {
        dis = _bake_conn_distance(conn_id);
    }
    ERR_FAIL_COND_V(dis==nullptr,0.0f);
    return dis[DISTANCE_BAKE_TOTAL - 1];
}
Pair<float,float> MCurve::conn_ratio_limit_to_dis_limit(int64_t conn_id,const Pair<float,float>& limits){
    Pair<float,float> out;
    ERR_FAIL_COND_V(limits.first > limits.second,out);
    if(Math::is_equal_approx(limits.first,0.0f) && Math::is_equal_approx(limits.second,1.0f)){
        out.first = 0.0f;
        out.second = get_conn_lenght(conn_id);
        return out;
    }
    float* dis;
    if(conn_distances.has(conn_id)){
        dis = conn_distances[conn_id].dis;
    } else {
        dis = _bake_conn_distance(conn_id);
    }
    out.first = _get_conn_ratio_distance(dis,limits.first);
    out.second = _get_conn_ratio_distance(dis,limits.second);
    return out;
}
/*
    Not with order of connection
    in order of points provided
*/
float MCurve::get_point_order_distance_ratio(int32_t point_a,int32_t point_b,float distance){
    float* dis;
    Conn c(point_a,point_b);
    if(conn_distances.has(c.id)){
        dis = conn_distances[c.id].dis;
    } else {
        dis = _bake_conn_distance(c.id);
    }
    ERR_FAIL_COND_V(dis==nullptr,0.0f);
    distance = point_a > point_b ? dis[DISTANCE_BAKE_TOTAL - 1] - distance : distance;
    float t = _get_conn_distance_ratios(dis,distance);
    t = point_a > point_b ?  1.0f - t: t;
    return t;
}

float MCurve::get_conn_distance_ratio(int64_t conn_id,float distance) {
    float* dis;
    if(conn_distances.has(conn_id)){
        dis = conn_distances[conn_id].dis;
    } else {
        dis = _bake_conn_distance(conn_id);
    }
    ERR_FAIL_COND_V(dis==nullptr,0.0f);
    return _get_conn_distance_ratios(dis,distance);
}
/*
    return smallest and biggest ratio in order with Pair
*/
Pair<int,int> MCurve::get_conn_distances_ratios(int64_t conn_id,const Vector<float>& distances,Vector<float>& t){
    t.resize(distances.size());
    float* dis;
    if(conn_distances.has(conn_id)){
        dis = conn_distances[conn_id].dis;
    } else {
        dis = _bake_conn_distance(conn_id);
    }
    Pair<int,int> out;
    ERR_FAIL_COND_V(dis==nullptr,out);
    float smallest_ratio = 10.0;
    int smallest_ration_index = -1;
    float biggest_ratio = -10.0;
    int biggest_ratio_index = -1;
    for(int i=0; i < distances.size(); i++){
        float ratio = _get_conn_distance_ratios(dis,distances[i]);
        t.set(i,ratio);
        if(ratio < smallest_ratio){
            smallest_ratio = ratio;
            smallest_ration_index = i;
        }
        if(ratio > biggest_ratio){
            biggest_ratio = ratio;
            biggest_ratio_index = i;
        }
    }
    ERR_FAIL_COND_V(smallest_ration_index==-1 || biggest_ratio_index==-1,out);
    out.first = smallest_ration_index;
    out.second = biggest_ratio_index;
    return out;
}

float MCurve::_get_conn_ratio_distance(const float* baked_dis,const float ratio) const{
    if(ratio < 0.001){
        return 0.0f;
    }
    if(ratio > 0.999){
        return baked_dis[DISTANCE_BAKE_TOTAL - 1];
    }
    int ratio_index = ratio * (DISTANCE_BAKE_TOTAL - 1);
    float ratio_remainder = std::fmod(ratio , RATIO_BAKE_INTERVAL);
    return Math::lerp(baked_dis[ratio_index],baked_dis[ratio_index+1],ratio_remainder);
}

float MCurve::_get_conn_distance_ratios(const float* baked_dis,const float distance) const{
    if(distance <= 0){
        return 0.0;
    }
    if(distance >= baked_dis[DISTANCE_BAKE_TOTAL - 1]){
        return 1.0;
    }
    int low = 0;
    int high = DISTANCE_BAKE_TOTAL - 1;
    int middle;
    while (high >= low)
    {
        middle = (high + low) / 2;
        if(baked_dis[middle] < distance){
            low = middle + 1;
        } else {
            high = middle - 1;
        }
    };
    #ifdef DEBUG_ENABLED
    ERR_FAIL_COND_V(high >= DISTANCE_BAKE_TOTAL - 1.0,0.0);
    #endif
    // our distance should be between these two
    float a;
    float b;
    float a_ratio;
    /// Despite its name hight is the lower bound here
    if(high < 0){ // is before point dis[0] and the zero lenght or start point
        a = 0;
        b = baked_dis[0];
        a_ratio = 0.0f;
    } else {
        a = baked_dis[high];
        b = baked_dis[high+1];
        a_ratio = (high + 1) * RATIO_BAKE_INTERVAL;
    }
    //return high * RATIO_BAKE_INTERVAL + RATIO_BAKE_INTERVAL;
    float dis_ratio = ((distance - a)/(b-a)) * RATIO_BAKE_INTERVAL;
    #ifdef DEBUG_ENABLED
    ERR_FAIL_COND_V(distance < a || distance > b, 0.0);
    #endif
    return dis_ratio + a_ratio;
}

/*
    Return the a pointer to ConnDistances float dis element
    if LENGTH_POINT_SAMPLE_COUNT = N
    a.pos --------------------------- b.pos
            0...1...2...3...,...,.....N-1
    There is not baked distnace at a.pos as it is always zero distance

*/
_FORCE_INLINE_ float* MCurve::_bake_conn_distance(int64_t conn_id){
    ERR_FAIL_COND_V(!has_conn(conn_id), nullptr);
    Conn conn(conn_id);
    const Point* a = points_buffer.ptr() + conn.p.a;
    const Point* b = points_buffer.ptr() + conn.p.b;
    Vector3 a_control = a->in; 
    Vector3 b_control = b->in;
    for(int8_t i=0; i < MAX_CONN; i++){
        if(a->conn[i] == conn.p.b){
            a_control = a->out;
        }
        if(b->conn[i] == conn.p.a){
            b_control = b->out;
        }
    }

    ConnDistances conn_d;
    float _interval = 1.0f/LENGTH_POINT_SAMPLE_COUNT;
    float lenght = 0;
    Vector3 last_pos = a->position;
    for(int i=1; i < LENGTH_POINT_SAMPLE_COUNT; i++){
        Vector3 current_pos = a->position.bezier_interpolate(a_control,b_control,b->position,_interval*i);
        lenght += last_pos.distance_to(current_pos);
        last_pos = current_pos;
        if(i%DISTANCE_BAKE_INTERVAL == 0){
            conn_d.dis[(i/DISTANCE_BAKE_INTERVAL) -1] = lenght;
        }
    }
    lenght += last_pos.distance_to(b->position);
    conn_d.dis[DISTANCE_BAKE_TOTAL - 1] = lenght;
    conn_distances.insert(conn_id,conn_d);
    return conn_distances[conn_id].dis;
}
/*
    bellow rename_ ... methods has only internal use and should not be called
    for now it used for swaping two point
*/
void MCurve::toggle_conn_type(int32_t point, int64_t conn_id){
    ERR_FAIL_COND(!has_point(point));
    Conn c(conn_id);
    int32_t other_point = 0;
    if(point==c.p.a){
        other_point = c.p.b;
    } else if(point==c.p.b) {
        other_point = c.p.a;
    } else{
        return;
    }
    ERR_FAIL_COND(!has_point(other_point));
    Point* tp = points_buffer.ptrw() + point;
    for(int8_t i=0; i < MAX_CONN; i++){
        if(std::abs(tp->conn[i]) == other_point){
            tp->conn[i] = -tp->conn[i];
            Conn cc(point,std::abs(tp->conn[i]));
            clear_conn_cache_data(cc.id);
            return;
        }
    }
    WARN_PRINT("Can't find conn between "+itos(point)+" and "+itos(other_point));
}

int32_t MCurve::_get_conn_id32(int64_t conn_id) const{
    auto it = conn_id32.find(conn_id);
    return it==conn_id32.end() ? -1 : it->value;
}

void MCurve::_set_conn_id32(int64_t conn_id,int32_t cid32) {
    ConnAdditional& ca = conn_additional.ptrw()[cid32];
    if(cid32==0){
        conn_id32.erase(conn_id);
        ca.conn_id = 0;
        return;
    }
    conn_id32.insert(conn_id,cid32);
    ca.conn_id = conn_id;
}

int8_t MCurve::_calculate_conn_lod(const int64_t conn_id) const{
    Conn conn(conn_id);
    const Point& a = points_buffer[conn.p.a];
    const Point& b = points_buffer[conn.p.b];
    int8_t lod = (a.lod < b.lod) && a.lod!=-1 ? a.lod : b.lod;
    auto it_cid32 = conn_id32.find(conn_id);
    ERR_FAIL_COND_V_MSG(it_cid32==conn_id32.end(),lod,"no cid32 "+itos(conn_id));
    const ConnAdditional& ca = conn_additional[it_cid32->value];
    for(int c=0; c < CONN_ADDITIONAL_POINT_COUNT; c++){
        if(lod>ca.lod[c] || lod==-1){
            lod = ca.lod[c];
        }
    }
    return lod;
}

void MCurve::_validate_points(const VSet<int32_t>& points){
    Vector<int32_t> removed_point;
    Vector<int32_t> updated_point;
    for(int i=0; i < points.size(); i++){
        int32_t p_id = points[i];
        if(!has_point(p_id)){
            removed_point.push_back(p_id);
            continue;
        }
        Point& point = points_buffer.ptrw()[p_id];
        if(octree){
            point.lod = octree->get_pos_lod_classic(point.position);
        }
        if(point.lod > active_lod_limit){
            active_points.erase(p_id);
            removed_point.push_back(p_id);
        } else {
            active_points.insert(p_id);
            updated_point.push_back(p_id);
        }
    }
    for(int i=0; i < removed_point.size(); i++){
        emit_signal("remove_point",removed_point[i]);
    }
    for(int i=0; i < updated_point.size(); i++){
        emit_signal("force_update_point",updated_point[i]);
    }
}

void MCurve::_validate_conns(const VSet<int64_t>& conns){
    Vector<int64_t> removed_conn;
    Vector<int64_t> updated_conn;
    for(int i=0; i < conns.size(); i++){
        int64_t cid = conns[i];
        clear_conn_cache_data(cid);
        if(!has_conn(cid)){
            conn_list.erase(cid);
            active_conn.erase(cid);
            removed_conn.push_back(cid);
            continue;
        }
        int8_t conn_lod = _calculate_conn_lod(cid);
        if(conn_lod > active_lod_limit){
            conn_list.erase(cid);
            active_conn.erase(cid);
            removed_conn.push_back(cid);
        } else {
            active_conn.insert(cid);
            conn_list.insert(cid,conn_lod);
            updated_conn.push_back(cid);
        }
    }
    for(int i=0; i < removed_conn.size(); i++){
        Conn conn(removed_conn[i]);
        //UtilityFunctions::print("remove_connection ",conn.str());
        emit_signal("remove_connection",removed_conn[i]);
    }
    for(int i=0; i < updated_conn.size(); i++){
        Conn conn(updated_conn[i]);
        //UtilityFunctions::print("updated_conn ",conn.str());
        emit_signal("force_update_connection",updated_conn[i]);
    }
}
/*
    After calling this the connection id connected to these points will be invalid
*/
void MCurve::_swap_points(const int32_t p_a,const int32_t p_b,VSet<int64_t>& affected_conns){
    if(p_a==p_b){
        return;
    }
    ERR_FAIL_COND(!has_point(p_a)||!has_point(p_b));
    const Point& a_old = points_buffer[p_a];
    const Point& b_old = points_buffer[p_b];
    Ref<MCurveOverrideData> a_old_override = get_override_entry(p_a);
    Ref<MCurveOverrideData> b_old_override = get_override_entry(p_b);
    Point a_new = b_old;
    Point b_new = a_old;
    bool is_a_b_connected = false;
    { // sign between connection should swap if is_a_b_connected true
        int b_sign_in_a_old = 0; // +1
        int a_sign_in_b_old = 0; // -1
        int b_index_in_a_old; // 3i
        int a_index_in_b_old; // 1i
        for(int i=0; i < MAX_CONN; i++){
            if(std::abs(a_old.conn[i])==p_b){
                is_a_b_connected = true;
                b_sign_in_a_old = a_old.conn[i] > 0 ? 1 : -1;
                b_index_in_a_old = i;
            }
            if(std::abs(b_old.conn[i])==p_a){
                is_a_b_connected = true;
                a_sign_in_b_old = b_old.conn[i] > 0 ? 1 : -1;
                a_index_in_b_old = i;
            }
        }
        if(is_a_b_connected){
            ERR_FAIL_COND(a_sign_in_b_old==0||b_sign_in_a_old==0);
            a_new.conn[a_index_in_b_old] = a_sign_in_b_old * p_b;
            b_new.conn[b_index_in_a_old] = b_sign_in_a_old * p_a;
            Conn ab(p_a,p_b);
            affected_conns.insert(ab.id);
        }
    }
    /////////// Now everything point to p_a should point to p_b with conserving the sign
    // pointing to p_a
    Conn orignal_conn[MAX_CONN*2];
    Conn replace_conn[MAX_CONN*2];
    /// Swaping conn_id32 will swap all additional_point stuff
    int32_t orignal_conn_id32[MAX_CONN*2];
    for(int i=0; i < MAX_CONN; i++){
        orignal_conn[i].id = 0;
        replace_conn[i].id = 0;
        int other_index = std::abs(a_old.conn[i]);
        if(a_old.conn[i]!=0 && other_index!=p_b){
            Point* other_p = points_buffer.ptrw() + other_index;
            for(int j=0; j < MAX_CONN; j++){
                if(std::abs(other_p->conn[j])==p_a){
                    int sign = other_p->conn[j] > 0 ? 1 : -1;
                    other_p->conn[j] = sign * p_b;
                    orignal_conn[i] = Conn(p_a,other_index);
                    replace_conn[i] = Conn(p_b,other_index);
                    orignal_conn_id32[i] = _get_conn_id32(orignal_conn[i].id);
                    affected_conns.insert(orignal_conn[i].id);
                    affected_conns.insert(replace_conn[i].id);
                    break;
                }
            }
        }
    }
    // pointing to p_b
    for(int i=0; i < MAX_CONN; i++){
        int ii = i + MAX_CONN;
        orignal_conn[ii].id = 0;
        replace_conn[ii].id = 0;
        int other_index = std::abs(b_old.conn[i]);
        if(b_old.conn[i]!=0 && other_index!=p_a){
            Point* other_p = points_buffer.ptrw() + other_index;
            for(int j=0; j < MAX_CONN; j++){
                if(std::abs(other_p->conn[j])==p_b){
                    int sign = other_p->conn[j] > 0 ? 1 : -1;
                    other_p->conn[j] = sign * p_a;
                    orignal_conn[ii] = Conn(p_b,other_index);
                    replace_conn[ii] = Conn(p_a,other_index);
                    orignal_conn_id32[ii] = _get_conn_id32(orignal_conn[ii].id);
                    affected_conns.insert(orignal_conn[ii].id);
                    affected_conns.insert(replace_conn[ii].id);
                    break;
                }
            }
        }
    }
    if(octree && is_init_insert){ // don't move affter points_buffer.set
        octree->change_point_id(oct_id,a_old.position,p_a,p_b);
        octree->change_point_id(oct_id,b_old.position,p_b,p_a);
    }
    points_buffer.set(p_a,a_new);
    points_buffer.set(p_b,b_new);
    set_override_entry(p_a,b_old_override);
    set_override_entry(p_b,a_old_override);
    // if p_a p_b connected their conn_id will not change only for others
    Ref<MCurveOverrideData> conn_overrides[MAX_CONN*2];
    for(int c=0; c < MAX_CONN*2; c++){
        if(orignal_conn[c].id!=0){
            conn_overrides[c] = get_override_entry(orignal_conn[c].id);
        }
    }
    // Replaceing overrides and removin old conn from list and replace it with new one
    for(int c=0; c < MAX_CONN*2; c++){
        if(conn_overrides[c].is_valid()){
            set_override_entry(replace_conn[c].id,conn_overrides[c]);
        }
    }
    // Removing original id32
    for(int c=0; c < MAX_CONN*2; c++){
        if(orignal_conn[c].id!=0){
            _set_conn_id32(orignal_conn[c].id,0);
        }
    }
    // Adding replaced id32
    for(int c=0; c < MAX_CONN*2; c++){
        if(replace_conn[c].id!=0){
            _set_conn_id32(replace_conn[c].id,orignal_conn_id32[c]);
        }
    }
}

void MCurve::swap_points(const int32_t p_a,const int32_t p_b){
    VSet<int64_t> affected_conns;
    _swap_points(p_a,p_b,affected_conns);
    VSet<int32_t> affected_points;
    for(int i=0; i < affected_conns.size(); i++){
        Conn conn(affected_conns[i]);
        affected_points.insert(conn.p.a);
        affected_points.insert(conn.p.b);
    }
    _validate_points(affected_points);
    _validate_conns(affected_conns);
    emit_signal("curve_updated");
}

int32_t MCurve::sort_from(int32_t root_point,bool increasing){
    ERR_FAIL_COND_V(!has_point(root_point),0);
    VSet<int64_t> affected_conns;
    // we consume all sorted points and points until they finish
    VSet<int32_t> psets = get_point_conn_points_recursive(root_point);
    PackedInt32Array points_sorted; // PackedInt32Array so we can reverse it
    points_sorted.resize(psets.size());
    for(int i=0; i < points_sorted.size(); i++){
        points_sorted.set(i,psets[i]);
    }
    if(increasing){ // as removing from end is faster
        points_sorted.reverse();
    }
    {
        // First do it for root point
        int32_t next_swap = points_sorted[points_sorted.size()-1];
        if(increasing){
            if(root_point > next_swap){
                _swap_points(root_point,next_swap,affected_conns);
            }
        } else {
            if(root_point < next_swap){
                _swap_points(root_point,next_swap,affected_conns);
            }
        }
        points_sorted.remove_at(points_sorted.size()-1);
        root_point = next_swap; // important
    }
    HashSet<int32_t> finish_points;
    finish_points.insert(root_point);
    PackedInt32Array parent_points = {0};
    // now we go and sort for each child one by one
    while (points_sorted.size()!=0 && parent_points.size()!=0)
    {
        int32_t current_parent_point_id = parent_points[parent_points.size()-1];
        parent_points.remove_at(parent_points.size()-1);
        const Point* current_parent_point = current_parent_point_id==0 ? &points_buffer[root_point] : &points_buffer[current_parent_point_id];
        for(int c=0; c < MAX_CONN; c++){
            if(points_sorted.size()==0){
                break;
            }
            if(current_parent_point->conn[c]!=0){
                int32_t child_id = std::abs(current_parent_point->conn[c]);
                if(finish_points.has(child_id)){
                    continue;
                }
                // Remove if at branch no need to go further
                if(points_buffer[child_id].get_conn_count()==0){ 
                    int _i = points_sorted.find(child_id);
                    if(_i!=-1){ points_sorted.remove_at(_i); }
                    finish_points.insert(child_id);
                    continue;
                }
                int32_t next_swap = points_sorted[points_sorted.size()-1];
                if(current_parent_point->is_connected_to(next_swap)){
                    // we will encounter this point in this inner loop soon
                    continue;
                }
                if(increasing){
                    if(child_id > next_swap){
                        _swap_points(child_id,next_swap,affected_conns);
                        points_sorted.remove_at(points_sorted.size()-1); 
                        child_id = next_swap;
                    } else {
                        int _i = points_sorted.find(child_id);
                        if(_i!=-1){ points_sorted.remove_at(_i); }
                    }
                } else {
                    if(child_id < next_swap){
                        _swap_points(child_id,next_swap,affected_conns);
                        points_sorted.remove_at(points_sorted.size()-1); 
                        child_id = next_swap;
                    } else {
                        int _i = points_sorted.find(child_id);
                        if(_i!=-1){ points_sorted.remove_at(_i); }
                    }
                }
                parent_points.push_back(child_id);
                finish_points.insert(child_id);
            }
        }
    }
    /// updating
    _validate_points(psets);
    _validate_conns(affected_conns);
    emit_signal("curve_updated");
    return root_point;
}

void MCurve::move_point(int p_index,const Vector3& pos){
    ERR_FAIL_INDEX(p_index,points_buffer.size());
    ERR_FAIL_COND(is_vec3_nan(pos));
    Point* p = points_buffer.ptrw() + p_index;
    if(octree && is_init_insert){
        MOctree::PointMoveReq req(p_index,oct_id,p->position,pos);
        octree->add_move_req(req);
    }
    Vector3 old_positions[MAX_CONN][CONN_ADDITIONAL_POINT_COUNT];
    for(int i=0; i < MAX_CONN; i++){
        if(p->conn[i]!=0){
            Conn conn(p_index,std::abs(p->conn[i]));
            _get_conn_additional_points(conn.id,old_positions[i]);
        }
    }
    Vector3 diff = pos - p->position;
    p->position = pos;
    p->in += diff;
    p->out += diff;
    for(int i=0; i < MAX_CONN; i++){
        if(p->conn[i]!=0){
            Conn conn(p_index,std::abs(p->conn[i]));
            _update_conn_additional_points(conn.id,old_positions[i]);
        }
    }
    for(int i=0 ; i < MAX_CONN; i++){
        if(p->conn[i]!=0){
            Conn cc(std::abs(p->conn[i]),p_index);
            clear_conn_cache_data(cc.id);
        }
    }
    emit_signal("curve_updated");
}

void MCurve::move_point_in(int p_index,const Vector3& pos){
    ERR_FAIL_INDEX(p_index,points_buffer.size());
    ERR_FAIL_COND(is_vec3_nan(pos));
    Point* p = points_buffer.ptrw() + p_index;
    Vector3 old_positions[MAX_CONN][CONN_ADDITIONAL_POINT_COUNT];
    for(int i=0; i < MAX_CONN; i++){
        if(p->conn[i]!=0){
            Conn conn(p_index,std::abs(p->conn[i]));
            _get_conn_additional_points(conn.id,old_positions[i]);
        }
    }
    p->in = pos;
    for(int i=0; i < MAX_CONN; i++){
        if(p->conn[i]!=0){
            Conn conn(p_index,std::abs(p->conn[i]));
            _update_conn_additional_points(conn.id,old_positions[i]);
        }
    }
    for(int i=0 ; i < MAX_CONN; i++){
        if(p->conn[i]!=0){
            Conn cc(std::abs(p->conn[i]),p_index);
            clear_conn_cache_data(cc.id);
        }
    }
    emit_signal("curve_updated");
}

void MCurve::move_point_out(int p_index,const Vector3& pos){
    ERR_FAIL_INDEX(p_index,points_buffer.size());
    ERR_FAIL_COND(is_vec3_nan(pos));
    Point* p = points_buffer.ptrw() + p_index;
    Vector3 old_positions[MAX_CONN][CONN_ADDITIONAL_POINT_COUNT];
    for(int i=0; i < MAX_CONN; i++){
        if(p->conn[i]!=0){
            Conn conn(p_index,std::abs(p->conn[i]));
            _get_conn_additional_points(conn.id,old_positions[i]);
        }
    }
    p->out = pos;
    for(int i=0; i < MAX_CONN; i++){
        if(p->conn[i]!=0){
            Conn conn(p_index,std::abs(p->conn[i]));
            _update_conn_additional_points(conn.id,old_positions[i]);
        }
    }
    for(int i=0 ; i < MAX_CONN; i++){
        if(p->conn[i]!=0){
            Conn cc(std::abs(p->conn[i]),p_index);
            clear_conn_cache_data(cc.id);
        }
    }
    emit_signal("curve_updated");
}

int32_t MCurve::ray_active_point_collision(const Vector3& org,Vector3 dir,float threshold){
    ERR_FAIL_COND_V(threshold < 0.99,INVALID_POINT_INDEX);
    dir.normalize();
    for(int i=0; i < active_points.size(); i++){
        Vector3 pto = points_buffer[active_points[i]].position - org;
        pto.normalize();
        float dot = pto.dot(dir);
        if (dot > threshold){
            return active_points[i];
        }
        pto = points_buffer[active_points[i]].in - org;
        pto.normalize();
        dot = pto.dot(dir);
        if (dot > threshold){
            return active_points[i];
        }
        pto = points_buffer[active_points[i]].out - org;
        pto.normalize();
        dot = pto.dot(dir);
        if (dot > threshold){
            return active_points[i];
        }
    }
    return INVALID_POINT_INDEX;
}

Ref<MCurveConnCollision> MCurve::ray_active_conn_collision(const Vector3& org,Vector3 dir,float threshold){
    ERR_FAIL_COND_V(threshold < 0.99,INVALID_POINT_INDEX);
    Ref<MCurveConnCollision> col;
    col.instantiate();
    dir.normalize();
    constexpr float grow = 0.5;
    for(int i=0; i < active_conn.size(); i++){
        int64_t cid = active_conn[i];
        AABB aabb = get_conn_aabb(cid);
        // inline not using .grow() function for performance
        aabb.position.x -= grow;
        aabb.position.y -= grow;
        aabb.position.z -= grow;
        aabb.size.x += grow;
        aabb.size.y += grow;
        aabb.size.z += grow;
        if(aabb.intersects_ray(org,dir)){
            float ratio = get_closest_ratio_to_line(cid,org,dir);
            Vector3 pos = get_conn_position(cid,ratio);
            Vector3 p_dir = pos - org;
            p_dir.normalize();
            float val = p_dir.dot(dir);
            if(val >= threshold){
                col->_is_col = true;
                col->_ratio = ratio;
                col->_conn_id = cid;
                return col;
            }
        }
    }
    return col;
}

/*
    Header in order -> Total header size 16 Byte
    uint32_t -> PointSave struct size
    uint32_t -> point index type size (currently should be int32_t which is 4 byte)
    uint32_t -> free_buffer_indicies size or count (Not size in byte)
    uint32_t -> points buffer size or count (Not size in byte)
*/
#define MCURVE_DATA_HEADER_SIZE 16

void MCurve::_set_data(const PackedByteArray& data){
    ERR_FAIL_COND(data.size() < MCURVE_DATA_HEADER_SIZE);
    // Header
    ERR_FAIL_COND(data.decode_u32(0)!=(uint32_t)sizeof(MCurve::PointSave));
    ERR_FAIL_COND(data.decode_u32(4)!=(uint32_t)sizeof(int32_t));
    uint32_t free_indicies_count = data.decode_u32(8);
    uint32_t points_buffer_count = data.decode_u32(12);
    size_t size_free_indicies_byte = free_indicies_count * sizeof(int32_t);
    size_t size_points_buffer_byte = points_buffer_count * sizeof(MCurve::PointSave);
    ERR_FAIL_COND(data.size()!= MCURVE_DATA_HEADER_SIZE + size_free_indicies_byte + size_points_buffer_byte);

    // Finish header
    points_buffer.resize(points_buffer_count);
    free_buffer_indicies.resize(free_indicies_count);

    int64_t byte_offset = MCURVE_DATA_HEADER_SIZE;
    memcpy(free_buffer_indicies.ptrw(),data.ptr()+byte_offset,size_free_indicies_byte);
    byte_offset += size_free_indicies_byte;
    // Points buffer
    Vector<PointSave> points_save;
    points_save.resize(points_buffer_count);
    memcpy(points_save.ptrw(),data.ptr()+byte_offset,size_points_buffer_byte);
    points_buffer.resize(points_buffer_count);
    for(int i=0; i < points_buffer.size(); i++){
        points_buffer.set(i,points_save.get(i).get_point());
    }
}

PackedByteArray MCurve::_get_data(){
    PackedByteArray data;
    size_t size_free_indicies_byte = free_buffer_indicies.size() * sizeof(int32_t);
    size_t size_points_buffer_byte = points_buffer.size() * sizeof(PointSave);
    data.resize(MCURVE_DATA_HEADER_SIZE + size_free_indicies_byte + size_points_buffer_byte);
    // Header
    data.encode_u32(0,(uint32_t)sizeof(MCurve::PointSave));
    data.encode_u32(4,(uint32_t)sizeof(int32_t));
    data.encode_u32(8,(uint32_t)free_buffer_indicies.size());
    data.encode_u32(12,(uint32_t)points_buffer.size());
    int64_t byte_offset = MCURVE_DATA_HEADER_SIZE;
    //Finish header
    //copy size_free_indicies_byte
    memcpy(data.ptrw() + byte_offset,free_buffer_indicies.ptr(),size_free_indicies_byte);
    byte_offset += size_free_indicies_byte;
    //copy size_free_indicies_byte
    Vector<PointSave> points_save;
    points_save.resize(points_buffer.size());
    for(int i=0; i < points_buffer.size(); i++){
        points_save.set(i,points_buffer.get(i).get_point_save());
    }
    memcpy(data.ptrw()+byte_offset,points_save.ptr(),size_points_buffer_byte);
   return data;
}

void MCurve::set_bake_interval(float input){
    bake_interval = input;
    baked_lines.clear();
}

float MCurve::get_bake_interval(){
    return bake_interval;
}

void MCurve::set_active_lod_limit(int input){
    ERR_FAIL_INDEX(input,127);
    if(input == active_lod_limit){
        return;
    }
    int old_limit = active_lod_limit;
    active_lod_limit = input;
    Vector<int32_t> updated_points;
    for(int i=0;i<points_buffer.size();i++){
        if(free_buffer_indicies.has(i)){
            continue;
        }
        int8_t old_lod = points_buffer[i].lod > old_limit ? -1 : points_buffer[i].lod;
        int8_t new_lod = points_buffer[i].lod > input ? -1 : points_buffer[i].lod;
        if(new_lod == old_lod){
            continue;
        }
        updated_points.push_back(i);
        if(new_lod != -1){
            active_points.insert(i);
        } else {
            active_points.erase(i);
        }
        emit_signal("force_update_point",i);
    }
    HashSet<int64_t> processed_conn;
    for(int k=0; k < updated_points.size(); k++){
        int i = updated_points[k];
        for(int c=0;c < MAX_CONN; c++){
            if(points_buffer[i].conn[c] == INVALID_POINT_INDEX){
                continue;
            }
            int32_t j = std::abs(points_buffer[i].conn[c]);
            Conn cc(i,j);
            if(processed_conn.has(cc.id)){
                continue;
            }
            int8_t c_lod = points_buffer[i].lod < points_buffer[j].lod ? points_buffer[i].lod : points_buffer[j].lod;
            int8_t old_lod = c_lod > old_limit ? -1 : c_lod;
            int8_t new_lod = c_lod > input ? -1 : c_lod;
            if(old_lod == new_lod){
                processed_conn.insert(cc.id);
                continue;
            }
            if(new_lod==-1){
                active_conn.erase(cc.id);
                conn_list.erase(cc.id);
            } else {
                active_conn.insert(cc.id);
                conn_list.insert(cc.id,new_lod);
            }
            emit_signal("force_update_connection",cc.id);
        }
    }
    emit_signal("curve_updated");
}

int MCurve::get_active_lod_limit(){
    return active_lod_limit;
}

float  MCurve::get_length_between_basic(const Point* a, const Point* b, const Vector3& a_control, const Vector3& b_control){
    float lenght = 0;
    Vector3 last_position = a->position;
    if(LENGTH_POINT_SAMPLE_COUNT_BASIC >= 1){
        float p_interval = 1.0 / LENGTH_POINT_SAMPLE_COUNT_BASIC;
        for(int i=1; i <= LENGTH_POINT_SAMPLE_COUNT_BASIC; i++){
            Vector3 current_position = a->position.bezier_interpolate(a_control,b_control,b->position,p_interval*i);
            lenght += current_position.distance_to(last_position);
            last_position = current_position;
        }
    }
    lenght += b->position.distance_to(last_position);
    
    return lenght;
}