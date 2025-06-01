#include "mcurve_instance.h"
#include <godot_cpp/classes/rendering_server.hpp>
#define RS RenderingServer::get_singleton()
#include <godot_cpp/classes/physics_server3d.hpp>
#define PS PhysicsServer3D::get_singleton()
#include <godot_cpp/classes/random_number_generator.hpp>



void MCurveInstanceElement::_generate_transforms(){
    for(int i=0; i < transform_count; i++){
        int iseed = seed + i*13;
        Vector3 _rand_pos;
        Vector3 _rand_rot;
        Vector3 _rand_scale;
        float uniform_scale;
        Ref<RandomNumberGenerator> rand;
        rand.instantiate();
        auto rand_float = [&rand](float a,float b,int seed){
            rand->set_seed(seed);
            return rand->randf_range(a,b);
        };
        _rand_pos.x = rand_float(rand_offset_start.x,rand_offset_end.x,iseed);
        iseed++;
        _rand_pos.y = rand_float(rand_offset_start.y,rand_offset_end.y,iseed);
        iseed++;
        _rand_pos.z = rand_float(rand_offset_start.z,rand_offset_end.z,iseed);
        iseed++;
        _rand_rot.x = rand_float(rand_rotation_start.x,rand_rotation_end.x,iseed);
        iseed++;
        _rand_rot.y = rand_float(rand_rotation_start.y,rand_rotation_end.y,iseed);
        iseed++;
        _rand_rot.z = rand_float(rand_rotation_start.z,rand_rotation_end.z,iseed);
        iseed++;
        _rand_scale.x = rand_float(rand_scale_start.x,rand_scale_end.x,iseed);
        iseed++;
        _rand_scale.y = rand_float(rand_scale_start.y,rand_scale_end.y,iseed);
        iseed++;
        _rand_scale.z = rand_float(rand_scale_start.z,rand_scale_end.z,iseed);
        iseed++;
        uniform_scale = rand_float(rand_uniform_scale_start,rand_uniform_scale_end,iseed);
        // creating basis
        Basis b;
        b.scale(_rand_scale*scale*Vector3(uniform_scale,uniform_scale,uniform_scale));
        b.rotate(Vector3(0,1,0),UtilityFunctions::deg_to_rad(rotation.y));
        b.rotate(Vector3(1,0,0),UtilityFunctions::deg_to_rad(rotation.x));
        b.rotate(Vector3(0,0,1),UtilityFunctions::deg_to_rad(rotation.z));
        // Rotation order YXZ
        b.rotate(Vector3(0,1,0),UtilityFunctions::deg_to_rad(_rand_rot.y));
        b.rotate(Vector3(1,0,0),UtilityFunctions::deg_to_rad(_rand_rot.x));
        b.rotate(Vector3(0,0,1),UtilityFunctions::deg_to_rad(_rand_rot.z));

        bases[i] = b;
        offsets[i] = _rand_pos + offset;
        iseed++;
        random_numbers[i] = rand_float(0.0f,1.0f,iseed);
    }
}


