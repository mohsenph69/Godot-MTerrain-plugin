#include "mmesh.h"

#include "mhlod_scene.h"
#include <mutex>

#include <godot_cpp/classes/rendering_server.hpp>
#define RS RenderingServer::get_singleton()
#include <godot_cpp/variant/utility_functions.hpp>

#include <godot_cpp/classes/resource_loader.hpp>

void MMesh::_bind_methods(){
    ClassDB::bind_method(D_METHOD("create_from_mesh","mesh"), &MMesh::create_from_mesh);
    ClassDB::bind_method(D_METHOD("get_mesh_rid"), &MMesh::get_mesh_rid);
    ClassDB::bind_method(D_METHOD("get_mesh"), &MMesh::get_mesh);

    ClassDB::bind_method(D_METHOD("get_surface_count"), &MMesh::get_surface_count);
    ClassDB::bind_method(D_METHOD("get_aabb"), &MMesh::get_aabb);
    ClassDB::bind_method(D_METHOD("material_set_get_count"), &MMesh::material_set_get_count);
    ClassDB::bind_method(D_METHOD("material_set_get","set_id"), &MMesh::material_set_get);
    ClassDB::bind_method(D_METHOD("material_get","set_id","surface_index"), &MMesh::material_get);
    ClassDB::bind_method(D_METHOD("surface_set_material","set_id","surface_index","material_path"), &MMesh::surface_set_material);
    ClassDB::bind_method(D_METHOD("add_material_set"), &MMesh::add_material_set);
    ClassDB::bind_method(D_METHOD("clear_material_set","set_id"), &MMesh::clear_material_set);

    ClassDB::bind_method(D_METHOD("is_same_mesh","other"), &MMesh::is_same_mesh);

    ClassDB::bind_method(D_METHOD("_set_surfaces","surfaces"), &MMesh::_set_surfaces);
    ClassDB::bind_method(D_METHOD("_get_surfaces"), &MMesh::_get_surfaces);
    ADD_PROPERTY(PropertyInfo(Variant::ARRAY,"_surfaces",PROPERTY_HINT_NONE,"",PROPERTY_USAGE_STORAGE),"_set_surfaces","_get_surfaces");

    ClassDB::bind_method(D_METHOD("debug_test"), &MMesh::debug_test);
}

void MMesh::_create_if_not_exist(){
    if(!mesh.is_valid()){
        mesh = RS->mesh_create();
    }
}

MMesh::MaterialSet::MaterialSet(int surface_count){
    PackedStringArray _str_paths;
    _str_paths.resize(surface_count);
    set_surface_materials_paths(_str_paths);
}

MMesh::MaterialSet::MaterialSet(const PackedStringArray& _material_paths){
    set_surface_materials_paths(_material_paths);
}

MMesh::MaterialSet::MaterialSet(const PackedByteArray& _material_paths){
    surface_materials_paths = _material_paths;
}

MMesh::MaterialSet::~MaterialSet(){

}

PackedStringArray MMesh::MaterialSet::get_surface_materials_paths() const{
    return surface_materials_paths.get_string_from_ascii().split(";");
}

void MMesh::MaterialSet::set_surface_materials_paths(const PackedStringArray& paths){
    if(paths.size()==0){
        surface_materials_paths.clear();
        return;
    }
    String _str = paths[0];
    for(int i=1; i < paths.size(); i++){
        _str += ";" + paths[i];
    }
    surface_materials_paths = _str.to_ascii_buffer();
}

void MMesh::MaterialSet::clear(){
    PackedStringArray empty_path;
    empty_path.resize(get_surface_count());
    set_surface_materials_paths(empty_path);
}

bool MMesh::MaterialSet::has_cache() const{
    return materials_cache.size() != 0;
}

int MMesh::MaterialSet::get_surface_count() const{
    if(surface_materials_paths.size()==0){
        return 1;
    }
    return surface_materials_paths.count(MPATH_DELIMTER) + 1;
}

