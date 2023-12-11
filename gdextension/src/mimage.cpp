#include "mimage.h"
#include <godot_cpp/classes/resource_saver.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/rendering_server.hpp>

#define RS RenderingServer::get_singleton()

#include "mbound.h"
#include "mregion.h"

MImage::MImage(){
	
}
MImage::MImage(const String& _file_path,const String& _layers_folder,const String& _name,const String& _uniform_name,MGridPos _grid_pos,const int& _compression){
    file_path = _file_path;
    name = _name;
    uniform_name = _uniform_name;
    compression = _compression;
	layerDataDir = _layers_folder;
	grid_pos = _grid_pos;
}

MImage::MImage(const String& _file_path,const String& _layers_folder,const String& _name,const String& _uniform_name,MGridPos _grid_pos,MRegion* r){
	file_path = _file_path;
    name = _name;
    uniform_name = _uniform_name;
    region = r;
	layerDataDir = _layers_folder;
	grid_pos = _grid_pos;
}


MImage::~MImage(){
	for(HashMap<int,MImageUndoData>::Iterator it=undo_data.begin();it!=undo_data.end();++it){
		it->value.free();
	}
	for(int i=1;i<image_layers.size();i++){
		memdelete(image_layers[i]);
	}
	if(new_tex_rid.is_valid()){
		RS->free_rid(new_tex_rid);
	}
	if(old_tex_rid.is_valid()){
		RS->free_rid(old_tex_rid);
	}
}

void MImage::load(){
    Ref<Image> img = ResourceLoader::get_singleton()->load(file_path);
    width = img->get_size().x;
	height = img->get_size().x;
	total_pixel_amount = width*height;
    format = img->get_format();
	pixel_size = get_format_pixel_size(format);
    data = img->get_data();
    current_size = width;
	if(pixel_size==0){
		ERR_FAIL_EDMSG("Unsported image format for Mterrain");
	}
	is_save = true;
	image_layers.push_back(&data);
	layer_names.push_back("background");
	is_saved_layers.push_back(true);
}

void MImage::set_active_layer(int l){
	if(l!=active_layer){
		remove_undo_data_in_layer(active_layer);
	}
	active_layer = l;
}

// This must called alway after loading background image
void MImage::add_layer(String lname){
	ERR_FAIL_COND_EDMSG(data.size()==0,"You must first load the background image and then the layers");
	ERR_FAIL_COND_EDMSG(name!="heightmap","Layers is supported only for heightmap images");
	String ltname = lname +"_x"+itos(grid_pos.x)+"_y"+itos(grid_pos.z)+ ".r32";
	String layer_path = layerDataDir.path_join(ltname);
	if(FileAccess::file_exists(layer_path)){
		Ref<FileAccess> file = FileAccess::open(layer_path, FileAccess::READ);
		ERR_FAIL_COND(file->get_length() != data.size());
		PackedByteArray* img_layer_data = memnew(PackedByteArray);
		img_layer_data->resize(data.size());
		uint8_t* ptrw = img_layer_data->ptrw();
		for(int s=0;s<data.size();s++){
			ptrw[s] = file->get_8();
		}
		file->close();
		image_layers.push_back(img_layer_data);
		layer_names.push_back(lname);
		is_saved_layers.push_back(true);
		if(lname=="holes"){
			for(uint32_t i=0;i<total_pixel_amount;i++){
				if(!std::isnan(((float *)img_layer_data->ptr())[i])){
					((float *)data.ptrw())[i] = std::numeric_limits<float>::quiet_NaN();
				}
			}
		} else {
			for(uint32_t i=0;i<total_pixel_amount;i++){
				((float *)data.ptrw())[i] += ((float *)img_layer_data->ptr())[i];
			}
		}
	} else {
		PackedByteArray* new_layer = memnew(PackedByteArray);
		//we empty the new layer but never remove this from Vector because this cause ID of other will change
		image_layers.push_back(new_layer);
		layer_names.push_back(lname);
		is_saved_layers.push_back(true);
	}
	if(lname=="holes"){
		holes_layer = image_layers.size() - 1;
	}
}

