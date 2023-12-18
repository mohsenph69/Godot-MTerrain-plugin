#include "mregion.h"

#include <godot_cpp/classes/reg_ex.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/rendering_server.hpp>

#define RS RenderingServer::get_singleton()

#include "mgrid.h"

Vector<Vector3> MRegion::nvecs;

MRegion::MRegion(){
    lods = memnew(VSet<int8_t>);
}

MRegion::~MRegion(){
    memdelete(lods);
	remove_physics();
	images.clear();
}

void MRegion::set_material(RID input) {
    if(!input.is_valid()){
        return;
    }
	_material_rid = input;
	RS->material_set_param(_material_rid,"region_size",grid->region_size_meter);
	RS->material_set_param(_material_rid,"region_world_position",world_pos);
}

RID MRegion::get_material_rid() {
	return _material_rid;
}

void MRegion::add_image(MImage* input) {
    images.append(input);
	if(input->name=="heightmap"){
		heightmap = input;
	}
	else if(input->name=="normals"){
		normals = input;
	}
}

void MRegion::configure() {
	ERR_FAIL_COND_MSG(!heightmap,"Heightmap is not loaded check MTerrain Material");
	ERR_FAIL_COND_MSG(!normals,"Normals is not loaded check MTerrain Material");
	for(int i=0; i < images.size(); i++){
		images[i]->region = this;
		if(images[i]->name != "normals"){
			images[i]->active_undo = true;
		}
		if(images[i]->width != grid->region_pixel_size){
			images[i]->create(grid->region_pixel_size, images[i]->format);
			if(images[i]->name == "heightmap"){
				min_height = -0.1;
				max_height = 0.1;
			}
			ERR_FAIL_MSG("Region size not match for "+images[i]->name+ " please Check region size");
		}
	}
	int64_t index = 0;
	int64_t s = heightmap->data.size()/4;
	float* ptr = ((float *)heightmap->data.ptr());
	while (index < s)
	{
		float val = ptr[index];
		if(val > max_height){
			max_height = val;
		}
		if (val < min_height)
		{
			min_height = val;
		}
		index++;
	}
	uint32_t ss = grid->region_pixel_size - 1;
	normals_pixel_region.left = pos.x*ss;
	normals_pixel_region.right = (pos.x + 1)*ss;
	normals_pixel_region.top = pos.z*ss;
	normals_pixel_region.bottom = (pos.z + 1)*ss;
	//normals_pixel_region.grow_all_side(grid->grid_pixel_region);
}

void MRegion::update_region() {
	if(!_material_rid.is_valid()){
		return;
	}
    int8_t curren_lod = (lods->is_empty()) ? -1 : (*lods)[0];
	current_scale = pow(2, (int32_t)curren_lod);
	for(int i=0; i < images.size(); i++){
		MImage* img = images[i];
			if(last_lod != curren_lod || img->is_dirty){
			// if out of bound then we just add an empty texture
			if(curren_lod == -1){
				img->update_texture(0,false);
			} else {
				img->update_texture(current_scale,false);
			}
		}
	}
    last_lod = curren_lod;
    memdelete(lods);
    lods = memnew(VSet<int8_t>);
}

void MRegion::insert_lod(const int8_t& input) {
    lods->insert(input);
}

void MRegion::apply_update() {
	if(!_material_rid.is_valid()){
		return;
	}
	for(int i=0; i < images.size(); i++){
		MImage* img = images[i];
		img->apply_update();
	}
	current_image_size = ((double)heightmap->current_size);
	RS->material_set_param(_material_rid,"region_a",(current_image_size-1)/current_image_size);
	RS->material_set_param(_material_rid,"region_b",0.5/current_image_size);
	RS->material_set_param(_material_rid,"min_lod",last_lod);
}