void MMesh::MaterialSet::set_material(int surface_index,Ref<Material> material){
    ERR_FAIL_COND_MSG(material.is_valid()&&material->get_path().is_empty(),"Material should saved first to be added on MMesh");
    String path;
    if(material.is_valid()){
        path = material->get_path();
        ERR_FAIL_COND_MSG(path.find("::")!=-1,"Material should save as independent file current path is: "+path);
    }
    PackedStringArray _str_paths = get_surface_materials_paths();
    ERR_FAIL_INDEX(surface_index,_str_paths.size());
    _str_paths.set(surface_index,path);
    set_surface_materials_paths(_str_paths);
}

void MMesh::MaterialSet::set_material_no_error(int surface_index,Ref<Material> material){
    if(material.is_valid()&&material->get_path().is_empty()){
        return;
    }
    String path;
    if(material.is_valid()){
        path = material->get_path();
        if(path.find("::")!=-1){
            return;
        }
    }
    PackedStringArray _str_paths = get_surface_materials_paths();
    ERR_FAIL_INDEX(surface_index,_str_paths.size());
    _str_paths.set(surface_index,path);
    set_surface_materials_paths(_str_paths);
}

// This function should be called only in main loop
// Usally used for editor stuff
Ref<Material> MMesh::MaterialSet::get_material_no_user(int surface_index) const{
    std::lock_guard<std::mutex> lock(MHlodScene::update_mutex);
    if(has_cache()){

    }
    PackedStringArray _str_paths = get_surface_materials_paths();
    ERR_FAIL_INDEX_V(surface_index,_str_paths.size(),Ref<Material>());
    if(_str_paths[surface_index].is_empty() || !_str_paths[surface_index].is_absolute_path()){
        return Ref<Material>();
    }
    return ResourceLoader::get_singleton()->load(_str_paths[surface_index]);
}

void MMesh::MaterialSet::get_materials_add_user(Vector<RID>& materials_rid){
    add_user();
    for(int i=0; i < materials_cache.size(); i++){
        if(materials_cache[i].is_null()){
            materials_rid.push_back(RID());
        } else {
            materials_rid.push_back(materials_cache[i]->get_rid());
        }
    }
}

void MMesh::MaterialSet::get_materials(Vector<RID>& materials_rid){
    ERR_FAIL_COND(materials_cache.size()==0);
    for(int i=0; i < materials_cache.size(); i++){
        if(materials_cache[i].is_null()){
            materials_rid.push_back(RID());
        } else {
            materials_rid.push_back(materials_cache[i]->get_rid());
        }
    }
}

void MMesh::MaterialSet::update_cache(){
    if(!has_cache()){
        return;
    }
    materials_cache.clear();
    PackedStringArray _str_paths = get_surface_materials_paths();
    for(int i=0; i < _str_paths.size(); i++){
        if(_str_paths[i].is_empty()){
            materials_cache.push_back(Ref<Material>());
            continue;
        }
        materials_cache.push_back(ResourceLoader::get_singleton()->load(_str_paths[i]));
    }
}

void MMesh::MaterialSet::add_user(){
    user_count++;
    if(!has_cache()){
        materials_cache.clear();
        PackedStringArray _str_paths = get_surface_materials_paths();
        for(int i=0; i < _str_paths.size(); i++){
            if(_str_paths[i].is_empty()){
                materials_cache.push_back(Ref<Material>());
                continue;
            }
            materials_cache.push_back(ResourceLoader::get_singleton()->load(_str_paths[i]));
        }
    }
}

void MMesh::MaterialSet::remove_user(){
    ERR_FAIL_COND(user_count==0); // this should not happen, but will happen when you call extra remove_user
    user_count--; // I hope this happen in only one thread
    if(user_count==0){
        materials_cache.clear();
    }
}


