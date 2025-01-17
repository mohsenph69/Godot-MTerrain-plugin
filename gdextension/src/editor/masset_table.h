#ifndef __MASSETTABLE__
#define __MASSETTABLE__


#define MAX_MESH_LOD 10
#define MAX_MATERIAL_SET_ID 126

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/templates/vector.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/classes/texture2d.hpp>

#include <godot_cpp/classes/mesh_instance3d.hpp>

#include "../hlod/mhlod.h"

using namespace godot;

#define M_TAG_ELEMENT_COUNT 4 // change this to increase tags
#define M_MAX_TAG M_TAG_ELEMENT_COUNT*64 // don't touch 64! it is always 64


class MAssetTable : public Resource {
    GDCLASS(MAssetTable,Resource);

    protected:
    static void _bind_methods();
    public:
    enum ItemType {NONE,MESH,COLLISION};

    private:
    int64_t last_mesh_id = 1; // should not exist and increase by each adding (0 is invalid mesh ID)
    Dictionary import_info;

    struct Tag
    {
        int64_t tag[M_TAG_ELEMENT_COUNT];
        Tag();
        Tag(const PackedInt64Array& input);
        ~Tag()=default;
        bool has_tag(int id) const;
        bool has_match(const Tag& other) const;
        bool has_all(const Tag& other) const;
        void add_tag(int id);
        void remove_tag(int id);
        void clear();
        bool operator==(const Tag& other) const;
        Tag operator&(const Tag& other) const;
        Tag operator|(const Tag& other) const;
        Tag operator^(const Tag& other) const;
        Tag operator~() const;
    };

    struct Socket
    {
        String name;
        Vector<Transform3D> slots;
        Vector<int32_t> slot_type;
        Vector<bool> is_input;
    };
    
    Vector<Socket> sockets;

    struct CollisionShape
    {
        /* data */
    };
    

    struct Collection {
        int32_t mesh_id=-1;
        int32_t glb_id = -1;
        double thumbnail_creation_time = -1.0;
        Ref<Texture2D> cached_thumbnail;
        Vector<CollisionShape> collision_shapes;
        Vector<Transform3D> collision_shapes_transforms;
        PackedInt32Array sub_collections;
        Vector<Transform3D> sub_collections_transforms;

        //Vector<int32_t> variation; // [12,13,343,65,36]
        int sockets_id = 6;
        void set_glb_id(int32_t input);
        int32_t get_glb_id() const;
        void clear();
        void set_save_data(const PackedByteArray& data);
        PackedByteArray get_save_data() const;
    };

    Vector<Collection> collections;
    PackedStringArray collections_names;
    Vector<Tag> collections_tags;
    Vector<int> free_collections;



    PackedStringArray tag_names;
    PackedStringArray group_names;
    Vector<Tag> groups;

    private:
    static int32_t last_free_mesh_id; // should be updated before each import
    void _increase_collection_buffer_size(int q);
    int _get_free_collection_index();
    static const char* asset_table_path;
    static const char* asset_editor_root_dir;
    static const char* editor_baker_scenes_dir;
    static const char* asset_thumbnails_dir;
    static const char* hlod_res_dir;
    static MAssetTable* asset_table_singelton;

    public:
    static void set_singleton(Ref<MAssetTable> input);
    static Ref<MAssetTable> get_singleton();
    static void make_assets_dir();
    static void save();
    static String get_asset_table_path();
    static String get_asset_editor_root_dir();
    static String get_editor_baker_scenes_dir();
    static String get_asset_thumbnails_dir();
    static String get_asset_thumbnails_path(int collection_id);
    static String get_material_thumbnails_path(int material_id);
    static String get_hlod_res_dir();
    bool has_collection(int id) const;
    void remove_collection(int id);