void MImage::merge_layer(){
	String path = layer_names[active_layer] +"_x"+itos(grid_pos.x)+"_y"+itos(grid_pos.z)+ ".r32";
	path = layerDataDir.path_join(path);
	
	if(FileAccess::file_exists(path)){
		DirAccess::remove_absolute(path);
	}
	is_saved_layers.set(0,false); // make the background layer save to be false
	is_save = false;
	remove_undo_data_in_layer(active_layer);
	memdelete(image_layers[active_layer]);
	image_layers.remove_at(active_layer);
	is_saved_layers.remove_at(active_layer);
	layer_names.remove_at(active_layer);
	save(false);
}

void MImage::remove_layer(bool is_visible){
	if(image_layers[active_layer]->size()==0){
		return;
	}
	const uint8_t* ptr=image_layers[active_layer]->ptr();
	if(is_visible){
		if(active_layer==holes_layer){
			for(uint32_t i=0;i<total_pixel_amount;i++){
				if(!std::isnan(((float *)ptr)[i])){
					((float *)data.ptrw())[i] = ((float *)ptr)[i];
				}
			}
		} else {
			for(uint32_t i=0;i<total_pixel_amount;i++){
				((float *)data.ptrw())[i] -= ((float *)ptr)[i];
			}
		}
		is_dirty = true;
	}
	String path = layer_names[active_layer] +"_x"+itos(grid_pos.x)+"_y"+itos(grid_pos.z)+ ".r32";
	path = layerDataDir.path_join(path);
	is_saved_layers.set(active_layer,true);
	is_saved_layers.set(0,false);
	is_save = false;
	if(FileAccess::file_exists(path)){
		DirAccess::remove_absolute(path);
	}
	memdelete(image_layers[active_layer]);
	image_layers.remove_at(active_layer);
	is_saved_layers.remove_at(active_layer);
	layer_names.remove_at(active_layer);
	remove_undo_data_in_layer(active_layer);
	save(false);
}

void MImage::layer_visible(bool input){
	if(image_layers[active_layer]->size()==0){
		return;
	}
	// There is no control if the layer is currently visibile or not
	// These checks must be done in Grid Level
	// We save before hiding the layer to not complicating the save system for now
	save(false); // So we are sure in the save method we should do nothing
	const uint8_t* ptr=image_layers[active_layer]->ptr();
	if(input){
		if(active_layer==holes_layer){
			for(uint32_t i=0;i<total_pixel_amount;i++){
				if(!std::isnan(((float *)ptr)[i])){
					((float *)image_layers[active_layer]->ptrw())[i] = ((float *)data.ptrw())[i];
					((float *)data.ptrw())[i] = std::numeric_limits<float>::quiet_NaN();
				}
			}
		} else {
			for(uint32_t i=0;i<total_pixel_amount;i++){
				((float *)data.ptrw())[i] += ((float *)ptr)[i];
			}
		}
	} else {
		if(active_layer==holes_layer){
			for(uint32_t i=0;i<total_pixel_amount;i++){
				if(!std::isnan(((float *)ptr)[i])){
					((float *)data.ptrw())[i] = ((float *)ptr)[i];
				}
			}
		} else {
			for(uint32_t i=0;i<total_pixel_amount;i++){
				((float *)data.ptrw())[i] -= ((float *)ptr)[i];
			}
		}
	}
	is_dirty = true;
}

void MImage::create(uint32_t _size, Image::Format _format) {
	width = _size;
	height =_size;
	total_pixel_amount = width*height;
	format = _format;
	pixel_size = get_format_pixel_size(format);
	data.clear();
	data.resize(width*width*pixel_size);
	current_size = width;
	image_layers.push_back(&data);
	layer_names.push_back("Background");
	is_saved_layers.push_back(false);
}

void MImage::create(uint32_t _width,uint32_t _height, Image::Format _format){
	width = _width;
	height =_height;
	total_pixel_amount = width*height;
	format = _format;
	pixel_size = get_format_pixel_size(format);
	data.clear();
	data.resize(width*_height*pixel_size);
	current_size = width;
	image_layers.push_back(&data);
	layer_names.push_back("Background");
	is_saved_layers.push_back(false);
}

void MImage::get_data(PackedByteArray* out,int scale){
    current_size = ((width - 1)/scale) + 1;
    out->resize(current_size*current_size*pixel_size);
    for(int32_t y=0; y < current_size; y++){
        for(int32_t x=0; x < current_size; x++){
            int32_t main_offset = (scale*x+width*y*scale)*pixel_size;
            int32_t new_offset = (x+y*current_size)*pixel_size;
            for(int32_t i=0; i < pixel_size; i++){
                (*out)[new_offset+i] = data[main_offset+i];
            }
        }
    }
}

