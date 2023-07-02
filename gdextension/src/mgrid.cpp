#include "mgrid.h"

#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/shader.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/texture2d.hpp>
#include <iostream>


MGrid::MGrid(){}
MGrid::~MGrid() {
    clear();
}

void MGrid::clear() {
    if(is_dirty){
        RenderingServer* rs = RenderingServer::get_singleton();
        for(int32_t z=_search_bound.top; z <=_search_bound.bottom; z++)
        {
            for(int32_t x=_search_bound.left; x <=_search_bound.right; x++){
                if(points[z][x].has_instance()){
                    rs->free_rid(points[z][x].instance);
                    points[z][x].instance = RID();
                    points[z][x].mesh = RID();
                }
            }
        }
        for(int32_t z=0; z <_size.z; z++){
                memdelete_arr<MPoint>(points[z]);
            }
        memdelete_arr<MPoint*>(points);
        memdelete_arr<MRegion>(regions);
        memdelete(_chunks);
    }
    _size.x = 0;
    _size.y = 0;
    _size.z = 0;
    _grid_bound.clear();
    _search_bound.clear();
    _last_search_bound.clear();
    _region_grid_bound.clear();
    is_dirty = false;
}

bool MGrid::is_created() {
    return is_dirty;
}

MGridPos MGrid::get_size() {
    return _size;
}

void MGrid::set_scenario(RID scenario){
    _scenario = scenario;
}

void MGrid::create(const int32_t& width,const int32_t& height, MChunks* chunks) {
    if (width == 0 || height == 0) return;
    _chunks = chunks;
    _size.x = width;
    _size.z = height;
    _size_meter.x = width*_chunks->base_size_meter;
    _size_meter.z = height*_chunks->base_size_meter;
    _vertex_size.x = (_size_meter.x/chunks->h_scale) + 1;
    _vertex_size.z = (_size_meter.z/chunks->h_scale) + 1;
    _region_grid_size.x = _size.x/region_size + _size.x%region_size;
    _region_grid_size.z = _size.z/region_size + _size.z%region_size;
    _region_grid_bound.right  = _region_grid_size.x - 1;
    _region_grid_bound.bottom = _region_grid_size.z - 1;
    _regions_count = _region_grid_size.x*_region_grid_size.z;
    region_size_meter = region_size*_chunks->base_size_meter;
    _grid_bound = MBound(0,width-1, 0, height-1);
    regions = memnew_arr(MRegion, _regions_count);
    points = memnew_arr(MPoint*, _size.z);
    for (int32_t z=0; z<_size.z; z++){
        points[z] = memnew_arr(MPoint, _size.x);
    }
    //Init Regions
    int index = 0;
    for(int32_t z=0; z<_region_grid_size.z; z++){
        for(int32_t x=0; x<_region_grid_size.x; x++){
            regions[index].grid = this;
            regions[index].pos = MGridPos(x,0,z);
            regions[index].world_pos = get_world_pos(x*region_size,0,z*region_size);
            if(x!=0){
                regions[index].left = get_region(x-1,z);
            }
            if(x!=_region_grid_size.x-1){
                regions[index].right = get_region(x+1,z);
            }
            if(z!=0){
                regions[index].top = get_region(x,z-1);
            }
            if(z!=_region_grid_size.z-1){
                regions[index].bottom = get_region(x,z+1);
            }
            if(_material.is_valid()){
                regions[index].set_material(_material->duplicate());
            }
            index++;
        }
    }
    is_dirty = true;
}

void MGrid::update_regions_uniforms(Array input) {
    ERR_FAIL_COND(!_material.is_valid());
    ERR_FAIL_COND(!_material->get_shader().is_valid());
    for(int i=0;i<input.size();i++){
        Dictionary unifrom_info = input[i];
        update_regions_uniform(unifrom_info);
    }
}

