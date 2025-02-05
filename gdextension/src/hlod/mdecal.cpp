#include "mdecal.h"


void MDecal::_bind_methods(){
	
	ClassDB::bind_method(D_METHOD("set_size", "size"), &MDecal::set_size);
	ClassDB::bind_method(D_METHOD("get_size"), &MDecal::get_size);
	
	ClassDB::bind_method(D_METHOD("set_texture", "type", "texture"), &MDecal::set_texture);
	ClassDB::bind_method(D_METHOD("get_texture", "type"), &MDecal::get_texture);

	ClassDB::bind_method(D_METHOD("set_emission_energy", "energy"), &MDecal::set_emission_energy);
	ClassDB::bind_method(D_METHOD("get_emission_energy"), &MDecal::get_emission_energy);
	
	ClassDB::bind_method(D_METHOD("set_albedo_mix", "energy"), &MDecal::set_albedo_mix);
	ClassDB::bind_method(D_METHOD("get_albedo_mix"), &MDecal::get_albedo_mix);

	ClassDB::bind_method(D_METHOD("set_modulate", "color"), &MDecal::set_modulate);
	ClassDB::bind_method(D_METHOD("get_modulate"), &MDecal::get_modulate);

	ClassDB::bind_method(D_METHOD("set_upper_fade", "fade"), &MDecal::set_upper_fade);
	ClassDB::bind_method(D_METHOD("get_upper_fade"), &MDecal::get_upper_fade);
	
	ClassDB::bind_method(D_METHOD("set_lower_fade", "fade"), &MDecal::set_lower_fade);
	ClassDB::bind_method(D_METHOD("get_lower_fade"), &MDecal::get_lower_fade);

	ClassDB::bind_method(D_METHOD("set_normal_fade", "fade"), &MDecal::set_normal_fade);
	ClassDB::bind_method(D_METHOD("get_normal_fade"), &MDecal::get_normal_fade);

	ClassDB::bind_method(D_METHOD("set_enable_distance_fade", "enable"), &MDecal::set_enable_distance_fade);
	ClassDB::bind_method(D_METHOD("is_distance_fade_enabled"), &MDecal::is_distance_fade_enabled);

	ClassDB::bind_method(D_METHOD("set_distance_fade_begin", "distance"), &MDecal::set_distance_fade_begin);
	ClassDB::bind_method(D_METHOD("get_distance_fade_begin"), &MDecal::get_distance_fade_begin);

	ClassDB::bind_method(D_METHOD("set_distance_fade_length", "distance"), &MDecal::set_distance_fade_length);
	ClassDB::bind_method(D_METHOD("get_distance_fade_length"), &MDecal::get_distance_fade_length);

	ClassDB::bind_method(D_METHOD("set_cull_mask", "mask"), &MDecal::set_cull_mask);
	ClassDB::bind_method(D_METHOD("get_cull_mask"), &MDecal::get_cull_mask);

	ADD_PROPERTY(PropertyInfo(Variant::VECTOR3, "size", PROPERTY_HINT_RANGE, "0,1024,0.001,or_greater,suffix:m"), "set_size", "get_size");

	ADD_GROUP("Textures", "texture_");
	ADD_PROPERTYI(PropertyInfo(Variant::OBJECT, "texture_albedo", PROPERTY_HINT_RESOURCE_TYPE, "Texture2D"), "set_texture", "get_texture", DecalTexture::DECAL_TEXTURE_ALBEDO);
	ADD_PROPERTYI(PropertyInfo(Variant::OBJECT, "texture_normal", PROPERTY_HINT_RESOURCE_TYPE, "Texture2D"), "set_texture", "get_texture", DecalTexture::DECAL_TEXTURE_NORMAL);
	ADD_PROPERTYI(PropertyInfo(Variant::OBJECT, "texture_orm", PROPERTY_HINT_RESOURCE_TYPE, "Texture2D"), "set_texture", "get_texture", DecalTexture::DECAL_TEXTURE_ORM);
	ADD_PROPERTYI(PropertyInfo(Variant::OBJECT, "texture_emission", PROPERTY_HINT_RESOURCE_TYPE, "Texture2D"), "set_texture", "get_texture", DecalTexture::DECAL_TEXTURE_EMISSION);

	ADD_GROUP("Parameters", "");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "emission_energy", PROPERTY_HINT_RANGE, "0,16,0.01,or_greater"), "set_emission_energy", "get_emission_energy");
	ADD_PROPERTY(PropertyInfo(Variant::COLOR, "modulate"), "set_modulate", "get_modulate");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "albedo_mix", PROPERTY_HINT_RANGE, "0,1,0.01"), "set_albedo_mix", "get_albedo_mix");
	// A Normal Fade of 1.0 causes the decal to be invisible even if fully perpendicular to a surface.
	// Due to this, limit Normal Fade to 0.999.
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "normal_fade", PROPERTY_HINT_RANGE, "0,0.999,0.001"), "set_normal_fade", "get_normal_fade");

	ADD_GROUP("Vertical Fade", "");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "upper_fade", PROPERTY_HINT_EXP_EASING, "attenuation"), "set_upper_fade", "get_upper_fade");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "lower_fade", PROPERTY_HINT_EXP_EASING, "attenuation"), "set_lower_fade", "get_lower_fade");

	ADD_GROUP("Distance Fade", "distance_fade_");
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "distance_fade_enabled"), "set_enable_distance_fade", "is_distance_fade_enabled");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "distance_fade_begin", PROPERTY_HINT_RANGE, "0.0,4096.0,0.01,or_greater,suffix:m"), "set_distance_fade_begin", "get_distance_fade_begin");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "distance_fade_length", PROPERTY_HINT_RANGE, "0.0,4096.0,0.01,or_greater,suffix:m"), "set_distance_fade_length", "get_distance_fade_length");

	ADD_GROUP("Cull Mask", "");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "cull_mask", PROPERTY_HINT_LAYERS_3D_RENDER), "set_cull_mask", "get_cull_mask");
}


