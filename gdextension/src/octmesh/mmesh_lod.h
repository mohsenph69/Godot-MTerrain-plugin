#ifndef _MMESH_LOD
#define _MMESH_LOD


#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/classes/mesh.hpp>

using namespace godot;


class MMeshLod : public Resource {
    GDCLASS(MMeshLod,Resource);

    protected:
    static void _bind_methods();

    private:
    TypedArray<Mesh> meshes;


    public:
    MMeshLod();
    ~MMeshLod();
    RID get_mesh_rid(int8_t lod);
    RID get_mesh_rid_last(int8_t lod);
    Ref<Mesh> get_mesh(int8_t lod);
    Ref<Mesh> get_mesh_last(int8_t lod);
    Ref<Mesh> get_last_valid_mesh();
    void set_meshes(TypedArray<Mesh> input);
    TypedArray<Mesh> get_meshes() const;

	
	bool _set(const StringName &p_name, const Variant &p_value);
	bool _get(const StringName &p_name, Variant &r_ret) const;
	void _get_property_list(List<PropertyInfo> *p_list) const;
    bool _property_can_revert(const StringName &p_name) const;
};
#endif