void MGrid::update_regions_uniform(Dictionary input) {
    String name = input["name"];
    String uniform_name = input["uniform_name"];
    int compression = input["compression"];
    for(int z=0; z<_region_grid_size.z;z++){
        for(int x=0; x<_region_grid_size.x;x++){
            MRegion* region= get_region(x,z);
            String file_name = name+"_x"+itos(x)+"_y"+itos(z)+".res";
            String file_path = dataDir.path_join(file_name);
            ERR_FAIL_COND_MSG(!ResourceLoader::get_singleton()->exists(file_path), "MTerrain can not find files check dataDir OR adjust Terrain size and region size to match dataDir files");
            MImageInfo* i = memnew(MImageInfo(file_path,name,uniform_name,compression));
            region->set_image_info(i);
        }
    }
}


Vector3 MGrid::get_world_pos(const int32_t &x,const int32_t& y,const int32_t& z) {
    return Vector3(x,y,z)*_chunks->base_size_meter + offset;
}

Vector3 MGrid::get_world_pos(const MGridPos& pos){
    return Vector3(pos.x,pos.y,pos.z)*_chunks->base_size_meter + offset;
}

MGridPos MGrid::get_grid_pos(const Vector3& pos) {
    MGridPos p;
    Vector3 rp = pos - offset;
    p.x = ((int32_t)(rp.x))/_chunks->base_size_meter;
    p.y = ((int32_t)(rp.y))/_chunks->base_size_meter;
    p.z = ((int32_t)(rp.z))/_chunks->base_size_meter;
    return p;
}

int32_t MGrid::get_region_id_by_point(const int32_t &x, const int32_t& z) {
    return x/region_size + (z/region_size)*_region_grid_size.x;
}

MRegion* MGrid::get_region_by_point(const int32_t &x, const int32_t& z){
    int32_t id = x/region_size + (z/region_size)*_region_grid_size.x;
    return regions + id;
}

MRegion* MGrid::get_region(const int32_t &x, const int32_t& z){
    int32_t id = x + z*_region_grid_size.x;
    return regions + id;
}

MGridPos MGrid::get_region_pos_by_world_pos(Vector3 world_pos){
    MGridPos p;
    world_pos -= offset;
    p.x = (int32_t)(world_pos.x/((real_t)region_size_meter));
    p.z = (int32_t)(world_pos.z/((real_t)region_size_meter));
    return p;
}

int8_t MGrid::get_lod_by_distance(const int32_t& dis) {
    for(int8_t i=0 ; i < lod_distance.size(); i++){
        if(dis < lod_distance[i]){
            return i;
        }
    }
    return _chunks->max_lod;
}


void MGrid::set_cam_pos(const Vector3& cam_world_pos) {
    _cam_pos = get_grid_pos(cam_world_pos);
    _cam_pos_real = cam_world_pos;
}



void MGrid::update_search_bound() {
    num_chunks = 0;
    update_mesh_list.clear();
    remove_instance_list.clear();
    MBound sb(_cam_pos, max_range, _size);
    _last_search_bound = _search_bound;
    _search_bound = sb;
    //_search_bound = _grid_bound; /// For now just for debuging
}

void MGrid::cull_out_of_bound() {
    RenderingServer* rs = RenderingServer::get_singleton();
    for(int32_t z=_last_search_bound.top; z <=_last_search_bound.bottom; z++)
    {
        for(int32_t x=_last_search_bound.left; x <=_last_search_bound.right; x++){
            if (!_search_bound.has_point(x,z)){
                if(points[z][x].has_instance()){
                    //rs->free_rid(points[z][x].instance);
                    remove_instance_list.append(points[z][x].instance);
                    points[z][x].instance = RID();
                    points[z][x].mesh = RID();
                }
            }

        }
    }
}


