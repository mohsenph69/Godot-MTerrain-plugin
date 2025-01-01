#include "mmesh_joiner.h"

#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/resource_loader.hpp>

void MMeshJoiner::_bind_methods(){
    ClassDB::bind_method(D_METHOD("clear"), &MMeshJoiner::clear);
    ClassDB::bind_method(D_METHOD("insert_mesh_data","meshes","transforms","materials_override"), &MMeshJoiner::insert_mesh_data);
    ClassDB::bind_method(D_METHOD("insert_mmesh_data","meshes","transforms","materials_set_ids"), &MMeshJoiner::insert_mmesh_data);
    ClassDB::bind_method(D_METHOD("join_meshes"), &MMeshJoiner::join_meshes);

    ClassDB::bind_static_method("MMeshJoiner",D_METHOD("get_collission_mesh","meshes","transoforms"), &MMeshJoiner::get_collission_mesh);
    ClassDB::bind_method(D_METHOD("get_data_count"), &MMeshJoiner::get_data_count);
}

void MMeshJoiner::MeshData::append_uv_to(PackedVector2Array& _input) const{
    if(uv.size() > 0){
        _input.append_array(uv);
        return;
    }
    PackedVector2Array a;
    a.resize(vertices.size());
    _input.append_array(a);
}

void MMeshJoiner::MeshData::append_uv2_to(PackedVector2Array& _input) const{
    if(uv2.size() > 0){
        _input.append_array(uv2);
        return;
    }
    PackedVector2Array a;
    a.resize(vertices.size());
    _input.append_array(a);
}

void MMeshJoiner::MeshData::append_colors_to(PackedColorArray& _input) const{
    if(colors.size() > 0){
        _input.append_array(colors);
        return;
    }
    PackedColorArray a;
    a.resize(vertices.size());
    _input.append_array(a);
}

void MMeshJoiner::MeshData::append_vertices_to(PackedVector3Array& _input) const{
    for(Vector3 v : vertices){
        _input.push_back(transform.xform(v));
    }
}

void MMeshJoiner::MeshData::append_normals_to(PackedVector3Array& _input) const{
    if(normals.size() > 0){
        for(Vector3 n : normals){
            n = transform.basis.xform(n);
            n.normalize();
            _input.push_back(n);
        }
        return;
    }
    WARN_PRINT("No normal");
    PackedVector3Array a;
    a.resize(vertices.size());
    _input.append_array(a);
}

void MMeshJoiner::MeshData::append_tangents_to(PackedFloat32Array& _input) const{
    if(tangents.size() > 0){
        for(int i=0; i < tangents.size(); i+=4){
            Vector3 t(tangents[i],tangents[i+1],tangents[i+2]);
            t = transform.basis.xform(t);
            t.normalize();
            _input.push_back(t.x);
            _input.push_back(t.y);
            _input.push_back(t.z);
            _input.push_back(tangents[i+3]);
        }
        return;
    }
    WARN_PRINT("No Tangent Data!");
    PackedFloat32Array a;
    a.resize(vertices.size()*4);
    _input.append_array(a);
}

void MMeshJoiner::MeshData::append_indices_to(PackedInt32Array& _input,int vertex_index_offset) const{
    for(int32_t i : indices){
        i += vertex_index_offset;
        _input.push_back(i);
    }
}

void MMeshJoiner::_sort_data_by_materials(){
    material_sorted_data.clear();
    material_sorted_flags.clear();
    Vector<int> invalid_materials;
    HashMap<Ref<Material>,Vector<int>> sort_data;
    for(int i=0; i < data.size(); i++){
        const MeshData* m = data.ptr() + i;
        if(m->material.is_null()){
            invalid_materials.push_back(i);
            continue;
        }
        if(sort_data.has(m->material)){
            sort_data.getptr(m->material)->push_back(i);
        } else {
            Vector<int> v;
            v.push_back(i);
            sort_data.insert(m->material,v);
        }
    }
    material_sorted_data.push_back(invalid_materials);
    for(HashMap<Ref<Material>,Vector<int>>::Iterator it=sort_data.begin();it!=sort_data.end();++it){
        material_sorted_data.push_back(it->value);
    }
    // material_sorted_flags
    for(int i=0; i < material_sorted_data.size(); i++){
        uint64_t f = 0;
        for(int id : material_sorted_data[i]){
            const MeshData* m = data.ptr() + id;
            if(m->uv.size() > 0) f |= Flags::UV;
            if(m->uv2.size() > 0) f |= Flags::UV2;
            if(m->colors.size() > 0) f |= Flags::COLOR;
            if(m->tangents.size() > 0) f |= Flags::TANGENT;
        }
        material_sorted_flags.push_back(f);
    }
}