void MCurveInstanceElement::_bind_methods(){
    ADD_SIGNAL(MethodInfo("elements_changed"));

    ClassDB::bind_method(D_METHOD("emit_elements_changed"), &MCurveInstanceElement::emit_elements_changed);

    ClassDB::bind_method(D_METHOD("set_element_name","input"), &MCurveInstanceElement::set_element_name);
    ClassDB::bind_method(D_METHOD("get_element_name"), &MCurveInstanceElement::get_element_name);
    ADD_PROPERTY(PropertyInfo(Variant::STRING,"name",PROPERTY_HINT_NONE,"",PROPERTY_USAGE_EDITOR), "set_element_name", "get_element_name");

    ClassDB::bind_method(D_METHOD("set_mesh","input"), &MCurveInstanceElement::set_mesh);
    ClassDB::bind_method(D_METHOD("get_mesh"), &MCurveInstanceElement::get_mesh);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT,"mesh",PROPERTY_HINT_RESOURCE_TYPE,"MMeshLod"), "set_mesh", "get_mesh");

    ClassDB::bind_method(D_METHOD("set_shape_lod_cutoff","input"), &MCurveInstanceElement::set_shape_lod_cutoff);
    ClassDB::bind_method(D_METHOD("get_shape_lod_cutoff"), &MCurveInstanceElement::get_shape_lod_cutoff);
    ADD_PROPERTY(PropertyInfo(Variant::INT,"shape_lod_cutoff"), "set_shape_lod_cutoff", "get_shape_lod_cutoff");

    ClassDB::bind_method(D_METHOD("set_shape","input"), &MCurveInstanceElement::set_shape);
    ClassDB::bind_method(D_METHOD("get_shape"), &MCurveInstanceElement::get_shape);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT,"shape",PROPERTY_HINT_RESOURCE_TYPE,"Shape3D"), "set_shape", "get_shape");

    ClassDB::bind_method(D_METHOD("set_seed","input"), &MCurveInstanceElement::set_seed);
    ClassDB::bind_method(D_METHOD("get_seed"), &MCurveInstanceElement::get_seed);
    ADD_PROPERTY(PropertyInfo(Variant::INT,"seed"), "set_seed", "get_seed");

    ADD_GROUP("Placement","");

    ClassDB::bind_method(D_METHOD("set_middle","input"), &MCurveInstanceElement::set_middle);
    ClassDB::bind_method(D_METHOD("get_middle"), &MCurveInstanceElement::get_middle);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL,"middle"), "set_middle", "get_middle");

    ClassDB::bind_method(D_METHOD("set_include_end","input"), &MCurveInstanceElement::set_include_end);
    ClassDB::bind_method(D_METHOD("get_include_end"), &MCurveInstanceElement::get_include_end);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL,"include_end"), "set_include_end", "get_include_end");

    ClassDB::bind_method(D_METHOD("set_mirror","input"), &MCurveInstanceElement::set_mirror);
    ClassDB::bind_method(D_METHOD("get_mirror"), &MCurveInstanceElement::get_mirror);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL,"mirror"), "set_mirror", "get_mirror");

    ClassDB::bind_method(D_METHOD("set_mirror_rotation","input"), &MCurveInstanceElement::set_mirror_rotation);
    ClassDB::bind_method(D_METHOD("get_mirror_rotation"), &MCurveInstanceElement::get_mirror_rotation);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL,"mirror_rotation"), "set_mirror_rotation", "get_mirror_rotation");

    ClassDB::bind_method(D_METHOD("set_interval","input"), &MCurveInstanceElement::set_interval);
    ClassDB::bind_method(D_METHOD("get_interval"), &MCurveInstanceElement::get_interval);
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT,"interval"), "set_interval", "get_interval");

    ClassDB::bind_method(D_METHOD("set_offset","input"), &MCurveInstanceElement::set_offset);
    ClassDB::bind_method(D_METHOD("get_offset"), &MCurveInstanceElement::get_offset);
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR3,"offset"), "set_offset", "get_offset");

    ClassDB::bind_method(D_METHOD("set_rotation","input"), &MCurveInstanceElement::set_rotation);
    ClassDB::bind_method(D_METHOD("get_rotation"), &MCurveInstanceElement::get_rotation);
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR3,"roation"), "set_rotation", "get_rotation");

    ClassDB::bind_method(D_METHOD("set_scale","input"), &MCurveInstanceElement::set_scale);
    ClassDB::bind_method(D_METHOD("get_scale"), &MCurveInstanceElement::get_scale);
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR3,"scale"), "set_scale", "get_scale");

    ADD_GROUP("Placement Random","");

    ADD_SUBGROUP("Offset","");

    ClassDB::bind_method(D_METHOD("set_rand_offset_start","input"), &MCurveInstanceElement::set_rand_offset_start);
    ClassDB::bind_method(D_METHOD("get_rand_offset_start"), &MCurveInstanceElement::get_rand_offset_start);
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR3,"rand_offset_start"), "set_rand_offset_start", "get_rand_offset_start");

    ClassDB::bind_method(D_METHOD("set_rand_offset_end","input"), &MCurveInstanceElement::set_rand_offset_end);
    ClassDB::bind_method(D_METHOD("get_rand_offset_end"), &MCurveInstanceElement::get_rand_offset_end);
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR3,"rand_offset_end"), "set_rand_offset_end", "get_rand_offset_end");

    ADD_SUBGROUP("Rotation","");

    ClassDB::bind_method(D_METHOD("set_rand_rotation_start","input"), &MCurveInstanceElement::set_rand_rotation_start);
    ClassDB::bind_method(D_METHOD("get_rand_rotation_start"), &MCurveInstanceElement::get_rand_rotation_start);
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR3,"rand_rotation_start"), "set_rand_rotation_start", "get_rand_rotation_start");

    ClassDB::bind_method(D_METHOD("set_rand_rotation_end","input"), &MCurveInstanceElement::set_rand_rotation_end);
    ClassDB::bind_method(D_METHOD("get_rand_rotation_end"), &MCurveInstanceElement::get_rand_rotation_end);
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR3,"rand_rotation_end"), "set_rand_rotation_end", "get_rand_rotation_end");

    ADD_SUBGROUP("Scale","");

    ClassDB::bind_method(D_METHOD("set_rand_scale_start","input"), &MCurveInstanceElement::set_rand_scale_start);
    ClassDB::bind_method(D_METHOD("get_rand_scale_start"), &MCurveInstanceElement::get_rand_scale_start);
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR3,"rand_scale_start"), "set_rand_scale_start", "get_rand_scale_start");

    ClassDB::bind_method(D_METHOD("set_rand_scale_end","input"), &MCurveInstanceElement::set_rand_scale_end);
    ClassDB::bind_method(D_METHOD("get_rand_scale_end"), &MCurveInstanceElement::get_rand_scale_end);
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR3,"rand_scale_end"), "set_rand_scale_end", "get_rand_scale_end");

    ADD_SUBGROUP("Uniform Scale","");

    ClassDB::bind_method(D_METHOD("set_rand_uniform_scale_start","input"), &MCurveInstanceElement::set_rand_uniform_scale_start);
    ClassDB::bind_method(D_METHOD("get_rand_uniform_scale_start"), &MCurveInstanceElement::get_rand_uniform_scale_start);
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT,"rand_uniform_scale_start"), "set_rand_uniform_scale_start", "get_rand_uniform_scale_start");

    ClassDB::bind_method(D_METHOD("set_rand_uniform_scale_end","input"), &MCurveInstanceElement::set_rand_uniform_scale_end);
    ClassDB::bind_method(D_METHOD("get_rand_uniform_scale_end"), &MCurveInstanceElement::get_rand_uniform_scale_end);
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT,"rand_uniform_scale_end"), "set_rand_uniform_scale_end", "get_rand_uniform_scale_end");

    ADD_GROUP("Shape in Mesh Space","");

    ClassDB::bind_method(D_METHOD("set_shape_local_position","input"), &MCurveInstanceElement::set_shape_local_position);
    ClassDB::bind_method(D_METHOD("get_shape_local_position"), &MCurveInstanceElement::get_shape_local_position);
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR3,"shape_local_position"), "set_shape_local_position", "get_shape_local_position");

    ClassDB::bind_method(D_METHOD("set_shape_local_basis","input"), &MCurveInstanceElement::set_shape_local_basis);
    ClassDB::bind_method(D_METHOD("get_shape_local_basis"), &MCurveInstanceElement::get_shape_local_basis);
    ADD_PROPERTY(PropertyInfo(Variant::BASIS,"shape_local_basis"), "set_shape_local_basis", "get_shape_local_basis");

    ADD_GROUP("Render Settings","");
    
    ClassDB::bind_method(D_METHOD("set_shadow_setting","input"), &MCurveInstanceElement::set_shadow_setting);
    ClassDB::bind_method(D_METHOD("get_shadow_setting"), &MCurveInstanceElement::get_shadow_setting);
    ADD_PROPERTY(PropertyInfo(Variant::INT,"shadow_setting",PropertyHint::PROPERTY_HINT_ENUM,"OFF,ON,DOUBLE_SIDED,SHADOWS_ONLY"), "set_shadow_setting","get_shadow_setting");

    ClassDB::bind_method(D_METHOD("set_render_layers","input"), &MCurveInstanceElement::set_render_layers);
    ClassDB::bind_method(D_METHOD("get_render_layers"), &MCurveInstanceElement::get_render_layers);
    ADD_PROPERTY(PropertyInfo(Variant::INT,"render_layers",PROPERTY_HINT_LAYERS_3D_RENDER), "set_render_layers","get_render_layers");

    ADD_GROUP("Physics Settings","");

    ClassDB::bind_method(D_METHOD("set_physics_material","input"), &MCurveInstanceElement::set_physics_material);
    ClassDB::bind_method(D_METHOD("get_physics_material"), &MCurveInstanceElement::get_physics_material);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT,"physics_material",PROPERTY_HINT_RESOURCE_TYPE,"PhysicsMaterial"), "set_physics_material","get_physics_material");

    ClassDB::bind_method(D_METHOD("set_collision_layer","input"), &MCurveInstanceElement::set_collision_layer);
    ClassDB::bind_method(D_METHOD("get_collision_layer"), &MCurveInstanceElement::get_collision_layer);
    ADD_PROPERTY(PropertyInfo(Variant::INT,"collision_layer",PROPERTY_HINT_LAYERS_3D_PHYSICS), "set_collision_layer","get_collision_layer");

    ClassDB::bind_method(D_METHOD("set_collision_mask","input"), &MCurveInstanceElement::set_collision_mask);
    ClassDB::bind_method(D_METHOD("get_collision_mask"), &MCurveInstanceElement::get_collision_mask);
    ADD_PROPERTY(PropertyInfo(Variant::INT,"collision_mask",PROPERTY_HINT_LAYERS_3D_PHYSICS), "set_collision_mask","get_collision_mask");
}