void MGrid::update_lods() {
    /// First Some Clean up
    for(int32_t z=_search_bound.top; z <=_search_bound.bottom; z++){
        for(int32_t x=_search_bound.left; x <=_search_bound.right; x++){
            points[z][x].size = 0;
        }
    }
    //// Now Update LOD
    MGridPos closest = _grid_bound.closest_point_on_ground(_cam_pos);
    closest = get_3d_grid_pos_by_middle_point(closest);
    MBound m(closest);
    int8_t current_lod = 0;
    current_lod = get_lod_by_distance(m.center.get_distance(_cam_pos));
    if(!_grid_bound.has_point(_cam_pos))
    {
        Vector3 closest_real = get_world_pos(closest);
        Vector3 diff = _cam_pos_real - closest_real;
        m.grow_when_outside(diff.x, diff.z,_cam_pos, _search_bound,_chunks->base_size_meter);
        for(int32_t z =m.top; z <= m.bottom; z++){
            for(int32_t x=m.left; x <= m.right; x++){
                points[z][x].lod = current_lod;
                get_region_by_point(x,z)->insert_lod(current_lod);
            }
        }
    } else {
        points[m.center.z][m.center.x].lod = current_lod;
        get_region_by_point(m.center.x,m.center.z)->insert_lod(current_lod);
    }
    while (m.grow(_search_bound,1,1))
    {
        int8_t l;
        if(current_lod != _chunks->max_lod){
            MGridPos e = m.get_edge_point();
            e = get_3d_grid_pos_by_middle_point(e);
            int32_t dis = e.get_distance(_cam_pos);
            l = get_lod_by_distance(dis);
            //make sure that we are going one lod by one lod not jumping two lod
            if (l > current_lod +1){
                l = current_lod + 1;
            }
            // Also make sure to not jump back to lower lod when growing
            if(l<current_lod){
                l = current_lod;
            }
            current_lod = l;
        } else {
            l = _chunks->max_lod;
        }
        if(m.grow_left){
            for(int32_t z=m.top; z<=m.bottom;z++){
                points[z][m.left].lod = l;
                get_region_by_point(m.left,z)->insert_lod(l);
            }
        }
        if(m.grow_right){
            for(int32_t z=m.top; z<=m.bottom;z++){
                points[z][m.right].lod = l;
                get_region_by_point(m.right,z)->insert_lod(l);
            }
        }
        if(m.grow_top){
            for(int32_t x=m.left; x<=m.right; x++){
                points[m.top][x].lod = l;
                get_region_by_point(x,m.top)->insert_lod(l);
            }
        }
        if(m.grow_bottom){
            for(int32_t x=m.left; x<=m.right; x++){
                points[m.bottom][x].lod = l;
                get_region_by_point(x,m.bottom)->insert_lod(l);
            }
        }
    }
}

///////////////////////////////////////////////////////
////////////////// MERGE //////////////////////////////
void MGrid::merge_chunks() {
    for(int i=0; i < _regions_count; i++){
        regions[i].update_region();
    }
    for(int32_t z=_search_bound.top; z<=_search_bound.bottom; z++){
        for(int32_t x=_search_bound.left; x<=_search_bound.right; x++){
            int8_t lod = points[z][x].lod;
            MBound mb(x,z);
            int32_t region_id = get_region_id_by_point(x,z);
            #ifdef NO_MERGE
            check_bigger_size(lod,0, mb);
            num_chunks +=1;
            #else
            for(int8_t s=_chunks->max_size; s>=0; s--){
                if(_chunks->sizes[s].lods[lod].meshes.size()){
                    MBound test_bound = mb;
                    if(test_bound.grow_positive(pow(2,s) - 1, _search_bound)){
                        if(check_bigger_size(lod,s,region_id, test_bound)){
                            num_chunks +=1;
                            break;
                        }
                    }
                }
            }
            #endif
        }
    }
}