void MMeshJoiner::_join_meshes(const Vector<int>& data_ids,Array& mesh_arr,uint64_t flags){
    PackedVector3Array vertices;
    PackedVector3Array normals;
    PackedFloat32Array tangents;
    PackedColorArray colors;
    PackedVector2Array uv;
    PackedVector2Array uv2;
    PackedInt32Array indices;
    for(int id : data_ids){
        const MeshData* m = data.ptr() + id;
        m->append_indices_to(indices,vertices.size());// as we use vertices.size() this should come first really important
        m->append_vertices_to(vertices);
        m->append_normals_to(normals);
        if(flags&Flags::TANGENT!=0) m->append_tangents_to(tangents);
        if(flags&Flags::UV!=0) m->append_uv_to(uv);
        if(flags&Flags::UV2!=0) m->append_uv2_to(uv2);
        if(flags&Flags::COLOR!=0) m->append_colors_to(colors);
    }
    ERR_FAIL_COND(vertices.size()==0);
    mesh_arr.clear(); // just in case
    mesh_arr.resize(Mesh::ARRAY_MAX);
    mesh_arr[Mesh::ARRAY_VERTEX]=vertices;
    mesh_arr[Mesh::ARRAY_NORMAL]=normals;
    mesh_arr[Mesh::ARRAY_INDEX]=indices;
    if(flags&Flags::TANGENT!=0) mesh_arr[Mesh::ARRAY_TANGENT]=tangents;
    if(flags&Flags::UV!=0) mesh_arr[Mesh::ARRAY_TEX_UV]=uv;
    if(flags&Flags::UV2!=0) mesh_arr[Mesh::ARRAY_TEX_UV2]=uv2;
    if(flags&Flags::COLOR!=0) mesh_arr[Mesh::ARRAY_COLOR]=colors;
    int fvcount = vertices.size();
    /*
    ERR_FAIL_COND(fvcount!=uv.size() && uv.size()!=0);
    ERR_FAIL_COND(fvcount!=uv2.size() && uv2.size()!=0);
    ERR_FAIL_COND(fvcount!=colors.size() && colors.size()!=0);
    ERR_FAIL_COND(fvcount!=normals.size());
    ERR_FAIL_COND(fvcount!=tangents.size()/4);
    */
}

void MMeshJoiner::clear(){
    material_sorted_data.clear();
    material_sorted_flags.clear();
    data.clear();
}

bool MMeshJoiner::insert_mesh_data(Array meshes,Array transforms,Array materials_override){
    ERR_FAIL_COND_V(meshes.size()!=materials_override.size(),false);
    ERR_FAIL_COND_V(meshes.size()!=transforms.size(),false);
    for(int i=meshes.size() - 1; i >= 0 ; i--){ // Error checking
        Ref<Mesh> mesh = meshes[i];
        if(mesh.is_null()){
            meshes.remove_at(i);
            transforms.remove_at(i);
            materials_override.remove_at(i);
            continue;
        }
        ERR_FAIL_COND_V_MSG(transforms[i].get_type()!=Variant::TRANSFORM3D,false,"transforms Array input in insert_mesh_data should be Transform3D");
    }
    clear();
    for(int i=0; i < meshes.size(); i++){
        Ref<Mesh> mesh = meshes[i];
        Ref<Material> material = materials_override[i];
        Transform3D trasform = transforms[i];
        int surface_count = mesh->get_surface_count();
        for(int s=0; s < surface_count; s++){
            MeshData mdata;
            int vcount = 0;
            // Maybe later adding customs also
            {
                Array mesh_arr = mesh->surface_get_arrays(s);
                ERR_FAIL_COND_V(mesh_arr.size()!=Mesh::ARRAY_MAX,false);
                mdata.indices = mesh_arr[Mesh::ARRAY_INDEX];
                mdata.vertices = mesh_arr[Mesh::ARRAY_VERTEX];
                mdata.normals = mesh_arr[Mesh::ARRAY_NORMAL];
                mdata.tangents = mesh_arr[Mesh::ARRAY_TANGENT];
                mdata.colors = mesh_arr[Mesh::ARRAY_COLOR];
                mdata.uv = mesh_arr[Mesh::ARRAY_TEX_UV];
                mdata.uv2 = mesh_arr[Mesh::ARRAY_TEX_UV2];
                mdata.transform = trasform;
                vcount = mdata.vertices.size();
                if(vcount == 0){
                    WARN_PRINT("Vertex count is zero skiping this mesh surface");
                    continue;
                }
            }
            // Setting material
            if(material.is_valid()){
                mdata.material = material;
            } else {
                Ref<Material> smaterial = mesh->surface_get_material(s);
            }
            // push to data
            data.push_back(mdata);
        }
    }
    return true;
}