void MCurveInstanceElement::emit_elements_changed(){
    _generate_transforms();
    emit_signal("elements_changed");
}

void MCurveInstanceElement::set_element_name(const String& input){
    set_name(input);
}

String MCurveInstanceElement::get_element_name(){
    return get_name();
}


void MCurveInstanceElement::set_mesh(Ref<MMeshLod> input){
    if(mesh.is_valid()){
        mesh->disconnect("meshes_changed",Callable(this,"emit_elements_changed"));
    }
    mesh = input;
    if(mesh.is_valid()){
        mesh->connect("meshes_changed",Callable(this,"emit_elements_changed"));
    }
    emit_elements_changed();
}

void MCurveInstanceElement::set_seed(int input){
    seed = input;
    emit_elements_changed();
}

int MCurveInstanceElement::get_seed() const{
    return seed;
}


Ref<MMeshLod> MCurveInstanceElement::get_mesh() const{
    return mesh;
}

void MCurveInstanceElement::set_shape(Ref<Shape3D> input){
    shape = input;
}

Ref<Shape3D> MCurveInstanceElement::get_shape() const{
    return shape;
}

void MCurveInstanceElement::set_shape_lod_cutoff(int8_t input){
    shape_lod_cutoff = input;
}

int8_t MCurveInstanceElement::get_shape_lod_cutoff() const{
    return shape_lod_cutoff;
}

void MCurveInstanceElement::set_middle(bool input){
    middle = input;
    emit_elements_changed();
}

bool MCurveInstanceElement::get_middle() const{
    return middle;
}


void MCurveInstanceElement::set_include_end(bool input){
    include_end = input;
    emit_elements_changed();
}

bool MCurveInstanceElement::get_include_end() const{
    return include_end;
}


void MCurveInstanceElement::set_mirror_rotation(bool input){
    mirror_rotation = input;
    emit_elements_changed();
}

bool MCurveInstanceElement::get_mirror_rotation() const{
    return mirror_rotation;
}


void MCurveInstanceElement::set_mirror(bool input){
    mirror = input;
    emit_elements_changed();
}

bool MCurveInstanceElement::get_mirror() const{
    return mirror;
}

void MCurveInstanceElement::set_interval(float input){
    if(input >= 0.01){
        interval = input;
        emit_elements_changed();
    }
}

float MCurveInstanceElement::get_interval() const{
    return interval;
}


void MCurveInstanceElement::set_offset(const Vector3& input){
    offset = input;
    emit_elements_changed();
}

Vector3 MCurveInstanceElement::get_offset() const{
    return offset;
}


void MCurveInstanceElement::set_rotation(const Vector3& input){
    rotation = input;
    emit_elements_changed();
}

Vector3 MCurveInstanceElement::get_rotation() const{
    return rotation;
}


void MCurveInstanceElement::set_scale(const Vector3& input){
    scale = input;
    emit_elements_changed();
}

Vector3 MCurveInstanceElement::get_scale() const{
    return scale;
}


// rand
void MCurveInstanceElement::set_rand_offset_start(const Vector3& input){
    rand_offset_start = input;
    emit_elements_changed();
}

Vector3 MCurveInstanceElement::get_rand_offset_start() const{
    return rand_offset_start;
}


void MCurveInstanceElement::set_rand_offset_end(const Vector3& input){
    rand_offset_end = input;
    emit_elements_changed();
}

Vector3 MCurveInstanceElement::get_rand_offset_end() const{
    return rand_offset_end;
}


void MCurveInstanceElement::set_rand_rotation_start(const Vector3& input){
    rand_rotation_start = input;
    emit_elements_changed();
}

Vector3 MCurveInstanceElement::get_rand_rotation_start() const{
    return rand_rotation_start;
}

void MCurveInstanceElement::set_rand_rotation_end(const Vector3& input){
    rand_rotation_end = input;
    emit_elements_changed();
}

Vector3 MCurveInstanceElement::get_rand_rotation_end() const{
    return rand_rotation_end;
}

void MCurveInstanceElement::set_rand_scale_start(const Vector3& input){
    rand_scale_start = input;
    emit_elements_changed();
}

Vector3 MCurveInstanceElement::get_rand_scale_start() const{
    return rand_scale_start;
}


void MCurveInstanceElement::set_rand_scale_end(const Vector3& input){
    rand_scale_end = input;
    emit_elements_changed();
}

Vector3 MCurveInstanceElement::get_rand_scale_end() const{
    return rand_scale_end;
}

void MCurveInstanceElement::set_rand_uniform_scale_start(float input){
    rand_uniform_scale_start = input;
    emit_elements_changed();
}

float MCurveInstanceElement::get_rand_uniform_scale_start() const{
    return rand_uniform_scale_start;
}

void MCurveInstanceElement::set_rand_uniform_scale_end(float input){
    rand_uniform_scale_end = input;
    emit_elements_changed();
}

float MCurveInstanceElement::get_rand_uniform_scale_end() const{
    return rand_uniform_scale_end;
}

void MCurveInstanceElement::set_shape_local_position(const Vector3& input){
    shape_local_position = input;
    emit_elements_changed();
}

Vector3 MCurveInstanceElement::get_shape_local_position() const{
    return shape_local_position;
}

void MCurveInstanceElement::set_shape_local_basis(const Basis& input){
    shape_local_basis = input;
    emit_elements_changed();
}

Basis MCurveInstanceElement::get_shape_local_basis() const{
    return shape_local_basis;
}

void MCurveInstanceElement::set_shadow_setting(RenderingServer::ShadowCastingSetting input){
    shadow_setting = input;
    emit_elements_changed();
}

RenderingServer::ShadowCastingSetting MCurveInstanceElement::get_shadow_setting(){
    return shadow_setting;
}

