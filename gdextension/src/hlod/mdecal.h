#ifndef __MDECAL__
#define __MDECAL__

#include <godot_cpp/classes/mesh_instance3d.hpp>
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/classes/texture2d.hpp>
#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/classes/visual_instance3d.hpp>
using namespace godot;
#define RS RenderingServer::get_singleton()

class MDecal : public Resource {
	using DecalTexture = RenderingServer::DecalTexture;
    GDCLASS(MDecal,Resource);
    protected:
    static void _bind_methods();
    private:
	RID decal;
	// Vector3 size = Vector3(2, 2, 2); -> size is fixed with this val
	Ref<Texture2D> textures[DecalTexture::DECAL_TEXTURE_MAX];
	real_t emission_energy = 1.0;
	real_t albedo_mix = 1.0;
	Color modulate = Color(1, 1, 1, 1);
	uint32_t cull_mask = (1 << 20) - 1;
	real_t normal_fade = 0.0;
	real_t upper_fade = 0.3;
	real_t lower_fade = 0.3;
	bool distance_fade_enabled = false;
	real_t distance_fade_begin = 40.0;
	real_t distance_fade_length = 10.0;
	
    public:
    MDecal();
	~MDecal();

	RID get_decal_rid() const;

	void set_texture(DecalTexture p_type, const Ref<Texture2D> &p_texture);
	Ref<Texture2D> get_texture(DecalTexture p_type) const;

	void set_emission_energy(real_t p_energy);
	real_t get_emission_energy() const;

	void set_albedo_mix(real_t p_mix);
	real_t get_albedo_mix() const;

	void set_modulate(Color p_modulate);
	Color get_modulate() const;
	
	void set_upper_fade(real_t p_energy);
	real_t get_upper_fade() const;

	void set_lower_fade(real_t p_fade);
	real_t get_lower_fade() const;

	void set_normal_fade(real_t p_fade);
	real_t get_normal_fade() const;

	void set_enable_distance_fade(bool p_enable);
	bool is_distance_fade_enabled() const;

	void set_distance_fade_begin(real_t p_distance);
	real_t get_distance_fade_begin() const;

	void set_distance_fade_length(real_t p_length);
	real_t get_distance_fade_length() const;

	void set_cull_mask(uint32_t p_layers);
	uint32_t get_cull_mask() const;

	AABB get_aabb() const;
};
#endif