//This will check if all lod in this bound are the same if not return false
// also check if the right, bottom, top, left neighbor has the same lod level
// OR on lod level up otherwise return false
// Also if All condition are correct then we can merge to bigger size
// So this will set the size of all points except the first one to -1
// Also Here we should detrmine the edge of each mesh
bool MGrid::check_bigger_size(const int8_t& lod,const int8_t& size,const int32_t& region_id, const MBound& bound) {
    for(int32_t z=bound.top; z<=bound.bottom; z++){
        for(int32_t x=bound.left; x<=bound.right; x++){
            if (points[z][x].lod != lod || points[z][x].size == -1 || get_region_id_by_point(x,z) != region_id)
            {
                return false;
            }
        }
    }
    // So these will determine if left, right, top, bottom edge should adjust to upper LOD
    bool right_edge = false;
    bool left_edge = false;
    bool top_edge = false;
    bool bottom_edge = false;
    // Check right neighbors
    int32_t right_neighbor = bound.right + 1;
    if (right_neighbor <= _search_bound.right){
        // Grab one sample from right neghbor
        int8_t last_right_lod = points[bound.bottom][right_neighbor].lod;
        // Now we don't care what is that all should be same
        for(int32_t z=bound.top; z<bound.bottom; z++){
            if(points[z][right_neighbor].lod != last_right_lod){
                return false;
            }
        }
        right_edge = (last_right_lod == lod + 1);
    }

    // Doing the same for bottom neighbor
    int32_t bottom_neighbor = bound.bottom + 1;
    if(bottom_neighbor <= _search_bound.bottom){
        int8_t last_bottom_lod = points[bottom_neighbor][bound.right].lod;
        for(int32_t x=bound.left; x<bound.right;x++){
            if(points[bottom_neighbor][x].lod != last_bottom_lod){
                return false;
            }
        }
        bottom_edge = (last_bottom_lod == lod + 1);
    }

    // Doing the same for left
    int32_t left_neighbor = bound.left - 1;
    if(left_neighbor >= _search_bound.left){
        int8_t last_left_lod = points[bound.bottom][left_neighbor].lod;
        for(int32_t z=bound.top;z<bound.bottom;z++){
            if(points[z][left_neighbor].lod != last_left_lod){
                return false;
            }
        }
        left_edge = (last_left_lod == lod + 1);
    }
    // WOW finally top neighbor
    int32_t top_neighbor = bound.top - 1;
    if(top_neighbor >= _search_bound.top){
        int8_t last_top_lod = points[top_neighbor][bound.right].lod;
        for(int32_t x=bound.left; x<bound.right; x++){
            if(points[top_neighbor][x].lod != last_top_lod){
                return false;
            }
        }
        top_edge = (last_top_lod == lod + 1);
    }
    // Now all the condition for creating this chunk with this size is true
    // So we start to build that
    // Top left corner will have one chunk with this size
    RenderingServer* rs = RenderingServer::get_singleton();
    for(int32_t z=bound.top; z<=bound.bottom; z++){
        for(int32_t x=bound.left;x<=bound.right;x++){
            if(z==bound.top && x==bound.left){
                points[z][x].size = size;
                int8_t edge_num = get_edge_num(left_edge,right_edge,top_edge,bottom_edge);
                RID mesh = _chunks->sizes[size].lods[lod].meshes[edge_num];
                if(points[z][x].mesh != mesh){
                    points[z][x].mesh = mesh;
                    if(points[z][x].has_instance()){
                        remove_instance_list.append(points[z][x].instance);
                        points[z][x].instance = RID(); 
                    }
                    MRegion* region = get_region_by_point(x,z);
                    region->insert_lod(lod);
                    points[z][x].create_instance(get_world_pos(x,0,z), _scenario, region->get_material_rid());
                    rs->instance_set_visible(points[z][x].instance, false);
                    rs->instance_set_base(points[z][x].instance, mesh);
                    update_mesh_list.append(points[z][x].instance);
                }
            } else {
                points[z][x].size = -1;
                if(points[z][x].has_instance()){
                    remove_instance_list.append(points[z][x].instance);
                    points[z][x].instance = RID();
                    points[z][x].mesh = RID();
                }
            }
        }
    }
    return true;
}