void MCurveInstanceElement::set_render_layers(uint32_t input){
    render_layers = input;
    emit_elements_changed();
}

uint32_t MCurveInstanceElement::get_render_layers() const{
    return render_layers;
}

void MCurveInstanceElement::set_physics_material(Ref<PhysicsMaterial> input){
    physics_material = input;
    emit_elements_changed();
}

Ref<PhysicsMaterial> MCurveInstanceElement::get_physics_material() const{
    return physics_material;
}

void MCurveInstanceElement::set_collision_layer(uint32_t input){
    collision_layer = input;
    emit_elements_changed();
}

uint32_t MCurveInstanceElement::get_collision_layer() const{
    return collision_layer;
}

void MCurveInstanceElement::set_collision_mask(uint32_t input){
    collision_mask = input;
    emit_elements_changed();
}

uint32_t MCurveInstanceElement::get_collision_mask() const{
    return collision_mask;
}

///////////////////////////////////////////////////////////////////////
//////////////// Override Data
///////////////////////////////////////////////////////////////////////

MCurveInstanceOverride::OverrideData::OverrideData(){
    for(int i=0; i < M_CURVE_CONNECTION_INSTANCE_COUNT; i++){
        element_ovveride[i] = -1;
        start_offset[i] = 0;
        end_offset[i] = 0;
        random_remove[i] = 0;
    }
}

void MCurveInstanceOverride::_bind_methods(){
    ADD_SIGNAL(MethodInfo("connection_changed",PropertyInfo(Variant::INT,"conn_id")));

    ClassDB::bind_method(D_METHOD("get_conn_element_capacity","conn_id"), &MCurveInstanceOverride::get_conn_element_capacity);

    ClassDB::bind_method(D_METHOD("set_exclude_connection","conn_id","value"), &MCurveInstanceOverride::set_exclude_connection);
    ClassDB::bind_method(D_METHOD("is_exclude_connection","conn_id"), &MCurveInstanceOverride::is_exclude_connection);

    ClassDB::bind_method(D_METHOD("add_element","conn_id","element_index"), &MCurveInstanceOverride::add_element);
    ClassDB::bind_method(D_METHOD("remove_element","conn_id","element_index"), &MCurveInstanceOverride::remove_element);
    ClassDB::bind_method(D_METHOD("get_elements","conn_id"), &MCurveInstanceOverride::get_elements);
    ClassDB::bind_method(D_METHOD("has_element","conn_id","element_index"), &MCurveInstanceOverride::has_element);
    ClassDB::bind_method(D_METHOD("clear_to_default","conn_id"), &MCurveInstanceOverride::clear_to_default);
    ClassDB::bind_method(D_METHOD("has_override","conn_id"), &MCurveInstanceOverride::has_override);

    ClassDB::bind_method(D_METHOD("set_start_offset","conn_id","element_index","value"), &MCurveInstanceOverride::set_start_offset);
    ClassDB::bind_method(D_METHOD("get_start_offset","conn_id","element_index"), &MCurveInstanceOverride::get_start_offset);

    ClassDB::bind_method(D_METHOD("set_end_offset","conn_id","value"), &MCurveInstanceOverride::set_end_offset);
    ClassDB::bind_method(D_METHOD("get_end_offset","conn_id"), &MCurveInstanceOverride::get_end_offset);

    ClassDB::bind_method(D_METHOD("set_rand_remove","conn_id","value"), &MCurveInstanceOverride::set_rand_remove);
    ClassDB::bind_method(D_METHOD("get_rand_remove","conn_id"), &MCurveInstanceOverride::get_rand_remove);

    ClassDB::bind_method(D_METHOD("set_data","input"), &MCurveInstanceOverride::set_data);
    ClassDB::bind_method(D_METHOD("get_data"), &MCurveInstanceOverride::get_data);
    ADD_PROPERTY(PropertyInfo(Variant::PACKED_BYTE_ARRAY,"data",PROPERTY_HINT_NONE,"",PROPERTY_USAGE_STORAGE),"set_data","get_data");
}

void MCurveInstanceOverride::emit_connection_changed(int64_t conn_id){
    emit_signal("connection_changed",conn_id);
}

int MCurveInstanceOverride::get_conn_element_capacity(int64_t conn_id) const{
    auto it = data.find(conn_id);
    if(it==data.end()){
        // in this case max is it should be empty
        return M_CURVE_CONNECTION_INSTANCE_COUNT;
    }
    const OverrideData& ov = it->value;
    int capacity = 0;
    for(int i=0; i < M_CURVE_CONNECTION_INSTANCE_COUNT; i++){
        if(ov.element_ovveride[i]==-1){
            capacity++;
        }
    }
    return capacity;
}

void MCurveInstanceOverride::set_exclude_connection(int64_t conn_id,bool value){
    auto it = data.find(conn_id);
    if(it==data.end()){
        data.insert(conn_id,OverrideData());
        it = data.find(conn_id);
        ERR_FAIL_COND(it==data.end());
    } else if(!value && !it->value.has_any_element()){
        data.erase(conn_id);
        emit_connection_changed(conn_id);
        return;
    }
    OverrideData& ov = it->value;
    ov.is_exclude = value;
    emit_connection_changed(conn_id);
}

bool MCurveInstanceOverride::is_exclude_connection(int64_t conn_id) const{
    auto it = data.find(conn_id);
    if(it==data.end()){
        WARN_PRINT("Not found!");
        return false;
    }
    const OverrideData& ov = it->value;
    return ov.is_exclude;
}


void MCurveInstanceOverride::add_element(int64_t conn_id,int element_index){
    auto it = data.find(conn_id);
    if(it==data.end()){
        data.insert(conn_id,OverrideData());
        it = data.find(conn_id);
        ERR_FAIL_COND(it==data.end());
    }
    OverrideData& ov = it->value;
    for(int i=0; i < M_CURVE_CONNECTION_INSTANCE_COUNT; i++){
        if(ov.element_ovveride[i]==element_index){
            ERR_FAIL_MSG("Duplicate Element!");
        }
    }
    for(int i=0; i < M_CURVE_CONNECTION_INSTANCE_COUNT; i++){
        if(ov.element_ovveride[i]==-1){
            ov.element_ovveride[i] = element_index;
            ov.is_exclude = false;
            emit_connection_changed(conn_id);
            return;
        }
    }
    ERR_FAIL_MSG("No free element found check element capcity with MCurveInstanceOverride::get_conn_element_capacity");
}