void MImage::update_texture(int scale,bool apply_update){
	if(scale > 0){
		Ref<Image> new_img;
		if(scale!=0){
			PackedByteArray scaled_data;
			get_data(&scaled_data,scale);
			new_img = Image::create_from_data(current_size,current_size,false,format,scaled_data);
		} else {
			new_img = Image::create_from_data(current_size,current_size,false,format,data);
		}	
		if(current_scale==scale && apply_update){ //This will improve the sculpting speed a little bit
			RS->texture_2d_update(new_tex_rid,new_img,0);
			return;
		}
		old_tex_rid = new_tex_rid;
		new_tex_rid = RS->texture_2d_create(new_img);
		current_scale = scale;
	}
	if(apply_update){
		if(old_tex_rid.is_valid()){
			RS->call_deferred("free_rid",old_tex_rid);
			old_tex_rid = RID();
		}
		RS->material_set_param(region->get_material_rid(),uniform_name,new_tex_rid);
		is_dirty = false;
	} else {
		has_texture_to_apply = true;
	}
}

void MImage::apply_update() {
	//update_mutex.lock();
	if(has_texture_to_apply){
		if(old_tex_rid.is_valid()){
			RS->call_deferred("free_rid",old_tex_rid);
			old_tex_rid = RID();
		}
		RS->material_set_param(region->get_material_rid(),uniform_name,new_tex_rid);
		has_texture_to_apply = false;
		is_dirty = false;
	}
	//update_mutex.unlock();
}


// This works only for Format_RF
real_t MImage::get_pixel_RF(const uint32_t&x, const uint32_t& y) const {
	uint32_t ofs = (x + y*width);
    return ((float *)data.ptr())[ofs];
}

void MImage::set_pixel_RF(const uint32_t&x, const uint32_t& y,const real_t& value){
	check_undo();
	// not visibile layers should not be modified but as this called many times
	// it is better to check that in upper level
	uint32_t ofs = (x + y*width);
	#ifdef M_IMAGE_LAYER_ON
	// For when we have only background layer
	if(active_layer==0){
		((float *)data.ptrw())[ofs] = value;
		is_saved_layers.set(0,false);
		is_dirty = true;
		is_save = false;
		return;
	}
	// Check if we the layer is empty we resize that
	if(image_layers[active_layer]->size()!=data.size()){
		image_layers[active_layer]->resize(data.size());
		if(active_layer==holes_layer){ // Initialzation in case it is a holes layer
			float* ptrw = (float*)image_layers[active_layer]->ptrw();
			for(int i=0; i < total_pixel_amount; i++){
				ptrw[i] = std::numeric_limits<float>::quiet_NaN();
			}
		}
	}
	is_saved_layers.set(active_layer,false);
	if(std::isnan(value)){
		if(!std::isnan(((float *)data.ptr())[ofs])){
			((float *)image_layers[active_layer]->ptrw())[ofs] = ((float *)data.ptr())[ofs];
		}
		((float *)data.ptrw())[ofs] = value;
	} else if(std::isnan(((float *)data.ptr())[ofs])) {
		((float *)data.ptrw())[ofs] = ((float *)image_layers[active_layer]->ptr())[ofs];
		((float *)image_layers[active_layer]->ptrw())[ofs] = std::numeric_limits<float>::quiet_NaN();
	} else {
		float dif = value - ((float *)data.ptr())[ofs];
		((float *)image_layers[active_layer]->ptrw())[ofs] += dif;
		((float *)data.ptrw())[ofs] = value;
	}
	#else
	((float *)data.ptrw())[ofs] = value;
	#endif
	is_dirty = true;
	is_save = false;
}

Color MImage::get_pixel(const uint32_t&x, const uint32_t& y) const {
	uint32_t ofs = (x + y*width);
	return _get_color_at_ofs(data.ptr(), ofs);
}

void MImage::set_pixel(const uint32_t&x, const uint32_t& y,const Color& color){
	check_undo();
	uint32_t ofs = (x + y*width);
	_set_color_at_ofs(data.ptrw(), ofs, color);
	is_dirty = true;
	is_save = false;
}

void MImage::set_pixel_by_data_pointer(uint32_t x,uint32_t y,uint8_t* ptr){
	check_undo();
	uint32_t ofs = (x + y*width);
	uint8_t* ptrw = data.ptrw() + ofs*pixel_size;
	mempcpy(ptrw,ptr,pixel_size);
	is_dirty = true;
	is_save = false;
}