bool MMeshJoiner::insert_mmesh_data(Array meshes,Array transforms,PackedInt32Array materials_set_ids){
    ERR_FAIL_COND_V(meshes.size()!=materials_set_ids.size(),false);
    ERR_FAIL_COND_V(meshes.size()!=transforms.size(),false);
    for(int i=meshes.size() - 1; i >= 0 ; i--){ // Error checking
        Ref<MMesh> mesh = meshes[i];
        if(mesh.is_null()){
            meshes.remove_at(i);
            transforms.remove_at(i);
            materials_set_ids.remove_at(i);
            continue;
        }
        ERR_FAIL_COND_V_MSG(transforms[i].get_type()!=Variant::TRANSFORM3D,false,"transforms Array input in insert_mesh_data should be Transform3D");
    }
    clear();
    for(int i=0; i < meshes.size(); i++){
        Ref<MMesh> mesh = meshes[i];
        Transform3D trasform = transforms[i];
        int surface_count = mesh->get_surface_count();
        PackedStringArray surface_materials_path = mesh->material_set_get(materials_set_ids[i]);
        for(int s=0; s < surface_count; s++){
            MeshData mdata;
            int vcount = 0;
            // Maybe later adding customs also
            {
                Array mesh_arr = mesh->surface_get_arrays(s);
                ERR_FAIL_COND_V(mesh_arr.size()!=Mesh::ARRAY_MAX,false);
                mdata.indices = mesh_arr[Mesh::ARRAY_INDEX];
                mdata.vertices = mesh_arr[Mesh::ARRAY_VERTEX];
                mdata.normals = mesh_arr[Mesh::ARRAY_NORMAL];
                mdata.tangents = mesh_arr[Mesh::ARRAY_TANGENT];
                mdata.colors = mesh_arr[Mesh::ARRAY_COLOR];
                mdata.uv = mesh_arr[Mesh::ARRAY_TEX_UV];
                mdata.uv2 = mesh_arr[Mesh::ARRAY_TEX_UV2];
                mdata.transform = trasform;
                vcount = mdata.vertices.size();
                if(vcount == 0){
                    WARN_PRINT("Vertex count is zero skiping this mesh surface");
                    continue;
                }
            }
            // Setting material
            if(s < surface_materials_path.size() && !surface_materials_path[s].is_empty()){
                mdata.material = ResourceLoader::get_singleton()->load(surface_materials_path[s]);
            }
            // push to data
            data.push_back(mdata);
        }
    }
    return true;
}

Ref<ArrayMesh> MMeshJoiner::join_meshes(){
    ERR_FAIL_COND_V(material_sorted_data.size()!=material_sorted_flags.size(),Ref<Mesh>());
    _sort_data_by_materials();
    ERR_FAIL_COND_V(material_sorted_data.size()==0,Ref<Mesh>());
    Ref<ArrayMesh> jmesh;
    jmesh.instantiate();
    int surface_index = 0;
    for(int i=0; i < material_sorted_data.size(); i++){
        if(material_sorted_data[i].size()==0){
            continue;
        }
        Array mesh_arr;
        Ref<Material> smaterial = data[material_sorted_data[i][0]].material;
        _join_meshes(material_sorted_data[i],mesh_arr,material_sorted_flags[i]);
        ERR_CONTINUE(mesh_arr.size()!=Mesh::ARRAY_MAX);
        jmesh->add_surface_from_arrays(Mesh::PrimitiveType::PRIMITIVE_TRIANGLES,mesh_arr);
        jmesh->surface_set_material(surface_index,smaterial);
        surface_index++;
    }
    return jmesh;
}

Ref<Mesh> MMeshJoiner::get_collission_mesh(Array meshes,Array transforms){
    ERR_FAIL_COND_V(meshes.size()!=transforms.size(),nullptr);
    PackedVector3Array vertices;
    PackedInt32Array indicies;
    int index_offset = 0;
    for(int i=0; i < meshes.size();i++){
        Ref<Mesh> mesh = meshes[i];
        if(mesh.is_null()){
            continue;
        }
        Transform3D mtransform = transforms[i];
        int surface_count = mesh->get_surface_count();
        for(int j=0; j < surface_count; j++){
            Array surface_data = mesh->surface_get_arrays(j);
            PackedVector3Array surface_vertices = surface_data[Mesh::ARRAY_VERTEX];
            for(int v=0 ; v < surface_vertices.size(); v++){
                surface_vertices.ptrw()[v] = mtransform.xform(surface_vertices[v]);
            }
            vertices.append_array(surface_vertices);
            PackedInt32Array surface_indices = surface_data[Mesh::ARRAY_INDEX];
            if(index_offset!=0){
                for(int k=0 ; k < surface_indices.size(); k++){
                    surface_indices.ptrw()[k] += index_offset;
                }
            }
            indicies.append_array(surface_indices);
            index_offset = vertices.size();
        }
    }
    Array final_data;
    final_data.resize(Mesh::ARRAY_MAX);
    final_data[Mesh::ARRAY_VERTEX] = vertices;
    final_data[Mesh::ARRAY_INDEX] = indicies;
    Ref<ArrayMesh> arr_mesh;
    arr_mesh.instantiate();
    arr_mesh->add_surface_from_arrays(Mesh::PRIMITIVE_TRIANGLES,final_data);
    return arr_mesh;
}

int MMeshJoiner::get_data_count() const{
    return data.size();
}