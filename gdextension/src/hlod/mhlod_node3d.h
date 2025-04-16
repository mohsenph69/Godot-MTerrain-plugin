#ifndef __MHLODNODE3D__
#define __MHLODNODE3D__

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/core/gdvirtual.gen.inc>

#include "mhlod_scene.h"
#include "../util/lru_cache.h"

using namespace godot;


class MHlodNode3D : public Node3D {
    GDCLASS(MHlodNode3D,Node3D);
    friend MHlodScene;
    
    protected:
    static void _bind_methods();
    private:
    static MLRUCache<int64_t,Variant> state_data;
    bool is_inside_hlod_scene = false;
    bool hlod_remove_me = false; // should be set when removed by HLODSCENE, realy important otherwise you will see the most wierd bug in your life
    int8_t lod = -1;
    int32_t args[M_PACKED_SCENE_ARG_COUNT] = {0};
    MHlodScene::GlobalItemID bind_items[M_PACKED_SCENE_BIND_COUNT];
    MHlodScene::GlobalItemID global_id;
    MHlodScene::Proc* proc = nullptr;

    public:
    MHlodNode3D();
    ~MHlodNode3D();
    void _notify_update_lod(int _lod); // only called by MHlodScene
    void _notify_before_remove();
    int get_current_lod() const;
    void set_arg(int idx,int32_t val);
    int32_t get_arg(int idx) const;
    int64_t get_global_id() const;

    //Bind Items
    int64_t bind_item_get_global_id(int idx) const;
    Transform3D bind_item_get_transform(int idx) const;
    void bind_item_set_transform(int idx, const Transform3D& transform);
    bool bind_item_get_disabled(int idx) const;
    void bind_item_set_disabled(int idx,bool disabled);

    // Sate Data
    static int64_t state_data_get_cache_size();
    static String state_data_get_prop_name();
    void state_data_set(const Variant& data);
    const Variant& state_data_get();
    bool state_data_exist();

    void _set_args(const PackedInt32Array& input);
    PackedInt32Array _get_args();


    void _notification(int32_t what);
    void _get_property_list(List<PropertyInfo> *p_list) const;
    bool _get(const StringName &p_name, Variant &r_ret) const;
    bool _set(const StringName &p_name, const Variant &p_value);
    PackedStringArray _get_configuration_warnings() const;


    GDVIRTUAL1(_update_lod,int);
    GDVIRTUAL0(_before_remove);
};
#endif