    MAssetTable();
    ~MAssetTable();
    void init_asset_table();
    int tag_add(const String& name);
    void tag_set_name(int tag_id,const String& name);
    String tag_get_name(int tag_id) const;
    Dictionary tag_get_names() const;
    int tag_get_id(const String& tag_name);
    PackedInt32Array tag_get_collections(int tag_id) const;
    PackedInt32Array tag_get_collections_in_collections(const PackedInt32Array& search_collections,int tag_id) const;
    PackedInt32Array tags_get_collections_any(const PackedInt32Array& tags) const;
    PackedInt32Array tags_get_collections_all(const PackedInt32Array& tags) const;

    PackedInt32Array tags_get_collections_in_collections_any(const PackedInt32Array& search_collections,const PackedInt32Array& tags) const;
    PackedInt32Array tags_get_collections_in_collections_all(const PackedInt32Array& search_collections,const PackedInt32Array& tags) const;

    PackedInt32Array tag_get_tagless_collections() const;
    PackedInt32Array tag_names_begin_with(const String& prefix);

    static void update_last_free_mesh_id();
    static int mesh_item_get_max_lod();
    static int32_t get_last_free_mesh_id_and_increase();
    static int32_t mesh_item_get_first_lod(int mesh_id);
    static int32_t mesh_item_get_stop_lod(int mesh_id);
    static PackedInt32Array mesh_item_ids_no_replace(int mesh_id);
    static TypedArray<MMesh> mesh_item_meshes_no_replace(int mesh_id);
    static PackedInt32Array mesh_item_ids(int mesh_id);
    static TypedArray<MMesh> mesh_item_meshes(int mesh_id);
    static bool mesh_item_is_valid(int mesh_id);

    int collection_create(String _name);
    void collection_set_glb_id(int collection_id,int32_t glb_id);
    int32_t collection_get_glb_id(int collection_id) const;
    void collection_set_cache_thumbnail(int collection_id,Ref<Texture2D> tex,double creation_time);
    double collection_get_thumbnail_creation_time(int collection_id) const;
    Ref<Texture2D> collection_get_cache_thumbnail(int collection_id) const;
    void collection_set_mesh_id(int collection_id,int32_t mesh_id);
    int32_t collection_get_mesh_id(int collection_id);
    void collection_clear(int collection_id);
    void collection_remove(int collection_id);
    PackedInt32Array collection_get_list() const;
    void collection_add_tag(int collection_id,int tag);
    bool collection_add_sub_collection(int collection_id,int sub_collection_id,const Transform3D& transform);
    void collection_remove_sub_collection(int collection_id,int sub_collection_id);
    void collection_remove_all_sub_collection(int collection_id);
    PackedInt32Array collection_get_sub_collections(int collection_id) const;
    Array collection_get_sub_collections_transforms(int collection_id) const;
    Array collection_get_sub_collections_transform(int collection_id,int sub_collection_id) const;
    void collection_remove_tag(int collection_id,int tag);
    void collection_update_name(int collection_id,String name);
    String collection_get_name(int collection_id) const;
    int collection_get_id(const String& name) const;
    PackedInt32Array collection_get_tags(int collection_id) const;
    PackedInt32Array collection_names_begin_with(const String& prefix) const;
    Vector<Pair<int,Transform3D>> collection_get_sub_collection_id_transform(int collection_id);

    bool group_exist(const String& gname) const;
    bool group_create(const String& name);
    bool group_rename(const String& gname,const String& new_name);
    void group_remove(const String& gname);
    PackedStringArray group_get_list() const;
    int group_count() const;
    void group_add_tag(const String& gname,int tag);
    void group_remove_tag(const String& gname,int tag);
    PackedInt32Array group_get_tags(const String& gname) const;
    PackedInt32Array groups_get_collections_any(const String& gname) const;
    PackedInt32Array groups_get_collections_all(const String& gname) const;
    Dictionary group_get_collections_with_tags(const String& gname) const;

    void clear_table();
    void set_data(const Dictionary& data);
    Dictionary get_data();
    void _notification(int32_t what);

    void test(Dictionary d);

    void set_import_info(const Dictionary& input);
    Dictionary get_import_info();

    // Only for debug
    static void reset(bool hard);

    void debug_test();
};
VARIANT_ENUM_CAST(MAssetTable::ItemType);
#endif