const uint8_t* MImage::get_pixel_by_data_pointer(uint32_t x,uint32_t y){
	uint32_t ofs = (x + y*width);
	return data.ptr() + ofs*pixel_size;
}

void MImage::save(bool force_save) {
	if(name!="heightmap"){
		Ref<Image> img = Image::create_from_data(width,height,false,format,data);
		godot::Error err = ResourceSaver::get_singleton()->save(img,file_path);
		ERR_FAIL_COND_MSG(err,"Can not save image, image class erro: "+itos(err));
		is_save = true;
		return;
	}
	if(force_save || !is_save) {
		if(!is_saved_layers[0]){
			PackedByteArray background_data = data;
			int total_pixel = width*height;
			for(int i=1;i<image_layers.size();i++){
				if(!image_layers[i]->is_empty()){
					if(i==holes_layer){
						for(int j=0;j<total_pixel;j++){
							if(std::isnan(((float *)image_layers[i]->ptr())[j])){
								((float *)background_data.ptrw())[j] = ((float *)image_layers[i]->ptr())[j];
							}
						}
					} else {
						for(int j=0;j<total_pixel;j++){
							((float *)background_data.ptrw())[j] -= ((float *)image_layers[i]->ptr())[j];
						}
					}
				}
			}
			Ref<Image> img = Image::create_from_data(width,height,false,format,background_data);
			godot::Error err = ResourceSaver::get_singleton()->save(img,file_path);
			ERR_FAIL_COND_MSG(err,"Can not save background image, image class erro: "+itos(err));
			is_saved_layers.set(0,true);
		}
		for(int i=1;i<image_layers.size();i++){
			if(!is_saved_layers[i]){
				String lname = layer_names[i]+"_x"+itos(grid_pos.x)+"_y"+itos(grid_pos.z)+ ".r32";
				String layer_path = layerDataDir.path_join(lname);
				Ref<FileAccess> file = FileAccess::open(layer_path, FileAccess::WRITE);
				const uint8_t* ptr = image_layers[i]->ptr();
				for(int j=0;j<image_layers[i]->size();j++){
					file->store_8(ptr[j]);
				}
				file->close();
				is_saved_layers.set(i,true);
			}
		}
		is_save = true;
	}
}

void MImage::check_undo(){
	update_mutex.lock();
	if(undo_data.has(current_undo_id) || !active_undo){
		update_mutex.unlock();
		return;
	}
	MImageUndoData ur;
	ur.layer = active_layer;
	if(image_layers[active_layer]->is_empty()){
		ur.empty = true;
	} else {
		ur.data = memnew_arr(uint8_t,image_layers[active_layer]->size());
		memcpy(ur.data,image_layers[active_layer]->ptr(),image_layers[active_layer]->size());
	}
	undo_data.insert(current_undo_id,ur);
	update_mutex.unlock();
}

void MImage::remove_undo_data(int ur_id){
	if(undo_data.has(ur_id)){
		undo_data[ur_id].free();
		undo_data.erase(ur_id);
	}
}

void MImage::remove_undo_data_in_layer(int layer_index){
	for(HashMap<int,MImageUndoData>::Iterator it=undo_data.begin();it!=undo_data.end();++it){
		if(it->value.layer==layer_index){
			it->value.free();
			undo_data.erase(it->key);
		}
	}
}