PackedStringArray MMesh::surfaces_get_names() const{
    return surfaces_names.get_string_from_ascii().split(";");
}

void MMesh::surfaces_set_names(const PackedStringArray& _surfaces_names){
    if(_surfaces_names.size()==0){
        surfaces_names.clear();
        return;
    }
    String _str = _surfaces_names[0];
    for(int i=1; i < _surfaces_names.size(); i++){
        _str += ";" + _surfaces_names[i];
    }
    surfaces_names = _str.to_ascii_buffer();
}

MMesh::MMesh(){
}

MMesh::~MMesh(){
    if(mesh.is_valid()){
        RS->free_rid(mesh);
    }
}

void MMesh::surface_set_name(int surface_index){

}

String MMesh::surface_get_name() const{
    return "";
}

Array MMesh::surface_get_arrays(int surface_index) const{
    Array out;
    if(!mesh.is_valid()){
        return out;
    }
    return RS->mesh_surface_get_arrays(mesh,surface_index);
}


RID MMesh::get_mesh_rid(){
    _create_if_not_exist();
    return mesh;
}

void MMesh::create_from_mesh(Ref<Mesh> input){
    Array surfaces;
    ERR_FAIL_COND(input.is_null());
    int surface_count = input->get_surface_count();
    ERR_FAIL_COND(surface_count==0);
    materials_set.clear();
    Array _surfaces;
    RID input_rid = input->get_rid();
    MaterialSet _fms(surface_count);
    for(int i=0; i < surface_count; i++){
        _fms.set_material_no_error(i,input->surface_get_material(i));
    }
    // Material Path
    PackedByteArray _bpaths = _fms.surface_materials_paths;
    Array ___m;
    ___m.push_back(_bpaths);
    _surfaces.push_back(___m);
    // Mesh data
    for(int i=0; i < surface_count; i++){
        Dictionary sdata = RS->mesh_get_surface(input_rid,i);
        sdata["name"] = input->call("surface_get_name",i);
        _surfaces.push_back(sdata);
    }
    _set_surfaces(_surfaces);
}

Ref<ArrayMesh> MMesh::get_mesh() const{
    Array _surfaces = _get_surfaces();
    // Removing Material Section
    if(_surfaces.size() > 0 && _surfaces[0].get_type() == Variant::Type::ARRAY){
        _surfaces.remove_at(0);
    }
    Ref<ArrayMesh> out;
    out.instantiate();
    out->set("_surfaces",_surfaces);
    ERR_FAIL_COND_V(materials_set.size()==0,out);
    for(int i=0; i < _surfaces.size(); i++){
        out->surface_set_material(i,materials_set[0].get_material_no_user(i));
    }
    return out;
}

int MMesh::get_surface_count() const{
    if(!mesh.is_valid()){
        return 0;
    }
    ERR_FAIL_COND_V(materials_set.size()==0,0);
    return materials_set[0].get_surface_count();
}

AABB MMesh::get_aabb() const{
    return aabb;
}

int MMesh::material_set_get_count() const{
    return materials_set.size();
}

PackedStringArray MMesh::material_set_get(int set_id) const{
    ERR_FAIL_INDEX_V(set_id,materials_set.size(),PackedStringArray());
    return materials_set[set_id].get_surface_materials_paths();
}

String MMesh::material_get(int set_id,int surface_index)const{
    ERR_FAIL_INDEX_V(set_id,materials_set.size(),String(""));
    PackedStringArray __surfaces = materials_set[set_id].get_surface_materials_paths();
    ERR_FAIL_INDEX_V(surface_index,__surfaces.size(),String(""));
    return __surfaces[surface_index];
}

void MMesh::surface_set_material(int set_id,int surface_index,const String& path){
    ERR_FAIL_INDEX(set_id,materials_set.size());
    PackedStringArray __surfaces = materials_set[set_id].get_surface_materials_paths();
    ERR_FAIL_INDEX(surface_index,__surfaces.size());
    __surfaces.set(surface_index,path);
    materials_set.ptrw()[set_id].set_surface_materials_paths(__surfaces);
    materials_set.ptrw()[set_id].update_cache();
    update_material_override();
}

