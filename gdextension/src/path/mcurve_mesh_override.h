#ifndef __MCURVE_OVERRIDE
#define __MCURVE_OVERRIDE


#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/templates/hash_map.hpp>


using namespace godot;

/*
    -1 -> means default mesh or material, whatever is that
    -2 -> means the mesh should be removed
*/

class MCurveMeshOverride : public Resource {
    GDCLASS(MCurveMeshOverride,Resource);
    protected:
    static void _bind_methods();
    public:
    struct Override
    {
        int material = -1;
        int mesh = -1;
        Override()=default;
        Override(int _material,int _mesh){
            material = _material;
            mesh = _mesh;
        }
    };
    

    private:
    HashMap<int64_t,Override> data;

    public:
    void set_mesh_override(int64_t id,int mesh);
    void set_material_override(int64_t id,int material);
    int get_mesh_override(int64_t id);
    int get_material_override(int64_t id);
    Override get_override(int64_t id);
    void clear_mesh_override(int64_t id);
    void clear_material_override(int64_t id);
    void clear_override(int64_t id);
    void clear_override_no_signal(int64_t id);
    void clear();

    /// These are really usefull when we want to backup override data in run-time somwhere
    /// for example in split connection or undo redo stuff, or copy paste overrides
    void set_override_entry(int64_t id,PackedByteArray data_input);
    PackedByteArray get_override_entry(int64_t id) const;

    void set_data(const PackedByteArray& input);
    PackedByteArray get_data() const;
    
};
#endif