MDecal::MDecal(){
	decal = RenderingServer::get_singleton()->decal_create();
}
MDecal::~MDecal(){
	ERR_FAIL_NULL(RenderingServer::get_singleton());
	RS->free_rid(decal);
}

RID MDecal::get_decal_rid() const{
	return decal;
}

void MDecal::set_size(const Vector3 &p_size){
	size = p_size.maxf(0.001);
	RS->decal_set_size(decal, size);
}

Vector3 MDecal::get_size() const {
	return size;
}

void MDecal::set_texture(DecalTexture p_type, const Ref<Texture2D> &p_texture) {
	ERR_FAIL_INDEX(p_type, DecalTexture::DECAL_TEXTURE_MAX);
	textures[p_type] = p_texture;
	RID texture_rid = p_texture.is_valid() ? p_texture->get_rid() : RID();
	RS->decal_set_texture(decal, DecalTexture(p_type), texture_rid);
}

Ref<Texture2D> MDecal::get_texture(DecalTexture p_type) const {
	ERR_FAIL_INDEX_V(p_type, DecalTexture::DECAL_TEXTURE_MAX, Ref<Texture2D>());
	return textures[p_type];
}

void MDecal::set_emission_energy(real_t p_energy) {
	emission_energy = p_energy;
	RS->decal_set_emission_energy(decal, emission_energy);
}

real_t MDecal::get_emission_energy() const {
	return emission_energy;
}

void MDecal::set_albedo_mix(real_t p_mix) {
	albedo_mix = p_mix;
	RS->decal_set_albedo_mix(decal, albedo_mix);
}

real_t MDecal::get_albedo_mix() const {
	return albedo_mix;
}

void MDecal::set_upper_fade(real_t p_fade) {
	upper_fade = MAX(p_fade, 0.0);
	RS->decal_set_fade(decal, upper_fade, lower_fade);
}

real_t MDecal::get_upper_fade() const {
	return upper_fade;
}

void MDecal::set_lower_fade(real_t p_fade) {
	lower_fade = MAX(p_fade, 0.0);
	RS->decal_set_fade(decal, upper_fade, lower_fade);
}

real_t MDecal::get_lower_fade() const {
	return lower_fade;
}

void MDecal::set_normal_fade(real_t p_fade) {
	normal_fade = p_fade;
	RS->decal_set_normal_fade(decal, normal_fade);
}

real_t MDecal::get_normal_fade() const {
	return normal_fade;
}

void MDecal::set_modulate(Color p_modulate) {
	modulate = p_modulate;
	RS->decal_set_modulate(decal, p_modulate);
}

Color MDecal::get_modulate() const {
	return modulate;
}

void MDecal::set_enable_distance_fade(bool p_enable) {
	distance_fade_enabled = p_enable;
	RS->decal_set_distance_fade(decal, distance_fade_enabled, distance_fade_begin, distance_fade_length);
	notify_property_list_changed();
}

bool MDecal::is_distance_fade_enabled() const {
	return distance_fade_enabled;
}

void MDecal::set_distance_fade_begin(real_t p_distance) {
	distance_fade_begin = p_distance;
	RS->decal_set_distance_fade(decal, distance_fade_enabled, distance_fade_begin, distance_fade_length);
}

real_t MDecal::get_distance_fade_begin() const {
	return distance_fade_begin;
}

void MDecal::set_distance_fade_length(real_t p_length) {
	distance_fade_length = p_length;
	RS->decal_set_distance_fade(decal, distance_fade_enabled, distance_fade_begin, distance_fade_length);
}

real_t MDecal::get_distance_fade_length() const {
	return distance_fade_length;
}

void MDecal::set_cull_mask(uint32_t p_layers) {
	cull_mask = p_layers;
	RS->decal_set_cull_mask(decal, cull_mask);
}

uint32_t MDecal::get_cull_mask() const {
	return cull_mask;
}

AABB MDecal::get_aabb() const {
	AABB aabb;
	aabb.position = -size / 2;
	aabb.size = size;
	return aabb;
}