void MImage::go_to_undo(int ur_id){
	if(!undo_data.has(ur_id)){
		return; // noting to do here we don't have any data change corrispond to this undo redo
	}
	MImageUndoData ur = undo_data[ur_id];
	if(ur.layer!=active_layer){
		UtilityFunctions::print("Oh not equallllll active layer is ",active_layer);
	}
	if(ur.layer==0){
		memcpy(data.ptrw(),ur.data,data.size());
	} else if(ur.layer==holes_layer) {
		const uint8_t* ptr=image_layers[active_layer]->ptr();
		for(uint32_t i=0;i<total_pixel_amount;i++){
			// First Remove all holes and get all heigh value
			if(!std::isnan(((float *)ptr)[i])){
				((float *)data.ptrw())[i] = ((float *)ptr)[i];
			}
		}
		if(!ur.empty){ // if it is empty it means it was no hole in terrain before and the hole layer was empty in this region
			for(uint32_t i=0;i<total_pixel_amount;i++){
				//Now set the hole according to the last stage
				if(!std::isnan(((float*)ur.data)[i]) ){
					((float *)data.ptrw())[i] = std::numeric_limits<float>::quiet_NaN();
				}
			}
			memcpy(image_layers[holes_layer]->ptrw(),ur.data,data.size());
		} else {
			UtilityFunctions::print("Arrive begining removing ");
			image_layers[active_layer]->resize(0);
		}
	} else {
		// First Remove the layer which we want to undo
		const uint8_t* ptr=image_layers[active_layer]->ptr();
		for(uint32_t i=0;i<total_pixel_amount;i++){
			((float *)data.ptrw())[i] -= ((float *)ptr)[i];
		}
		//Now we add the backup data
		if(!ur.empty){ // the layer was empty at that stage no need to do anything
			for(uint32_t i=0;i<total_pixel_amount;i++){
				((float *)data.ptrw())[i] += ((float *)ur.data)[i];
			}
			//And we copy the backup data into that layer
			memcpy(image_layers[ur.layer]->ptrw(),ur.data,data.size());
		}
	}
	if(name=="heightmap" && region){
		region->recalculate_normals();
	}
	is_dirty = true;
}

bool MImage::has_undo(int ur_id){
	return undo_data.has(ur_id);
}

Color MImage::_get_color_at_ofs(const uint8_t *ptr, uint32_t ofs) const {
	switch (format) {
		case Image::FORMAT_L8: {
			float l = ptr[ofs] / 255.0;
			return Color(l, l, l, 1);
		}
		case Image::FORMAT_LA8: {
			float l = ptr[ofs * 2 + 0] / 255.0;
			float a = ptr[ofs * 2 + 1] / 255.0;
			return Color(l, l, l, a);
		}
		case Image::FORMAT_R8: {
			float r = ptr[ofs] / 255.0;
			return Color(r, 0, 0, 1);
		}
		case Image::FORMAT_RG8: {
			float r = ptr[ofs * 2 + 0] / 255.0;
			float g = ptr[ofs * 2 + 1] / 255.0;
			return Color(r, g, 0, 1);
		}
		case Image::FORMAT_RGB8: {
			float r = ptr[ofs * 3 + 0] / 255.0;
			float g = ptr[ofs * 3 + 1] / 255.0;
			float b = ptr[ofs * 3 + 2] / 255.0;
			return Color(r, g, b, 1);
		}
		case Image::FORMAT_RGBA8: {
			float r = ptr[ofs * 4 + 0] / 255.0;
			float g = ptr[ofs * 4 + 1] / 255.0;
			float b = ptr[ofs * 4 + 2] / 255.0;
			float a = ptr[ofs * 4 + 3] / 255.0;
			return Color(r, g, b, a);
		}
		case Image::FORMAT_RGBA4444: {
			uint16_t u = ((uint16_t *)ptr)[ofs];
			float r = ((u >> 12) & 0xF) / 15.0;
			float g = ((u >> 8) & 0xF) / 15.0;
			float b = ((u >> 4) & 0xF) / 15.0;
			float a = (u & 0xF) / 15.0;
			return Color(r, g, b, a);
		}
		case Image::FORMAT_RGB565: {
			uint16_t u = ((uint16_t *)ptr)[ofs];
			float r = (u & 0x1F) / 31.0;
			float g = ((u >> 5) & 0x3F) / 63.0;
			float b = ((u >> 11) & 0x1F) / 31.0;
			return Color(r, g, b, 1.0);
		}
		case Image::FORMAT_RF: {
			float r = ((float *)ptr)[ofs];
			return Color(r, 0, 0, 1);
		}
		case Image::FORMAT_RGF: {
			float r = ((float *)ptr)[ofs * 2 + 0];
			float g = ((float *)ptr)[ofs * 2 + 1];
			return Color(r, g, 0, 1);
		}
		case Image::FORMAT_RGBF: {
			float r = ((float *)ptr)[ofs * 3 + 0];
			float g = ((float *)ptr)[ofs * 3 + 1];
			float b = ((float *)ptr)[ofs * 3 + 2];
			return Color(r, g, b, 1);
		}
		case Image::FORMAT_RGBAF: {
			float r = ((float *)ptr)[ofs * 4 + 0];
			float g = ((float *)ptr)[ofs * 4 + 1];
			float b = ((float *)ptr)[ofs * 4 + 2];
			float a = ((float *)ptr)[ofs * 4 + 3];
			return Color(r, g, b, a);
		}
		case Image::FORMAT_RGBE9995: {
			return Color::from_rgbe9995(((uint32_t *)ptr)[ofs]);
		}
		default: {
			ERR_FAIL_V_MSG(Color(), "Unsportet format for Mterrain");
		}
	}
}

