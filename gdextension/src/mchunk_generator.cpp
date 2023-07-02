#include "mchunk_generator.h"

#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/aabb.hpp>

void MChunkGenerator::_bind_methods() {
    ClassDB::bind_static_method("MChunkGenerator", D_METHOD("generate","size","h_scale","el","er","et","eb"), &MChunkGenerator::generate );
}

Ref<ArrayMesh> MChunkGenerator::generate(real_t size, real_t h_scale, bool el, bool er, bool et, bool eb) {
    Ref<ArrayMesh> mesh(memnew(ArrayMesh));
    PackedVector3Array vertices;
    PackedVector2Array uvs;
    PackedInt32Array indices;
    if(fmod(size,h_scale) != 0 || h_scale>size){
        ERR_FAIL_V_MSG(mesh, "size and h_scale values not match");
    }
    if(size != h_scale){
        int32_t vert_num_minus_one = (int32_t)(size/h_scale);
        int32_t vert_num = vert_num_minus_one + 1;
        int32_t index = -1;
        // If we should drop a vertex it's index in rows will be -1
        // here all index exist in rows even those we should drop
        int32_t** rows = memnew_arr(int32_t*, vert_num);
        for(int32_t i=0;i<vert_num;i++){
            rows[i] = memnew_arr(int32_t, vert_num);
        }
        for(int32_t y=0;y<vert_num;y++){
            for(int32_t x=0;x<vert_num;x++){
                index++;
                bool is_main = fmod(fmod(x,2)+fmod(y,2), 2) == 0;
                bool drop = (el && x==0) || (er && x==vert_num_minus_one) || (et && y==0) || (eb && y==vert_num_minus_one);
                if(drop && !is_main){
                    index--;
                    rows[y][x] = -1;
                    continue;
                }
                rows[y][x] = index;
                Vector2 uv = Vector2((real_t)x,(real_t)y);
                vertices.append(Vector3(uv.x,0,uv.y)*h_scale);
                uv = uv/((real_t)vert_num_minus_one);
                uvs.append(uv);
            }
        }
        for(int32_t y=0;y<vert_num;y++){
            for(int32_t x=0;x<vert_num;x++){
                bool is_main = fmod(x,2) == 0 && fmod(y,2) == 0;
                index = rows[y][x];
                if(is_main && !(x==0 || x==vert_num_minus_one || y==0 || y==vert_num_minus_one)){
                    PackedInt32Array seg;
                    seg.resize(24);
                    seg[0]=index;seg[1]=rows[y][x-1];seg[2]=rows[y-1][x-1]; //1
                    seg[3]=index;seg[4]=rows[y-1][x-1];seg[5]=rows[y-1][x]; //2
                    seg[6]=index;seg[7]=rows[y-1][x];seg[8]=rows[y-1][x+1]; //3
                    seg[9]=index;seg[10]=rows[y-1][x+1];seg[11]=rows[y][x+1]; //4
                    seg[12]=index;seg[13]=rows[y][x+1];seg[14]=rows[y+1][x+1]; //5
                    seg[15]=index;seg[16]=rows[y+1][x+1];seg[17]=rows[y+1][x]; //6
                    seg[18]=index;seg[19]=rows[y+1][x];seg[20]=rows[y+1][x-1]; //7
                    seg[21]=index;seg[22]=rows[y+1][x-1];seg[23]=rows[y][x-1]; //8
                    indices.append_array(seg);
                }
                if(x==1 && y!=0 && y!=vert_num_minus_one){
                    if (fmod(y,2) == 0){
                        indices.append(index);indices.append(rows[y][x-1]);indices.append(rows[y-1][x]);
                        indices.append(index);indices.append(rows[y+1][x]);indices.append(rows[y][x-1]);
                    } else if (el)
                    {
                        indices.append(index);indices.append(rows[y+1][x-1]);indices.append(rows[y-1][x-1]);
                    } else {
                        indices.append(index);indices.append(rows[y][x-1]);indices.append(rows[y-1][x-1]);
                        indices.append(index);indices.append(rows[y+1][x-1]);indices.append(rows[y][x-1]);
                    }
                }
                if(y==1 && x!=0 && x!=vert_num_minus_one){
                    if (fmod(x,2) == 0){
                        indices.append(index);indices.append(rows[y][x-1]);indices.append(rows[y-1][x]);
                        indices.append(index);indices.append(rows[y-1][x]);indices.append(rows[y][x+1]);
                    } else if (et)
                    {
                        indices.append(index);indices.append(rows[y-1][x-1]);indices.append(rows[y-1][x+1]);
                    } else{
                        indices.append(index);indices.append(rows[y-1][x-1]);indices.append(rows[y-1][x]);
                        indices.append(index);indices.append(rows[y-1][x]);indices.append(rows[y-1][x+1]);
                    }
                }
                if(x==vert_num_minus_one-1 && y!=0 && y!=vert_num_minus_one){
                    if(fmod(y,2) == 0){
                        indices.append(index);indices.append(rows[y-1][x]);indices.append(rows[y][x+1]);
                        indices.append(index);indices.append(rows[y][x+1]);indices.append(rows[y+1][x]);
                    } else if (er){
                        indices.append(index);indices.append(rows[y-1][x+1]);indices.append(rows[y+1][x+1]);
                    } else {
                        indices.append(index);indices.append(rows[y-1][x+1]);indices.append(rows[y][x+1]);
                        indices.append(index);indices.append(rows[y][x+1]);indices.append(rows[y+1][x+1]);
                    }
                }
                if(y==vert_num_minus_one-1 && x!=0 && x!=vert_num_minus_one){
                    if(fmod(x,2)==0){
                        indices.append(index);indices.append(rows[y][x+1]);indices.append(rows[y+1][x]);
                        indices.append(index);indices.append(rows[y+1][x]);indices.append(rows[y][x-1]);
                    }else if (eb){
                        indices.append(index);indices.append(rows[y+1][x+1]);indices.append(rows[y+1][x-1]);
                    }else{
                        indices.append(index);indices.append(rows[y+1][x+1]);indices.append(rows[y+1][x]);
                        indices.append(index);indices.append(rows[y+1][x]);indices.append(rows[y+1][x-1]);
                    }
                }
            }
        }
        for(int32_t i=0;i<vert_num;i++){
            memdelete_arr<int32_t>(rows[i]);
        }
        memdelete_arr<int32_t*>(rows);
    } else {
        // In case h_scale == size
        vertices.append(Vector3(0,0,0)*h_scale);
        uvs.append(Vector2(0,0));
        vertices.append(Vector3(1,0,0)*h_scale);
        uvs.append(Vector2(1,0));
        vertices.append(Vector3(0,0,1)*h_scale);
        uvs.append(Vector2(0,1));
        vertices.append(Vector3(1,0,1)*h_scale);
        uvs.append(Vector2(1,1));
        indices.append(0);indices.append(1);indices.append(2);
        indices.append(1);indices.append(3);indices.append(2);
    }
    PackedVector3Array normals;
    normals.resize(vertices.size());
    normals.fill(Vector3(0,1,0));
    PackedFloat32Array tangents;
    tangents.resize(vertices.size()*4);
    for(int64_t i=0;i<tangents.size();i+=4){
        tangents[i] = 1.0;
        tangents[i+1] = 0.0;
        tangents[i+2] = 0.0;
        tangents[i+3] = 1.0;
    }
    Array surface_arr;
    surface_arr.resize(Mesh::ARRAY_MAX);
    surface_arr[Mesh::ARRAY_VERTEX] = vertices;
    surface_arr[Mesh::ARRAY_INDEX] = indices;
    surface_arr[Mesh::ARRAY_TEX_UV] = uvs;
    surface_arr[Mesh::ARRAY_NORMAL] = normals;
    surface_arr[Mesh::ARRAY_TANGENT] = tangents;
    mesh->add_surface_from_arrays(Mesh::PRIMITIVE_TRIANGLES, surface_arr);
    mesh->set_custom_aabb(AABB(Vector3(0,-100000,0),Vector3(size,200000,size)));
    return mesh;
}