void MCurveInstanceOverride::remove_element(int64_t conn_id,int element_index){
    auto it = data.find(conn_id);
    if(it==data.end()){
        WARN_PRINT("Element "+itos(element_index)+" not found for remove!");
        return;
    }
    OverrideData& ov = it->value;
    for(int i=0; i < M_CURVE_CONNECTION_INSTANCE_COUNT; i++){
        if(ov.element_ovveride[i]==element_index){
            ov.element_ovveride[i] = -1;
            if(!ov.has_any_element()){
                data.erase(conn_id);
            }
            emit_connection_changed(conn_id);
            return;
        }
    }
    WARN_PRINT("In OverrideData Element "+itos(element_index)+" not found for remove!");
}

PackedByteArray MCurveInstanceOverride::get_elements(int64_t conn_id) const{
    PackedByteArray out;
    auto it = data.find(conn_id);
    if(it==data.end()){
        return out;
    }
    const OverrideData& ov = it->value;
    for(int i=0; i < M_CURVE_CONNECTION_INSTANCE_COUNT; i++){
        if(ov.element_ovveride[i]==-1){
            out.push_back(ov.element_ovveride[i]);
        }
    }
    return out;
}

bool MCurveInstanceOverride::has_element(int64_t conn_id,int8_t element_index) const{
    PackedByteArray out;
    auto it = data.find(conn_id);
    if(it==data.end()){
        return false;
    };
    const OverrideData& ov = it->value;
    for(int i=0; i < M_CURVE_CONNECTION_INSTANCE_COUNT; i++){
        if(ov.element_ovveride[i]==element_index){
            return true;
        }
    }
    return false;
}

void MCurveInstanceOverride::clear_to_default(int64_t conn_id){
    data.erase(conn_id);
    emit_connection_changed(conn_id);
}

bool MCurveInstanceOverride::has_override(int64_t conn_id) const{
    return data.has(conn_id);
}

void MCurveInstanceOverride::set_start_offset(int64_t conn_id,int element_index,float val){
    auto it = data.find(conn_id);
    if(it==data.end()){
        data.insert(conn_id,OverrideData());
        it = data.find(conn_id);
        ERR_FAIL_COND(it==data.end());
    }
    OverrideData& ov = it->value;
    for(int i=0; i < M_CURVE_CONNECTION_INSTANCE_COUNT; i++){
        if(ov.element_ovveride[i]==element_index){
            ov.start_offset[i].set_float(val);
            emit_connection_changed(conn_id);
            return;
        }
    }
    ERR_FAIL_MSG("set_start_offset element not found!");
}

float MCurveInstanceOverride::get_start_offset(int64_t conn_id,int element_index) const{
    auto it = data.find(conn_id);
    if(it==data.end()){
        return 0;
    }
    const OverrideData& ov = it->value;
    for(int i=0; i < M_CURVE_CONNECTION_INSTANCE_COUNT; i++){
        if(ov.element_ovveride[i]==element_index){
            return ov.start_offset[i].get_float();
        }
    }
    ERR_FAIL_V_MSG(0.0f,"get_start_offset element not found!");
}

void MCurveInstanceOverride::set_end_offset(int64_t conn_id,int element_index,float val){
    auto it = data.find(conn_id);
    if(it==data.end()){
        data.insert(conn_id,OverrideData());
        it = data.find(conn_id);
        ERR_FAIL_COND(it==data.end());
    }
    OverrideData& ov = it->value;
    for(int i=0; i < M_CURVE_CONNECTION_INSTANCE_COUNT; i++){
        if(ov.element_ovveride[i]==element_index){
            ov.end_offset[i].set_float(val);
            emit_connection_changed(conn_id);
            return;
        }
    }
    ERR_FAIL_MSG("set_end_offset element not found!");
}

float MCurveInstanceOverride::get_end_offset(int64_t conn_id,int element_index) const{
    auto it = data.find(conn_id);
    if(it==data.end()){
        return 0;
    }
    const OverrideData& ov = it->value;
    for(int i=0; i < M_CURVE_CONNECTION_INSTANCE_COUNT; i++){
        if(ov.element_ovveride[i]==element_index){
            return ov.end_offset[i].get_float();
        }
    }
    ERR_FAIL_V_MSG(0.0f,"get_end_offset element not found!");
}

void MCurveInstanceOverride::set_rand_remove(int64_t conn_id,int element_index,float val){
    auto it = data.find(conn_id);
    if(it==data.end()){
        data.insert(conn_id,OverrideData());
        it = data.find(conn_id);
        ERR_FAIL_COND(it==data.end());
    }
    OverrideData& ov = it->value;
    for(int i=0; i < M_CURVE_CONNECTION_INSTANCE_COUNT; i++){
        if(ov.element_ovveride[i]==element_index){
            ov.random_remove[i].set_float(val);
            emit_connection_changed(conn_id);
            return;
        }
    }
    ERR_FAIL_MSG("set_rand_remove element not found!");
}

float MCurveInstanceOverride::get_rand_remove(int64_t conn_id,int element_index) const{
    auto it = data.find(conn_id);
    if(it==data.end()){
        return 0;
    }
    const OverrideData& ov = it->value;
    for(int i=0; i < M_CURVE_CONNECTION_INSTANCE_COUNT; i++){
        if(ov.element_ovveride[i]==element_index){
            return ov.random_remove[i].get_float();
        }
    }
    ERR_FAIL_V_MSG(0.0f,"get_rand_remove element not found!");
}

void MCurveInstanceOverride::set_data(const PackedByteArray& input){
    using OvPair = Pair<int64_t,OverrideData>;
    constexpr size_t osize = sizeof(OvPair);
    ERR_FAIL_COND(input.size()%osize!=0);
    int count = input.size()/osize;
    size_t head = 0;
    data.clear();
    for(int i=0; i < count; i++){
        OvPair ov;
        memcpy(&ov,input.ptr()+head,osize);
        head += osize;
        data.insert(ov.first,ov.second);
    }
}

PackedByteArray MCurveInstanceOverride::get_data() const {
    PackedByteArray out;
    using OvPair = Pair<int64_t,OverrideData>;
    constexpr size_t osize = sizeof(OvPair);
    out.resize(osize*data.size());
    size_t head = 0;
    for(auto it=data.begin();it!=data.end();++it){
        OvPair ov_pair = {it->key, it->value};
        memcpy(out.ptrw()+head,&ov_pair,osize);
        head += osize;
    }
    return out;
}

///////////////////////////////////////////////////////////////////////
//////////////// Curve Instance 
///////////////////////////////////////////////////////////////////////