int MMesh::add_material_set(){
    MaterialSet new_set(get_surface_count());
    materials_set.push_back(new_set);
    return materials_set.size() - 1;
}

void MMesh::clear_material_set(int set_id){
    ERR_FAIL_INDEX(set_id,materials_set.size());
    materials_set.ptrw()[set_id].clear();
}

bool MMesh::has_material_override(){
    return materials_set.size() > 1;
}

void MMesh::update_material_override(){
    // Setting mesh material if we have only one set
    if(!has_material_override() && materials_set.size()!=0 && mesh.is_valid()){
        Vector<RID> materials_rid;
        materials_set.ptrw()[0].get_materials_add_user(materials_rid);
        for(int i=0; i < materials_rid.size(); i++){
            if(materials_rid[i].is_valid()){
                RS->mesh_surface_set_material(mesh,i,materials_rid[i]);
            }
        }
        return;
    }
    if(mesh.is_valid()){
        int surface_count = get_surface_count();
        for(int i=0; i < surface_count; i++){
            RS->mesh_surface_set_material(mesh,i,RID());
        }
    }
}

void MMesh::get_materials_add_user(int material_set_id,Vector<RID>& materials_rid){
    ERR_FAIL_INDEX(material_set_id,materials_set.size());
    materials_set.ptrw()[material_set_id].get_materials_add_user(materials_rid);
}

void MMesh::get_materials(int material_set_id,Vector<RID>& materials_rid){
    ERR_FAIL_INDEX(material_set_id,materials_set.size());
    materials_set.ptrw()[material_set_id].get_materials(materials_rid);
}

void MMesh::add_user(int material_set_id){
    ERR_FAIL_INDEX(material_set_id,materials_set.size());
    materials_set.ptrw()[material_set_id].add_user();
}

void MMesh::remove_user(int material_set_id){
    ERR_FAIL_INDEX(material_set_id,materials_set.size());
    materials_set.ptrw()[material_set_id].remove_user();
}

bool MMesh::is_same_mesh(Ref<MMesh> other){
    if(other.is_null()){
        return false;
    }
    if(get_surface_count()!=other->get_surface_count()){
        return false;
    }
    if(material_set_get_count()!=other->material_set_get_count()){
        return false;
    }
    if(surfaces_get_names()!=other->surfaces_get_names()){
        return false;
    }
    for(int s=0; s < get_surface_count(); s++){
        Array my_info = surface_get_arrays(s);
        Array other_info = other->surface_get_arrays(s);
        for(int i=0; i < Mesh::ARRAY_MAX; i++){
            if(my_info[i]!=other_info[i]){
                return false;
            }
        }
    }
    return true;
}

void MMesh::_set_surfaces(Array _surfaces){
    _create_if_not_exist();
    RS->mesh_clear(mesh);
    materials_set.clear();
    // Material
    if(_surfaces.size() > 0 && _surfaces[0].get_type() == Variant::Type::ARRAY){
        // Then the first element is materials_set
        Array _ms = _surfaces[0];
        for(int i=0; i < _ms.size(); i++){
            PackedByteArray _ms_path_ascci = _ms[i];
            materials_set.push_back(MaterialSet(_ms_path_ascci));
        }
        _surfaces.remove_at(0);
    }
    // Check Import
    int surface_count = _surfaces.size();
    ERR_FAIL_COND(surface_count==0);
    if(materials_set.size() == 0){
        MaterialSet _ms(surface_count);
        materials_set.push_back(_ms);
    }
    PackedStringArray _surfaces_names;
    // Mesh Data
    for(int i=0; i < surface_count; i++){
        Dictionary sdata = _surfaces[i];
        _surfaces_names.push_back(sdata["name"]);
        RS->mesh_add_surface(mesh,sdata);
        ERR_CONTINUE(!sdata.has("aabb"));
        if(i==0){
            aabb = sdata["aabb"];
        } else {
            aabb.merge_with(sdata["aabb"]);
        }
    }
    update_material_override();
    surfaces_set_names(_surfaces_names);
    notify_property_list_changed();
}

