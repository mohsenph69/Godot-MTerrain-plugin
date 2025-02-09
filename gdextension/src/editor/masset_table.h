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
    enum ItemType : uint8_t {NONE=0,MESH=2,COLLISION=4,PACKEDSCENE=8,DECAL=16,HLOD=32};
    // Enum numbers should match CollisionType in mhold_item.h
    enum CollisionType : uint8_t {UNDEF=0,SHPERE=1,CYLINDER=2,CAPSULE=3,BOX=4};

    private:
    int64_t last_item_id = 1; // should not exist and increase by each adding (0 is invalid mesh ID)
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
        CollisionType type = CollisionType::UNDEF;
        float param_1;
        float param_2;
        float param_3;
    };

    struct SubCollectionData{
        PackedInt32Array sub_collections;
        Vector<Transform3D> sub_collections_transforms;
    };
    public:
    struct CollisionData{
        Vector<CollisionShape> collision_shapes;
        Vector<Transform3D> collision_shapes_transforms;
    };

    struct Collection {
        ItemType type = NONE;
        int8_t colcutoff = -1;
        int16_t physics_name = -1; // is id in PackedStringArray physics_names (-1 is default)
        uint32_t modify_time = 0;
        int32_t item_id=-1;
        int32_t glb_id = -1;
    };
    
    struct CollectionIdentifier {
        String name;
        int32_t glb_id = -1;
        CollectionIdentifier()=default;
        inline CollectionIdentifier(int glb_id,const String& name):glb_id(glb_id),name(name){}

        inline bool is_null() const{
            return glb_id == -1 || name.is_empty();
        }
        
        _FORCE_INLINE_ bool operator==(const CollectionIdentifier& other){
            return glb_id==other.glb_id && name==other.name;
        }
    };

    private:
    Vector<Collection> collections;
    VMap<int32_t,SubCollectionData> sub_collections;
    VMap<int32_t,CollisionData> collisions_data;
    PackedStringArray physics_names;
    PackedStringArray collections_names;
    Vector<Tag> collections_tags;
    Vector<int> free_collections;



    PackedStringArray tag_names;
    PackedStringArray group_names;
    Vector<Tag> groups;

    static int32_t last_free_item_id; // should be updated before each import
    void _increase_collection_buffer_size(int q);
    int _get_free_collection_index();
    static const char* import_info_path;
    static const char* asset_table_path;
    static const char* asset_editor_root_dir;
    static const char* editor_baker_scenes_dir;
    static const char* asset_thumbnails_dir;
    static const char* thumbnails_dir;
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
    static String get_thumbnails_dir();
    static String get_asset_thumbnails_path(int collection_id);
    static String get_material_thumbnails_path(int material_id);
    static String get_hlod_res_dir();
    bool has_collection(int id) const;

    MAssetTable();
    ~MAssetTable();
    void init_asset_table();
    int tag_add(const String& name);
    void tag_set_name(int tag_id,const String& name);
    String tag_get_name(int tag_id) const;
    Dictionary tag_get_names() const;
    int tag_get_id(const String& tag_name);
    PackedInt32Array tag_get_collections(int tag_id) const;
    PackedInt32Array tags_get_collections_any(const PackedInt32Array& search_collections,const PackedInt32Array& tags,const PackedInt32Array& exclude_tags) const;
    PackedInt32Array tags_get_collections_all(const PackedInt32Array& search_collections,const PackedInt32Array& tags,const PackedInt32Array& exclude_tags) const;
    PackedInt32Array tag_get_tagless_collections() const;

    static void update_last_free_mesh_id();
    static int mesh_item_get_max_lod();
    static int32_t get_last_free_mesh_id_and_increase();
    static int32_t mesh_item_get_first_lod(int item_id);
    static int32_t mesh_item_get_stop_lod(int item_id);
    static PackedInt32Array mesh_item_ids_no_replace(int item_id);
    static TypedArray<MMesh> mesh_item_meshes_no_replace(int item_id);
    static PackedInt32Array mesh_item_ids(int item_id);
    static TypedArray<MMesh> mesh_item_meshes(int item_id);
    static bool mesh_item_is_valid(int item_id);

    static int32_t get_last_free_mesh_join_id();
    static int32_t mesh_join_get_first_lod(int item_id);
    static int32_t mesh_join_get_stop_lod(int item_id);
    static PackedInt32Array mesh_join_ids_no_replace(int item_id);
    static TypedArray<MMesh> mesh_join_meshes_no_replace(int item_id);
    static PackedInt32Array mesh_join_ids(int item_id);
    static TypedArray<MMesh> mesh_join_meshes(int item_id);
    static bool mesh_join_is_valid(int item_id);
    static int32_t mesh_join_start_lod(int item_id);

    static int32_t get_last_id_in_dir(const String dir_path);
    static int32_t get_last_free_decal_id();
    static int32_t get_last_free_packed_scene_id();
    static int32_t get_last_free_hlod_id(int32_t last_hlod_id=-1,const String& baker_scene_path="");

    CollectionIdentifier collection_get_identifier(int collection_id) const;
    int32_t collection_get_id_by_identifier(const CollectionIdentifier& identifier) const;

    CollisionData collection_get_collision_data(int collection_id) const;

    int physics_id_get_add(const String& physics_name);

    int collection_create(const String& _name,int32_t item_id,ItemType type,int32_t glb_id);
    void collection_update_modify_time(int collection_id);
    int64_t collection_get_modify_time(int collection_id) const;
    void collection_set_physics_setting(int collection_id,const String& physics_name);
    String collection_get_physics_setting(int collection_id) const;
    void collection_set_colcutoff(int collection_id,int value);
    int8_t collection_get_colcutoff(int collection_id) const;
    void collection_clear_unused_physics_settings();
    ItemType collection_get_type(int collection_id) const;
    int32_t collection_get_glb_id(int collection_id) const;
    int32_t collection_find_with_item_type_item_id(ItemType type, int32_t item_id) const;
    int32_t collection_find_with_glb_id_collection_name(int32_t glb_id,const String collection_name) const;
    int32_t collection_get_item_id(int collection_id);
    void collection_clear_sub_and_col(int id);
    void collection_remove(int id);
    PackedInt32Array collection_get_list() const;
    PackedInt32Array collections_get_by_type(int item_types) const;
    void collection_add_tag(int collection_id,int tag);
    bool collection_add_sub_collection(int collection_id,int sub_collection_id,const Transform3D& transform);
    void collection_add_collision(int collection_id,CollisionType col_type,const Transform3D& col_transform,const Transform3D& obj_transform);
    PackedInt32Array collection_get_sub_collections(int collection_id) const;
    int collection_get_collision_count(int collection_id) const;
    void collection_remove_tag(int collection_id,int tag);
    void collection_set_name(int collection_id,ItemType expected_type,const String& new_name);
    String collection_get_name(int collection_id) const;
    int collection_get_id(const String& name) const;
    PackedInt32Array collection_get_tags(int collection_id) const;
    Vector<Pair<int,Transform3D>> collection_get_sub_collection_id_transform(int collection_id) const;

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
    void set_collection_data(int collection_id,const PackedByteArray& data);
    PackedByteArray get_collection_data(int collection_id) const;
    void set_data(const Dictionary& data);
    Dictionary get_data();
    void _notification(int32_t what);

    void test(Dictionary d);

    void clear_import_info_cache();
    void save_import_info();
    void load_import_info();
    void set_import_info(const Dictionary& input);
    Dictionary get_import_info();

    void auto_asset_update_from_dir(ItemType type);

    // Only for debug
    static void reset(bool hard);

    void debug_test();
};
VARIANT_ENUM_CAST(MAssetTable::ItemType);
VARIANT_ENUM_CAST(MAssetTable::CollisionType);
#endif