void MCurveInstance::_bind_methods(){

    ClassDB::bind_method(D_METHOD("_update_visibilty"), &MCurveInstance::_update_visibilty);

    ClassDB::bind_method(D_METHOD("set_override","input"), &MCurveInstance::set_override);
    ClassDB::bind_method(D_METHOD("get_override"), &MCurveInstance::get_override);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT,"override_data",PROPERTY_HINT_RESOURCE_TYPE,"MCurveInstanceOverride"), "set_override","get_override");

    ClassDB::bind_method(D_METHOD("set_default_element","input"), &MCurveInstance::set_default_element);
    ClassDB::bind_method(D_METHOD("get_default_element"), &MCurveInstance::get_default_element);
    ADD_PROPERTY(PropertyInfo(Variant::INT,"default_element"), "set_default_element","get_default_element");

    ClassDB::bind_method(D_METHOD("set_element","input","instance_index"), &MCurveInstance::set_element);
    ClassDB::bind_method(D_METHOD("get_element","instance_index"), &MCurveInstance::get_element);
    for(int i=0; i < M_CURVE_ELEMENT_COUNT; i++){
        ADD_PROPERTYI(PropertyInfo(Variant::OBJECT,"element_"+itos(i),PROPERTY_HINT_RESOURCE_TYPE,"MCurveInstanceElement"), "set_element","get_element",i);
    }
    ClassDB::bind_method(D_METHOD("_on_curve_changed"), &MCurveInstance::_on_curve_changed);
    ClassDB::bind_method(D_METHOD("_on_connections_updated"), &MCurveInstance::_on_connections_updated);
    ClassDB::bind_method(D_METHOD("_connection_force_update"), &MCurveInstance::_connection_force_update);
    ClassDB::bind_method(D_METHOD("_connection_remove"), &MCurveInstance::_connection_remove);
    ClassDB::bind_method(D_METHOD("_recreate"), &MCurveInstance::_recreate);

    ClassDB::bind_static_method("MCurveInstance",D_METHOD("get_instance_count"), &MCurveInstance::get_instance_count);
    ClassDB::bind_static_method("MCurveInstance",D_METHOD("get_element_count"), &MCurveInstance::get_element_count);
}

/*
void MCurveInstance::_update_physics_body(){
    if(physics_body.is_valid()){
        PS->body_set_collision_layer(physics_body,collision_layer);
        PS->body_set_collision_mask(physics_body,collision_layer);
        if(physics_material.is_valid()){
            float friction = physics_material->is_rough() ? - physics_material->get_friction() : physics_material->get_friction();
            float bounce = physics_material->is_absorbent() ? - physics_material->get_bounce() : physics_material->get_bounce();
            PS->body_set_param(physics_body,PhysicsServer3D::BODY_PARAM_BOUNCE,bounce);
            PS->body_set_param(physics_body,PhysicsServer3D::BODY_PARAM_FRICTION,friction);
        }
    }
}
*/

MCurveInstance::MCurveInstance(){
    connect("tree_exited", Callable(this, "_update_visibilty"));
    connect("tree_entered", Callable(this, "_update_visibilty"));
}

MCurveInstance::~MCurveInstance(){
    _remove_all_instance();
}

void MCurveInstance::_on_connections_updated(){
    std::lock_guard<std::recursive_mutex> lock(update_mutex);
    //ERR_FAIL_COND(!UtilityFunctions::is_instance_valid(path));
    ERR_FAIL_COND(curve.is_null());
    thread_task_id = WorkerThreadPool::get_singleton()->add_native_task(&MCurveInstance::thread_update,(void*)this);
    is_thread_updating = true;
    set_process(true);
}

void MCurveInstance::thread_update(void* input){
    MCurveInstance* curve_instance = (MCurveInstance*)input;
    std::lock_guard<std::recursive_mutex> lock(curve_instance->update_mutex);
    ERR_FAIL_COND(curve_instance->curve.is_null());
    Ref<MCurve> curve = curve_instance->curve;
    for(int i=0; i < curve->conn_update.size(); i++){
        curve_instance->_generate_connection(curve->conn_update[i]);
    }
}

