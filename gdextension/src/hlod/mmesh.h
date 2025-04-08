#ifndef __MMESH___
#define __MMESH___

#define MPATH_DELIMTER 59

#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/classes/array_mesh.hpp>
#include <godot_cpp/classes/material.hpp>

#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

/*
	If mesh come with only one material set then
	the material will be applied on top of the mesh automaticly
*/

class MMesh : public Mesh {
    GDCLASS(MMesh,Mesh);
	protected:
	static void _bind_methods();

	RID mesh;
	AABB aabb;
	// An array of materials ovverides

	private:
	void _create_if_not_exist();
	struct MaterialSet
	{
		int type = 0;
		int user_count = 0;
		// Material Sets seperated with ";" For less memory use it is converted to assci(PackedByteArray)
		PackedByteArray surface_materials_paths;
		// in case user_count > 0 we have a cache
		Vector<Ref<Material>> materials_cache;
		

		MaterialSet() = default;
		MaterialSet(int surface_count);
		MaterialSet(const PackedStringArray& _material_paths);
		MaterialSet(const PackedByteArray& _material_paths);
		~MaterialSet();
		//private:
		PackedStringArray get_surface_materials_paths() const;
		void set_surface_materials_paths(const PackedStringArray& paths);
		void clear();

		public:
		inline bool has_cache() const;
		inline int get_surface_count() const;
		// should be called only in MainLoop, only for editor
		void set_material(int surface_index,Ref<Material> material);
		void set_material_no_error(int surface_index,Ref<Material> material);
		Ref<Material> get_material_no_user(int surface_index) const;
		// should be called only in MHlodScene update thread
		void get_materials_add_user(Vector<RID>& materials_rid);
		void get_materials(Vector<RID>& materials_rid);
		void update_cache();
		void add_user();
		void remove_user();
	};
	// Surface names seperated by ;
	PackedByteArray surfaces_names;
	Vector<MaterialSet> materials_set;

	
	void surfaces_set_names(const PackedStringArray& _surfaces_names);

	public:
	MMesh();
	~MMesh();

	PackedStringArray surfaces_get_names() const;
	void surface_set_name(int surface_index,const String& new_name);
	String surface_get_name(int surface_index) const;
	Array surface_get_arrays(int surface_index) const;

	RID get_mesh_rid();
	void create_from_mesh(Ref<Mesh> input);
	Ref<ArrayMesh> get_mesh() const;

	int get_surface_count() const;
	AABB get_aabb() const;
	int material_set_get_count() const;
	PackedStringArray material_set_get(int set_id) const;
	String material_get(int set_id,int surface_index)const;
	void surface_set_material(int set_id,int surface_index,const String& path);
	int add_material_set();
	void material_set_resize(int size);
	void clear_material_set(int set_id);
	bool has_material_override();
	void update_material_override();

	void get_materials_add_user(int material_set_id,Vector<RID>& materials_rid);
	void get_materials(int material_set_id,Vector<RID>& materials_rid);
	void add_user(int material_set_id);
	void remove_user(int material_set_id);

	bool is_same_mesh(Ref<MMesh> other);

	RID _get_rid() const override;
	// First element in array is material set
	void _set_surfaces(Array _surfaces);
	Array _get_surfaces() const;

	bool _set(const StringName &p_name, const Variant &p_value);
	bool _get(const StringName &p_name, Variant& r_ret) const;
	void _get_property_list(List<PropertyInfo> *p_list) const;
	String _to_string();

	void debug_test();
};
#endif