void MImage::_set_color_at_ofs(uint8_t *ptr, uint32_t ofs, const Color &p_color) {
	check_undo();
	switch (format) {
		case Image::FORMAT_L8: {
			ptr[ofs] = uint8_t(CLAMP(p_color.get_v() * 255.0, 0, 255));
		} break;
		case Image::FORMAT_LA8: {
			ptr[ofs * 2 + 0] = uint8_t(CLAMP(p_color.get_v() * 255.0, 0, 255));
			ptr[ofs * 2 + 1] = uint8_t(CLAMP(p_color.a * 255.0, 0, 255));
		} break;
		case Image::FORMAT_R8: {
			ptr[ofs] = uint8_t(CLAMP(p_color.r * 255.0, 0, 255));
		} break;
		case Image::FORMAT_RG8: {
			ptr[ofs * 2 + 0] = uint8_t(CLAMP(p_color.r * 255.0, 0, 255));
			ptr[ofs * 2 + 1] = uint8_t(CLAMP(p_color.g * 255.0, 0, 255));
		} break;
		case Image::FORMAT_RGB8: {
			ptr[ofs * 3 + 0] = uint8_t(CLAMP(p_color.r * 255.0, 0, 255));
			ptr[ofs * 3 + 1] = uint8_t(CLAMP(p_color.g * 255.0, 0, 255));
			ptr[ofs * 3 + 2] = uint8_t(CLAMP(p_color.b * 255.0, 0, 255));
		} break;
		case Image::FORMAT_RGBA8: {
			ptr[ofs * 4 + 0] = uint8_t(CLAMP(p_color.r * 255.0, 0, 255));
			ptr[ofs * 4 + 1] = uint8_t(CLAMP(p_color.g * 255.0, 0, 255));
			ptr[ofs * 4 + 2] = uint8_t(CLAMP(p_color.b * 255.0, 0, 255));
			ptr[ofs * 4 + 3] = uint8_t(CLAMP(p_color.a * 255.0, 0, 255));

		} break;
		case Image::FORMAT_RGBA4444: {
			uint16_t rgba = 0;

			rgba = uint16_t(CLAMP(p_color.r * 15.0, 0, 15)) << 12;
			rgba |= uint16_t(CLAMP(p_color.g * 15.0, 0, 15)) << 8;
			rgba |= uint16_t(CLAMP(p_color.b * 15.0, 0, 15)) << 4;
			rgba |= uint16_t(CLAMP(p_color.a * 15.0, 0, 15));

			((uint16_t *)ptr)[ofs] = rgba;

		} break;
		case Image::FORMAT_RGB565: {
			uint16_t rgba = 0;

			rgba = uint16_t(CLAMP(p_color.r * 31.0, 0, 31));
			rgba |= uint16_t(CLAMP(p_color.g * 63.0, 0, 33)) << 5;
			rgba |= uint16_t(CLAMP(p_color.b * 31.0, 0, 31)) << 11;

			((uint16_t *)ptr)[ofs] = rgba;

		} break;
		case Image::FORMAT_RF: {
			((float *)ptr)[ofs] = p_color.r;
		} break;
		case Image::FORMAT_RGF: {
			((float *)ptr)[ofs * 2 + 0] = p_color.r;
			((float *)ptr)[ofs * 2 + 1] = p_color.g;
		} break;
		case Image::FORMAT_RGBF: {
			((float *)ptr)[ofs * 3 + 0] = p_color.r;
			((float *)ptr)[ofs * 3 + 1] = p_color.g;
			((float *)ptr)[ofs * 3 + 2] = p_color.b;
		} break;
		case Image::FORMAT_RGBAF: {
			((float *)ptr)[ofs * 4 + 0] = p_color.r;
			((float *)ptr)[ofs * 4 + 1] = p_color.g;
			((float *)ptr)[ofs * 4 + 2] = p_color.b;
			((float *)ptr)[ofs * 4 + 3] = p_color.a;
		} break;
		case Image::FORMAT_RGBE9995: {
			((uint32_t *)ptr)[ofs] = p_color.to_rgbe9995();

		} break;
		default: {
			ERR_FAIL_MSG("Can't set_pixel() on compressed image, sorry.");
		}
	}
}