int8_t MGrid::get_edge_num(const bool& left,const bool& right,const bool& top,const bool& bottom) {
    if(!left && !right && !top && !bottom){
        return M_MAIN;
    }
    if(left && !right && !top && !bottom){
            return M_L;
    }
    if(!left && right && !top && !bottom){
            return M_R;
    }
    if(!left && !right && top && !bottom){
            return M_T;
    }
    if(!left && !right && !top && bottom){
            return M_B;
    }
    if(left && !right && top && !bottom){
            return M_LT;
    }
    if(!left && right && top && !bottom){
            return M_RT;
    }
    if(left && !right && !top && bottom){
            return M_LB;
    }
    if(!left && right && !top && bottom){
            return M_RB;
    }
    if(left && right && top && bottom){
            return M_LRTB;
    }
    UtilityFunctions::print("Error Can not find correct Edge");
    UtilityFunctions::print(left, " ", right, " ", top, " ", bottom);
    return -1;
}

Ref<ShaderMaterial> MGrid::get_material() {
    return _material;
}



void MGrid::set_material(Ref<ShaderMaterial> material) {
    if(material.is_valid()){
        if(material->get_shader().is_valid()){
            _material = material;
        }
    }
}


MGridPos MGrid::get_3d_grid_pos_by_middle_point(MGridPos input) {
    MRegion* r = get_region_by_point(input.x,input.z);
    //Calculating middle point in chunks
    real_t half = ((real_t)_chunks->base_size_meter)/2;
    Vector3 middle_point_chunk = get_world_pos(input) + Vector3(half,0, half);
    middle_point_chunk.y = r->get_closest_height(middle_point_chunk);
    return get_grid_pos(middle_point_chunk);
}

real_t MGrid::get_closest_height(const Vector3& pos) {
    MGridPos grid_pos = get_grid_pos(pos);
    if(!_grid_bound.has_point(grid_pos)){
        return 0;
    }
    MRegion* r = get_region_by_point(grid_pos.x, grid_pos.z);
    return r->get_closest_height(pos);
}

void MGrid::update_chunks(const Vector3& cam_pos) {
    set_cam_pos(cam_pos);
    update_search_bound();
    cull_out_of_bound();
    update_lods();
    merge_chunks();
}

void MGrid::apply_update_chunks() {
    for(int i=0; i < _regions_count; i++){
        regions[i].apply_update();
    }
    RenderingServer* rs = RenderingServer::get_singleton();
    for(RID rm: remove_instance_list){
        rs->free_rid(rm);
    }
    for(RID add : update_mesh_list){
        rs->instance_set_visible(add, true);
    }
    MRegion::number_of_tex_update = 0;
}

void MGrid::update_physics(const Vector3& cam_pos){
    MGridPos pos = get_region_pos_by_world_pos(cam_pos);
    MBound bound(pos);
    bound.left -= physics_update_limit;
    bound.right += physics_update_limit;
    bound.top -= physics_update_limit;
    bound.bottom += physics_update_limit;
    //Clear last physics if they are not in the current bound
    for(int32_t z=_last_region_grid_bound.top; z<=_last_region_grid_bound.bottom;z++){
        for(int32_t x=_last_region_grid_bound.left; x<=_last_region_grid_bound.right; x++){
            MGridPos p(x,0,z);
            if(_region_grid_bound.has_point(p) && !bound.has_point(p)){
                get_region(x,z)->remove_physics();
            }
        }
    }
    _last_region_grid_bound = bound;
    for(int32_t z=bound.top; z<=bound.bottom;z++){
        for(int32_t x=bound.left; x<=bound.right; x++){
            MGridPos p(x,0,z);
            if(_region_grid_bound.has_point(p)){
                get_region(x,z)->create_physics();
            }
        }
    }
}