void MCurveInstance::_generate_connection(const MCurve::ConnUpdateInfo& update_info,bool immediate_update){
    int64_t cid = update_info.conn_id;
    int lod = update_info.current_lod;
    int last_lod = update_info.last_lod;
    if(lod==-1 || curve.is_null()){
        _remove_instance(cid);
        return;
    }
    // Getting instances
    Instances* instances;
    godot::HashMap<int64_t, MCurveInstance::Instances>::Iterator it = curve_instance_instances.find(cid);
    if(it==curve_instance_instances.end()){
        Instances new_instance;
        it = curve_instance_instances.insert(cid,new_instance);
    }
    ERR_FAIL_COND(it==curve_instance_instances.end());
    instances = &it->value;
    // Looping in instance index
    OverrideData ov_data = get_default_override_data();
    if(override_data.is_valid()){
        auto it = override_data->data.find(cid);
        if(it!=override_data->data.end()){
            ov_data = it->value;
        }
    }
    if(ov_data.is_exclude){ // condition which ignore conn entirly
        _remove_instance(cid);
        return;
    }
    //////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////// Instance Index Loop ///////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////
    for(int instance_index=0; instance_index < M_CURVE_CONNECTION_INSTANCE_COUNT; instance_index++){
        int element_index = ov_data.element_ovveride[instance_index];
        if(element_index < 0 || element_index >= M_CURVE_ELEMENT_COUNT){
            _remove_instance(cid,instance_index,false);
            continue; // No element
        }
        Ref<MCurveInstanceElement> element = elements[element_index];
        if(element.is_null()){
            _remove_instance(cid,instance_index,false);
            continue; // No element
        }
        RID mesh = element->get_mesh_lod(lod);
        // Cheating LOD into shape
        RID shape = element->shape_lod_cutoff > lod ? element->get_shape_rid() : RID();
        if(!mesh.is_valid() && !shape.is_valid()){
            _remove_instance(cid,instance_index,false); // No mesh so removing
            continue;
        }
        // Checking if has instance!
        Instance& instance = instances->instances[instance_index];
        if(instance.mesh_rid == mesh && shape==instance.shape){
            continue; // Is same so no change
        }
        instance.mesh_rid = mesh;
        instance.shape = shape;
        //////////////////////////////////////////////////////////////////////////////////////////////
        ///////////////////////Creating Instance///////////////////////////////
        //////////////////////////////////////////////////////////////////////////////////////////////
        {
            float curve_len = curve->get_conn_lenght(cid);
            float start_offset_len = curve_len*ov_data.start_offset[instance_index];
            float end_offset_len = curve_len*ov_data.end_offset[instance_index];
            curve_len = curve_len - (start_offset_len + end_offset_len);
            if(curve_len < M_CURVE_INSTANCE_EPSILON){
                _remove_instance(cid,instance_index,false); // No mesh so removing
                continue;
            }
            int total_mesh_count = curve_len/element->interval;
            float rinterval = curve_len/total_mesh_count; // true interval due to integer rounding
            if(total_mesh_count==0){
                _remove_instance(cid,instance_index,false); // No mesh so removing
                continue;
            }
            Vector<Transform3D> transforms;
            /// Creating Transforms
            {
                Vector<float> ratios;
                {
                    Vector<float> distances;
                    if(!element->middle && element->include_end){
                        total_mesh_count++;
                    }
                    distances.resize(total_mesh_count);
                    float current_dis = element->middle ? rinterval/2.0f : 0.0f;
                    current_dis += start_offset_len;
                    for(int i=0; i < total_mesh_count; i++){
                        distances.set(i,current_dis);
                        current_dis += rinterval;
                    }
                    curve->get_conn_distances_ratios(cid,distances,ratios);
                }
                ERR_FAIL_COND(ratios.size()!=total_mesh_count);
                curve->get_conn_transforms(cid,ratios,transforms);
                ERR_FAIL_COND(transforms.size()!=total_mesh_count);
            }
            //// End of creating transforms
            ////////////////////////////////////
            PackedFloat32Array multimesh_buffer;
            int multimesh_buffer_index=0;
            int item_count =0;
            ///////////////////// Creating multimesh buffer and adding shapes
            instance.ensure_physics_body_exist(path->get_space(),element->collision_layer,element->collision_mask,element->physics_material);
            RID body = instance.body;
            for(int i=0; i < total_mesh_count; i++){
                // should check for element->index_exist here as element->index_exist_mirror might have different result
                if(element->index_exist(i,ov_data.random_remove[instance_index])){
                    // mesh
                    Transform3D t = element->modify_transform(transforms[i],i);
                    if(mesh.is_valid()){
                        _set_multimesh_buffer(multimesh_buffer,t,multimesh_buffer_index);
                    }
                    // shape
                    if(shape.is_valid()){
                        t = element->modify_transform_shape(t);
                        PS->body_add_shape(body,shape,t);
                    }
                    // adding count
                    item_count++;
                }
                if(element->mirror && element->index_exist_mirror(i,ov_data.random_remove[instance_index])){
                    // mesh
                    Transform3D t = element->modify_transform_mirror(transforms[i],i);
                    if(mesh.is_valid()){
                        _set_multimesh_buffer(multimesh_buffer,t,multimesh_buffer_index);
                    }
                    // shape
                    if(shape.is_valid()){
                        t = element->modify_transform_mirror_shape(t);
                        PS->body_add_shape(body,shape,t);
                    }
                    // adding count
                    item_count++;
                }
            }
            if(item_count==0){
                _remove_instance(cid,instance_index,false);
                continue;
            }
            // Adding meshes
            if(mesh.is_valid()){
                instance.ensure_render_instance_exist(path->get_scenario(),element->render_layers,element->shadow_setting);
                instance.count = item_count;
                ERR_FAIL_COND(!instance.mesh_rid.is_valid());
                RS->multimesh_set_mesh(instance.multimesh,instance.mesh_rid);
                RS->multimesh_allocate_data(instance.multimesh,item_count,RenderingServer::MULTIMESH_TRANSFORM_3D,false,false);
                RS->multimesh_set_buffer(instance.multimesh,multimesh_buffer);
            }
        }
        //////////////////////////////////////////////////////////////////////////////////////////////////
        //////////////////// END Creating Instance ///////////////////////////////////////////////
        //////////////////////////////////////////////////////////////////////////////////////////////////
    }
    //////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////// END Instance Index Loop ///////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////
    if(!instances->has_valid_instance()){
        curve_instance_instances.erase(cid);
    }
}

void MCurveInstance::_update_visibilty(){
    if(path==nullptr || curve.is_null()){
        return;
    }
    bool v = path->is_visible() && path->is_inside_tree() && is_inside_tree();
    for(auto it=curve_instance_instances.begin();it!=curve_instance_instances.end();++it){
        Instances& instances = it->value;
        for(int j=0; j < M_CURVE_CONNECTION_INSTANCE_COUNT; j++){
            if(instances[j].instance.is_valid()){
                RS->instance_set_visible(instances[j].instance,v);
            }
        }
    }
}

void MCurveInstance::_connection_force_update(int64_t conn_id){
    ERR_FAIL_COND(curve.is_null());
    std::lock_guard<std::recursive_mutex> lock(update_mutex);
    _remove_instance(conn_id);
    MCurve::ConnUpdateInfo cu;
    cu.last_lod = -1;
    cu.current_lod = curve->get_conn_lod(conn_id);
    cu.conn_id = conn_id;
    _generate_connection(cu,true);
}

void MCurveInstance::_connection_remove(int64_t conn_id){
    std::lock_guard<std::recursive_mutex> lock(update_mutex);
    ERR_FAIL_COND(curve.is_null());
    _remove_instance(conn_id);
}

void MCurveInstance::_recreate(){
    std::lock_guard<std::recursive_mutex> lock(update_mutex);
    _remove_all_instance();
    if(curve.is_null()){
        return;
    }
    PackedInt64Array conns = curve->get_active_conns();
    for(int i=0;i<conns.size();++i){
        MCurve::ConnUpdateInfo cu;
        cu.last_lod = -1;
        cu.current_lod = curve->get_conn_lod(conns[i]);
        cu.conn_id = conns[i];
        _generate_connection(cu,true);
    }
}

void MCurveInstance::_remove_instance(int64_t conn_id,int instance_index,bool rm_curve_instance_instances){
    auto it = curve_instance_instances.find(conn_id);
    if(it==curve_instance_instances.end()){
        return;
    }
    Instances& instances = it->value;
    if(instance_index!=-1){
        if(instances[instance_index].multimesh.is_valid()){
            RS->free_rid(instances[instance_index].multimesh);
            instances[instance_index].multimesh = RID();
        }
        if(instances[instance_index].instance.is_valid()){
            RS->free_rid(instances[instance_index].instance);
            instances[instance_index].instance = RID();
        }
        if(instances[instance_index].body.is_valid()){
            PS->free_rid(instances[instance_index].body);
            instances[instance_index].body = RID();
        }
        instances[instance_index].mesh_rid = RID();
        instances[instance_index].shape = RID();
        if(!instances.has_valid_instance() && rm_curve_instance_instances){
            curve_instance_instances.erase(conn_id);
        }
    } else{
        for(int i=0; i < M_CURVE_CONNECTION_INSTANCE_COUNT; i++){
            if(instances[i].multimesh.is_valid()){
                RS->free_rid(instances[i].multimesh);
            }
            if(instances[i].instance.is_valid()){
                RS->free_rid(instances[i].instance);
            }
            if(instances[i].body.is_valid()){
                PS->free_rid(instances[i].body);
            }
        }
        if(rm_curve_instance_instances){
            curve_instance_instances.erase(conn_id);
        }
    }
}