int MImage::get_format_pixel_size(Image::Format p_format) {
	switch (p_format) {
		case Image::FORMAT_L8:
			return 1; //luminance
		case Image::FORMAT_LA8:
			return 2; //luminance-alpha
		case Image::FORMAT_R8:
			return 1;
		case Image::FORMAT_RG8:
			return 2;
		case Image::FORMAT_RGB8:
			return 3;
		case Image::FORMAT_RGBA8:
			return 4;
		case Image::FORMAT_RGBA4444:
			return 2;
		case Image::FORMAT_RGB565:
			return 2;
		case Image::FORMAT_RF:
			return 4; //float
		case Image::FORMAT_RGF:
			return 8;
		case Image::FORMAT_RGBF:
			return 12;
		case Image::FORMAT_RGBAF:
			return 16;
		case Image::FORMAT_RGBE9995:
			return 4;
	}
	return 0;
}



void MImage::set_pixel_in_channel(const uint32_t&x, const uint32_t& y,int8_t channel,const float& value){
	check_undo();
	uint32_t ofs = (x + y*width);
	uint8_t* ptr = data.ptrw();
	switch (format) {
		case Image::FORMAT_L8: {
			if(channel==0){
				ptr[ofs] = uint8_t(CLAMP(value * 255.0, 0, 255));
			}
		} break;
		case Image::FORMAT_LA8: {
			if(channel==0)
				ptr[ofs * 2 + 0] = uint8_t(CLAMP(value * 255.0, 0, 255));
			else if(channel==3)
				ptr[ofs * 2 + 1] = uint8_t(CLAMP(value * 255.0, 0, 255));
		} break;
		case Image::FORMAT_R8: {
			if(channel==0)
				ptr[ofs] = uint8_t(CLAMP(value * 255.0, 0, 255));
		} break;
		case Image::FORMAT_RG8: {
			if(channel==0)
				ptr[ofs * 2 + 0] = uint8_t(CLAMP(value * 255.0, 0, 255));
			if(channel==1)
				ptr[ofs * 2 + 1] = uint8_t(CLAMP(value * 255.0, 0, 255));
		} break;
		case Image::FORMAT_RGB8: {
			if(channel==0)
				ptr[ofs * 3 + 0] = uint8_t(CLAMP(value * 255.0, 0, 255));
			if(channel==1)
				ptr[ofs * 3 + 1] = uint8_t(CLAMP(value * 255.0, 0, 255));
			if(channel==2)
				ptr[ofs * 3 + 2] = uint8_t(CLAMP(value * 255.0, 0, 255));
		} break;
		case Image::FORMAT_RGBA8: {
			if(channel==0)
				ptr[ofs * 4 + 0] = uint8_t(CLAMP(value * 255.0, 0, 255));
			if(channel==1)
				ptr[ofs * 4 + 1] = uint8_t(CLAMP(value * 255.0, 0, 255));
			if(channel==2)
				ptr[ofs * 4 + 2] = uint8_t(CLAMP(value * 255.0, 0, 255));
			if(channel==3)
				ptr[ofs * 4 + 3] = uint8_t(CLAMP(value * 255.0, 0, 255));
		} break;
		case Image::FORMAT_RGBA4444: {
			uint16_t u = ((uint16_t *)ptr)[ofs];
			if(channel==0){
				u &= 0x0FFF;
				u |= uint16_t(CLAMP(value * 15.0, 0, 15)) << 12;
			}
			if(channel==1)
			{
				u &= 0xF0FF;
				u |= uint16_t(CLAMP(value * 15.0, 0, 15)) << 8;
			}
			if(channel==2){
				u &= 0xFF0F;
				u |= uint16_t(CLAMP(value * 15.0, 0, 15)) << 4;	
			}
			if(channel==3){
				u &= 0xFFF0;
				u |= uint16_t(CLAMP(value * 15.0, 0, 15));
			}
			((uint16_t *)ptr)[ofs] = u;

		} break;
		case Image::FORMAT_RGB565: {
			uint16_t rgba = ((uint16_t *)ptr)[ofs];
			if(channel==0)
				rgba = uint16_t(CLAMP(value * 31.0, 0, 31));
			if(channel==1)
				rgba |= uint16_t(CLAMP(value * 63.0, 0, 33)) << 5;
			if(channel==2)
				rgba |= uint16_t(CLAMP(value * 31.0, 0, 31)) << 11;

			((uint16_t *)ptr)[ofs] = rgba;

		} break;
		case Image::FORMAT_RF: {
			if(channel==0)
				((float *)ptr)[ofs] = value;
		} break;
		case Image::FORMAT_RGF: {
			if(channel==0)
				((float *)ptr)[ofs * 2 + 0] = value;
			if(channel==1)
				((float *)ptr)[ofs * 2 + 1] = value;
		} break;
		case Image::FORMAT_RGBF: {
			if(channel==0)
				((float *)ptr)[ofs * 3 + 0] = value;
			if(channel==1)
				((float *)ptr)[ofs * 3 + 1] = value;
			if(channel==2)
				((float *)ptr)[ofs * 3 + 2] = value;
		} break;
		case Image::FORMAT_RGBAF: {
			if(channel==0)
				((float *)ptr)[ofs * 4 + 0] = value;
			if(channel==1)
				((float *)ptr)[ofs * 4 + 1] = value;
			if(channel==2)
				((float *)ptr)[ofs * 4 + 2] = value;
			if(channel==3)
				((float *)ptr)[ofs * 4 + 3] = value;
		} break;
		default: {
			ERR_FAIL_MSG("Can't set_pixel_by_channel() on compressed image, sorry.");
		}
	}
}

