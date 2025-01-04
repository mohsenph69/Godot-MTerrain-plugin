#ifndef __MASSETTABLE__
#define __MASSETTABLE__

#define MAX_MATERIAL_SET_ID 126

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/templates/vector.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/variant/dictionary.hpp>

#include <godot_cpp/classes/mesh_instance3d.hpp>

#include "../hlod/mhlod.h"
#include "../util/mtrie_array.h"

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
    struct MeshHasher
    {
        static _FORCE_INLINE_ uint32_t hash(Ref<MMesh> input_mesh){
            ERR_FAIL_COND_V(input_mesh.is_null(),0);
            int suf_count = input_mesh->get_surface_count();
            Array suf_info;
            for(int i=0; i < suf_count; i++){
                suf_info.push_back(input_mesh->surface_get_arrays(i));
            }
            uint32_t hash = hash_one_uint64(suf_info.hash());
            return hash;
        }
    };
    struct MeshHasherComparator
    {
        static bool compare(const Ref<MMesh> &p_lhs, const Ref<MMesh> &p_rhs) {
            if(p_lhs.is_null() || p_rhs.is_null()){
                return false;
            }
            Array lsuf_info;
            Array rsuf_info;
            {
                int suf_count = p_lhs->get_surface_count();
                for(int i=0; i < suf_count; i++){
                    lsuf_info.push_back(p_lhs->surface_get_arrays(i));
                }
            }
            {
                int suf_count = p_rhs->get_surface_count();
                for(int i=0; i < suf_count; i++){
                    rsuf_info.push_back(p_rhs->surface_get_arrays(i));
                }
            }
            return lsuf_info == rsuf_info;
        }
    };

    int64_t last_mesh_id = 1; // should not exist and increase by each adding (0 is invalid mesh ID)
    HashMap<Ref<MMesh>,int64_t,MAssetTable::MeshHasher,MAssetTable::MeshHasherComparator> mesh_hashes;
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

    struct MeshItem {
        // path is a int64_t (path hash) with a int64_t (path index) which the file name is like hash_index.res
        // in case of index = 0; file_name is hash.res
        int8_t material_set_id = -1;
        PackedInt64Array path; // Contain array of mesh path follow by array of material_path
        // Shadow setting follow by gi_mode setting
        bool insert_data(const PackedInt64Array& mesh,int _material_set_id);                                          
        int get_lod_count() const;
        bool has_mesh(int64_t mesh_id) const;
        bool has_material(int32_t m) const;
        int64_t hash();
        void clear();
        Dictionary get_creation_data() const;
        void set_save_data(const PackedByteArray& data);
        PackedByteArray get_save_data() const;
        bool operator==(const MeshItem& other) const;
    };

    Vector<MeshItem> mesh_items;
    Vector<int64_t> mesh_items_hashes;
    Vector<int32_t> free_mesh_items;

    struct Socket
    {
        String name;
        Vector<Transform3D> slots;
        Vector<int32_t> slot_type;
        Vector<bool> is_input;
    };
    
    Vector<Socket> sockets;

    struct Collection {
        Vector<Pair<ItemType,int>> items;
        Vector<Transform3D> transforms;
        PackedInt32Array sub_collections;
        Vector<Transform3D> sub_collections_transforms;
        //Vector<int32_t> variation; // [12,13,343,65,36]
        int sockets_id = 6;
        void clear();
        void set_save_data(const PackedByteArray& data);
        PackedByteArray get_save_data() const;
    };

    Vector<Collection> collections;
    Ref<MTrieArray> collections_names;
    Vector<Tag> collections_tags;
    Vector<int> free_collections;



    Ref<MTrieArray> tag_names;
    Ref<MTrieArray> group_names;
    Vector<Tag> groups;

    private:
    void _increase_mesh_item_buffer_size(int q);
    int _get_free_mesh_item_index();
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
    static String get_hlod_res_dir();
    bool has_mesh_item(int id) const;
    bool has_collection(int id) const;
    void remove_mesh_item(int id);
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
    int mesh_item_add(const PackedInt64Array& mesh,int material_set_id);
    void mesh_item_update(int mesh_id,const PackedInt64Array& mesh,int material_set_id);
    void mesh_item_remove(int mesh_id);
    int mesh_item_find_by_info(const PackedInt64Array& mesh,int material) const;
    PackedInt32Array mesh_item_find_collections(int mesh_id) const;
    PackedInt32Array mesh_item_find_collections_with_tag(int mesh_id,int tag_id) const;
    PackedInt64Array mesh_item_get_mesh(int mesh_id) const;
    int mesh_item_get_material(int mesh_id) const;

    Dictionary mesh_item_get_info(int mesh_id);
    PackedInt32Array mesh_item_get_list() const;
    int collection_create(String _name);
    bool collection_rename(int collection_id,const String& new_name);
    void collection_add_item(int collection_id,ItemType type, int item_id,const Transform3D& transform);
    void collection_clear(int collection_id);
    void collection_remove(int collection_id);
    void collection_remove_item(int collection_id,ItemType type, int item_id);
    void collection_remove_all_items(int collection_id);
    PackedInt32Array collection_get_list() const;
    Transform3D collection_get_item_transform(int collection_id,ItemType type, int item_id) const;
    void collection_update_item_transform(int collection_id,ItemType type, int item_id,const Transform3D& transform);
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
    Vector<Pair<int,Transform3D>> collection_get_mesh_items_id_transform(int collection_id);
    Array collection_get_mesh_items_info(int collection_id) const;
    PackedInt32Array collection_get_mesh_items_ids(int collection_id) const;

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

    void set_data(const Dictionary& data);
    Dictionary get_data();
    void _notification(int32_t what);

    void test(Dictionary d);

    void set_import_info(const Dictionary& input);
    Dictionary get_import_info();

    int mesh_get_id(Ref<MMesh> mesh);
    String mesh_get_path(Ref<MMesh> mesh);
    PackedInt32Array mesh_get_mesh_items_users(int64_t mesh_id) const;
    bool mesh_exist(Ref<MMesh> mesh);
    bool mesh_update(Ref<MMesh> old_mesh,Ref<MMesh> new_mesh);
    void initialize_mesh_hashes();
    int mesh_add(Ref<MMesh> mesh);
    void mesh_remove(int mesh_id);

    // Only for debug
    static void reset(bool hard);

    void debug_test();
};
VARIANT_ENUM_CAST(MAssetTable::ItemType);
#endif