void MCurveInstance::_remove_all_instance(){
    for(auto it=curve_instance_instances.begin();it!=curve_instance_instances.end();++it){
        Instances& instances = it->value;
        for(int i=0; i < M_CURVE_CONNECTION_INSTANCE_COUNT; i++){
            if(instances[i].multimesh.is_valid()){
                RS->free_rid(instances[i].multimesh);
            }
            if(instances[i].instance.is_valid()){
                RS->free_rid(instances[i].instance);
            }
        }
    }
    curve_instance_instances.clear();
}

void MCurveInstance::set_override(Ref<MCurveInstanceOverride> input){
    if(override_data.is_valid()){
        override_data->disconnect("connection_changed",Callable(this,"_connection_force_update"));
    }
    override_data = input;
    if(override_data.is_valid()){
        override_data->connect("connection_changed",Callable(this,"_connection_force_update"));
    }
    _recreate();
}

MCurveInstance::OverrideData MCurveInstance::get_default_override_data() const{
    OverrideData ov;
    ov.element_ovveride[0] = default_element;
    for(int i=1; i < M_CURVE_CONNECTION_INSTANCE_COUNT; i++){
        ov.element_ovveride[i] = -1;
    }
    return ov;
}

Ref<MCurveInstanceOverride> MCurveInstance::get_override() const{
    return override_data;
}

void MCurveInstance::set_default_element(int input){
    default_element = input;
    _recreate();
}

int MCurveInstance::get_default_element() const{
    return default_element;
}

void MCurveInstance::_on_curve_changed(){
    MPath* new_path = Object::cast_to<MPath>(get_parent());
    if(new_path!=path){
        if(path!=nullptr){
            path->disconnect("curve_changed",Callable(this,"_on_curve_changed"));
            path->disconnect("visibility_changed",Callable(this,"_update_visibilty"));
            path->disconnect("tree_exited",Callable(this,"_update_visibilty"));
            path->disconnect("tree_entered",Callable(this,"_update_visibilty"));
        }
        if(new_path!=nullptr){
            new_path->connect("curve_changed",Callable(this,"_on_curve_changed"));
            new_path->connect("visibility_changed",Callable(this,"_update_visibilty"));
            new_path->connect("tree_exited",Callable(this,"_update_visibilty"));
            new_path->connect("tree_entered",Callable(this,"_update_visibilty"));
        }
    }
    path = new_path;
    Ref<MCurve> new_curve;
    // Handling Curve ...
    if(path!=nullptr){
        new_curve = path->curve;
    }
    if(curve != new_curve){
        if(curve.is_valid()){
            curve->disconnect("connection_updated",Callable(this,"_on_connections_updated"));
            curve->disconnect("force_update_connection",Callable(this,"_connection_force_update"));
            curve->disconnect("remove_connection",Callable(this,"_connection_remove"));
            //curve->disconnect("swap_point_id",Callable(this,"_recreate"));
            curve->disconnect("recreate",Callable(this,"_recreate"));
            curve->remove_curve_user_id(curve_user_id);
            curve_user_id = -1;
        }
        curve = new_curve;
        if(curve.is_valid()){
            curve_user_id = curve->get_curve_users_id();
            curve->connect("connection_updated",Callable(this,"_on_connections_updated"));
            curve->connect("force_update_connection",Callable(this,"_connection_force_update"));
            curve->connect("remove_connection",Callable(this,"_connection_remove"));
            //curve->connect("swap_point_id",Callable(this,"_recreate"));
            curve->connect("recreate",Callable(this,"_recreate"));
        }
    }
    update_configuration_warnings();
    //recreate();
}

void MCurveInstance::_process_tick(){
    if(is_thread_updating){
        if(WorkerThreadPool::get_singleton()->is_task_completed(thread_task_id)){
            WorkerThreadPool::get_singleton()->wait_for_task_completion(thread_task_id);
            is_thread_updating = false;
            ERR_FAIL_COND(curve.is_null());
            //_apply_update();
            set_process(false);
            curve->user_finish_process(curve_user_id);
        }
    }
}

void MCurveInstance::_notification(int p_what){
    switch (p_what)
    {
    case NOTIFICATION_PROCESS:
        _process_tick();
        break;
    case NOTIFICATION_READY:
        //if(!ov.is_valid()){
        //    ov.instantiate();
        //}
        _on_curve_changed();
        break;
    case NOTIFICATION_PARENTED:
        _on_curve_changed();
        break;
    case NOTIFICATION_EDITOR_PRE_SAVE:
        //if(!ov->get_path().is_empty()){
        //    ResourceSaver::get_singleton()->save(ov,ov->get_path());
        //}
    default:
        break;
    }
}

PackedStringArray MCurveInstance::_get_configuration_warnings() const{
    PackedStringArray out;
    if(path==nullptr){
        out.push_back("MCurveMesh should be a child of MPath node!");
        return out;
    }
    if(curve.is_null()){
        out.push_back("Please create a curve resource for MPath!");
        return out;
    }
    return out;
}

void MCurveInstance::set_element(int instance_index,Ref<MCurveInstanceElement> input){
    elements[instance_index] = input;
    if(elements[instance_index].is_valid()){
        elements[instance_index]->_generate_transforms();
        elements[instance_index]->connect("elements_changed",Callable(this,"_recreate"));
    }
    /**
     * this run only at start other MCurveInstanceElement will be set in _set function
     * so there will be no need to clear old MCurveInstanceElement
     */
}

Ref<MCurveInstanceElement> MCurveInstance::get_element(int instance_index) const{
    ERR_FAIL_INDEX_V(instance_index,M_CURVE_ELEMENT_COUNT,Ref<MCurveInstanceElement>());
    return elements[instance_index];
}

int MCurveInstance::get_instance_count(){
    return M_CURVE_CONNECTION_INSTANCE_COUNT;
}

int MCurveInstance::get_element_count(){
    return M_CURVE_ELEMENT_COUNT;
}