#define INVALID_CHANELL 0

float MImage::get_pixel_in_channel(const uint32_t&x, const uint32_t& y,int8_t channel){
	uint32_t ofs = (x + y*width);
	const uint8_t* ptr = data.ptr();
	switch (format) {
		case Image::FORMAT_L8: {
			if(channel==0)
				return (float)ptr[ofs] / 255.0;
			return INVALID_CHANELL;
		}
		case Image::FORMAT_LA8: {
			if(channel==0)
				return (float)ptr[ofs * 2] / 255.0;
			if(channel==3)
				return (float)ptr[ofs * 2 + 1] / 255.0;
			return INVALID_CHANELL;
		}
		case Image::FORMAT_R8: {
			if(channel==0)
				return (float)ptr[ofs] / 255.0;
			return INVALID_CHANELL;
		}
		case Image::FORMAT_RG8: {
			if(channel<2)
				return (float)ptr[ofs * 2 + channel] / 255.0;
			return INVALID_CHANELL;
		}
		case Image::FORMAT_RGB8: {
			if(channel<3)
				return (float)ptr[ofs * 3 + channel] / 255.0;
			return INVALID_CHANELL;
		}
		case Image::FORMAT_RGBA8: {
			if(channel<4)
				return (float)ptr[ofs * 4 + channel] / 255.0;
			return INVALID_CHANELL;
		}
		case Image::FORMAT_RGBA4444: {
			uint16_t u = ((uint16_t *)ptr)[ofs];
			if(channel==0)
				return (float)((u >> 12) & 0xF) / 15.0;
			if(channel==1)
				return (float)((u >> 8) & 0xF) / 15.0;
			if(channel==2)
				return (float)((u >> 4) & 0xF) / 15.0;
			if(channel==3)
				return (float)(u & 0xF) / 15.0;
			return INVALID_CHANELL;
		}
		case Image::FORMAT_RGB565: {
			uint16_t u = ((uint16_t *)ptr)[ofs];
			if(channel==0)
				return (float)(u & 0x1F) / 31.0;
			if(channel==1)
				return (float)((u >> 5) & 0x3F) / 63.0;
			if(channel==2)
				return (float)((u >> 11) & 0x1F) / 31.0;
			return INVALID_CHANELL;
		}
		case Image::FORMAT_RF: {
			if(channel==0)
				return ((float *)ptr)[ofs];
			return INVALID_CHANELL;
		}
		case Image::FORMAT_RGF: {
			if(channel<2)
				return ((float *)ptr)[ofs * 2 + channel];
			return INVALID_CHANELL;
		}
		case Image::FORMAT_RGBF: {
			if(channel<3)
				return ((float *)ptr)[ofs * 3 + channel];
			return INVALID_CHANELL;
		}
		case Image::FORMAT_RGBAF: {
			if(channel<4)
				return ((float *)ptr)[ofs * 4 + channel];
			return INVALID_CHANELL;
		}
		default: {
			ERR_FAIL_V_MSG(INVALID_CHANELL, "Unsportet format for Mterrain");
		}
	}
}