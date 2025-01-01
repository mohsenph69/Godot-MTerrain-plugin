#ifndef __MMATERAILTABLE__
#define __MMATERAILTABLE__

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/classes/material.hpp>
#include <godot_cpp/templates/hash_map.hpp>


using namespace godot;

class MHlod;

class MMaterialTable : public Resource {
    GDCLASS(MMaterialTable,Resource);
    friend MHlod;
    private:
    HashMap<int32_t,String> paths;
    protected:
    static void _bind_methods();

    private:
    static Ref<MMaterialTable> material_table_singelton;


    public:
    static Ref<MMaterialTable> get_singleton();
    static void save();
    static String get_material_table_path();
    int add_material(const String& _path);
    void remove_mateiral(int id);
    int find_material_id(const String& _path) const;
    void set_table(const Dictionary& info);
    Dictionary get_table() const;
};
#endif