void MRegion::create_physics() {
	ERR_FAIL_COND(heightmap == nullptr);
	if(has_physic){
		return;
	}
	physic_body = PhysicsServer3D::get_singleton()->body_create();
	PhysicsServer3D::get_singleton()->body_set_mode(physic_body, PhysicsServer3D::BodyMode::BODY_MODE_STATIC);
	heightmap_shape = PhysicsServer3D::get_singleton()->heightmap_shape_create();
	Dictionary d;
	d["width"] = heightmap->width;
	d["depth"] = heightmap->height;
	#ifdef REAL_T_IS_DOUBLE
	const float* hdata = (float*)heightmap->data.ptr();
	PackedFloat64Array hdata64;
	int size = heightmap->data.size()/4;
	hdata64.resize(size);
	for(int i=0;i<size;i++){
		hdata64.set(i,hdata[i]);
	}
	d["heights"] = hdata64;
	#else
	d["heights"] = heightmap->data.to_float32_array();
	#endif
	d["min_height"] = min_height;
	d["max_height"] = max_height;
	Vector3 pos = world_pos + Vector3(grid->region_size_meter,0,grid->region_size_meter)/2;
	Basis basis(Vector3(grid->_chunks->h_scale,0,0), Vector3(0,1,0), Vector3(0,0,grid->_chunks->h_scale) );
	Transform3D transform(basis, pos);
	PhysicsServer3D::get_singleton()->shape_set_data(heightmap_shape, d);
	PhysicsServer3D::get_singleton()->body_add_shape(physic_body, heightmap_shape);
	PhysicsServer3D::get_singleton()->body_set_space(physic_body, grid->space);
	PhysicsServer3D::get_singleton()->body_set_state(physic_body, PhysicsServer3D::BodyState::BODY_STATE_TRANSFORM,transform);
	has_physic = true;
}

void MRegion::remove_physics(){
	if(!has_physic){
		return;
	}
	PhysicsServer3D::get_singleton()->free_rid(physic_body);
	PhysicsServer3D::get_singleton()->free_rid(heightmap_shape);
	physic_body = RID();
	heightmap_shape = RID();
	has_physic = false;
}

Color MRegion::get_pixel(const uint32_t& x, const uint32_t& y, const int32_t& index) const {
	return images[index]->get_pixel(x,y);
}

void MRegion::set_pixel(const uint32_t& x, const uint32_t& y,const Color& color,const int32_t& index){
	images[index]->set_pixel(x,y,color);
}

Color MRegion::get_normal_by_pixel(const uint32_t& x, const uint32_t& y) const{
	return normals->get_pixel(x,y);
}

void MRegion::set_normal_by_pixel(const uint32_t& x, const uint32_t& y,const Color& value){
	normals->set_pixel(x,y,value);
}

real_t MRegion::get_height_by_pixel(const uint32_t& x, const uint32_t& y) const {
	return heightmap->get_pixel_RF(x,y);
}

void MRegion::set_height_by_pixel(const uint32_t& x, const uint32_t& y,const real_t& value){
	heightmap->set_pixel_RF(x,y,value);
}

real_t MRegion::get_closest_height(Vector3 pos){
	pos.x -= world_pos.x;
	pos.z -= world_pos.z;
	pos /= grid->_chunks->h_scale;
	uint32_t x = (uint32_t)round(pos.x);
	uint32_t y = (uint32_t)round(pos.z);
	return heightmap->get_pixel_RF(x,y);
}

real_t MRegion::get_height_by_pixel_in_layer(const uint32_t& x, const uint32_t& y) const{
	return heightmap->get_pixel_RF_in_layer(x,y);
}

void MRegion::update_all_dirty_image_texture(){
	for(int i=0; i < images.size(); i++){
		if(images[i]->is_dirty){
			images[i]->update_texture(images[i]->current_scale, true);
		}
	}
}


void MRegion::save_image(int index,bool force_save) {
	images[index]->save(force_save);
}

void MRegion::recalculate_normals(){
	if(grid)
		grid->generate_normals_thread(normals_pixel_region);
}

void MRegion::refresh_all_uniforms(){
	if(_material_rid.is_valid()){
		RS->material_set_param(_material_rid,"region_size",grid->region_size_meter);
		RS->material_set_param(_material_rid,"region_world_position",world_pos);

		RS->material_set_param(_material_rid,"region_a",(current_image_size-1)/current_image_size);
		RS->material_set_param(_material_rid,"region_b",0.5/current_image_size);
		RS->material_set_param(_material_rid,"min_lod",last_lod);
	}
}