Array MMesh::_get_surfaces() const{
    Array _surfaces;
    Array _ms;
    for(int i=0; i < materials_set.size(); i++){
        _ms.push_back(materials_set[i].surface_materials_paths);
    }
    _surfaces.push_back(_ms);
    if(!mesh.is_valid()){
        return _surfaces;
    }
    int surface_count = get_surface_count();
    PackedStringArray _surfaces_names = surfaces_get_names();
    for(int i=0; i < surface_count; i++){
        Dictionary sdata = RS->mesh_get_surface(mesh,i);
        sdata["name"] = _surfaces_names[i];
        _surfaces.push_back(sdata);
    }
    return _surfaces;
}


bool MMesh::_set(const StringName &p_name, const Variant &p_value){
    if(p_name.begins_with("materials/set_")){
        String mname = p_name.replace("materials/set_","");
        int e = mname.find("/"); int e2 = mname.find("_");
        if(e==-1||e2==-1){
            return false;
        }
        int set_index = mname.substr(0,e).to_int();
        if(set_index < 0 || set_index >= materials_set.size()){
            return false;
        }
        e++;
        int surface_index = mname.substr(e,e2 - e).to_int();
        materials_set.ptrw()[set_index].set_material(surface_index,p_value);
        materials_set.ptrw()[set_index].update_cache();
        update_material_override();
        return true;
    }
    return false;
}

bool MMesh::_get(const StringName &p_name, Variant &r_ret) const{
    if(p_name.begins_with("materials/set_")){
        String mname = p_name.replace("materials/set_","");
        int e = mname.find("/"); int e2 = mname.find("_");
        if(e==-1||e2==-1){
            return false;
        }
        int set_index = mname.substr(0,e).to_int();
        if(set_index < 0 || set_index >= materials_set.size()){
            return false;
        }
        e++;
        int surface_index = mname.substr(e,e2 - e).to_int();
        r_ret = materials_set[set_index].get_material_no_user(surface_index);
        return true;
    }
    return false;
}

void MMesh::_get_property_list(List<PropertyInfo> *p_list) const{
    if(!mesh.is_valid()){
        return;
    }
    int surface_count = get_surface_count();
    String prefix = "materials/set_";
    PackedStringArray __surfaces_names = surfaces_get_names();
    ERR_FAIL_COND(__surfaces_names.size()!=surface_count);
    for(int ms=0; ms < materials_set.size(); ms++){
        String prefix_ms = prefix + itos(ms) + String("/");
        for(int s=0; s < surface_count; s++){
            String pname = prefix_ms + itos(s) + String("_") + __surfaces_names[s];
            PropertyInfo prop(Variant::OBJECT,pname,PROPERTY_HINT_RESOURCE_TYPE,"BaseMaterial3D,ShaderMaterial",PROPERTY_USAGE_EDITOR);
            p_list->push_back(prop);
        }
    }
}



void MMesh::debug_test() {
    Ref<Material> mat;
    mat.instantiate();
    UtilityFunctions::print("Debug test");
    PackedStringArray _str_paths;
    _str_paths.push_back("res://massets/meshes/3.res");
    //_str_paths.push_back("res://massets/foo.res");
    //_str_paths.push_back("res://loo.res");
    MaterialSet ms(1);
    ms.set_material(0,mat);
    UtilityFunctions::print(ms.surface_materials_paths.get_string_from_ascii());
    UtilityFunctions::print(ms.get_surface_materials_paths());
}