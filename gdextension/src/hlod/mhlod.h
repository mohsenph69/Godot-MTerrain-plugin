#ifndef __MHLOD__
#define __MHLOD__

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/templates/vector.hpp>
#include <godot_cpp/templates/vset.hpp>
#include <godot_cpp/templates/hash_set.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <godot_cpp/classes/resource_loader.hpp>
#include "mhlod_item.h"
#include "../hlod/mmaterial_table.h"

using namespace godot;

class MHlod : public Resource{
    GDCLASS(MHlod, Resource);

    protected:
    static void _bind_methods();

    public:
    enum Type : uint8_t {NONE,MESH,COLLISION};
    struct Item
    {
        friend MHlod;
        Type type = NONE; // 0
        int8_t lod = -1; // 1
        uint16_t item_layers = 0;
        int32_t transform_index = -1; // Same as unique id for each Item with different LOD
        int32_t user_count = 0;
        union {
            MHLodItemMesh mesh;
            MHLodItemCollision collision;
        };
        void create();
        void copy(const Item& other);
        void clear();
        public:
        Item();
        Item(Type _type);
        ~Item();
        Item(const Item& other);
        Item& operator=(const Item& other);
        
        void load();
        void unload();
        void add_user();
        void remove_user();

        void set_data(const Dictionary& d);
        Dictionary get_data() const;
    };

    /* Item List structure
        [itemA_lod0,itemA_lod1,itemA_lod2, .... , itemB_lod0,itemB_lod1,itemB_lod2]
        the start index (in this case index of itemA_lod0) is the id of that item
        one LOD can be droped if it is a duplicate Base on this if item LOD does not exist we pick the last existing one
        Only two neghbor similar lod can be detected
    */
    static const char* asset_root_dir;
    static const char* mesh_root_dir;
    static const char* material_table_path;
    static const char* physics_settings_dir;
    static Ref<MMaterialTable> material_table; // this is problematic specially in windows should be changed later
    int join_at_lod = -1;
    String baker_path;
    AABB aabb;
    Vector<Item> item_list;
    Vector<Transform3D> transforms;
    Vector<VSet<int32_t>> lods;
    Vector<Transform3D> sub_hlods_transforms;
    Vector<Ref<MHlod>> sub_hlods;
    Vector<uint16_t> sub_hlods_scene_layers;

    void _get_sub_hlod_size_rec(int& size);
    public:
    static Ref<Material> get_material_from_table(int material_id);
    static String get_mesh_root_dir();
    static String get_material_table_path();
    static String get_physics_settings_dir();
    static String get_mesh_path(int64_t mesh_id);
    void set_join_at_lod(int input);
    int get_join_at_lod();
    int get_sub_hlod_size_rec();
    void add_sub_hlod(const Transform3D& transform,Ref<MHlod> hlod,uint16_t scene_layers);
    int add_mesh_item(const Transform3D& transform,const PackedInt64Array& mesh,int material,const PackedByteArray& shadow_settings,const PackedByteArray& gi_modes,int32_t render_layers,int32_t hlod_layers);
    Dictionary get_mesh_item(int item_id);
    int add_collision_item(const Transform3D& transform,const PackedStringArray& shape_path);
    PackedInt32Array get_mesh_items_ids() const;
    int get_last_lod_with_mesh() const;

    void insert_item_in_lod_table(int item_id,int lod);
    Array get_lod_table();
    void clear();

    void set_baker_path(const String& input);
    String get_baker_path();

    /// Physics
    int add_shape_sphere(const Transform3D& _transform,float radius);



    void start_test(){
        if(false){
            int id = add_shape_sphere(Transform3D(),2.5);
            int id2 = add_shape_sphere(Transform3D(),6.5);
            Item& item = item_list.ptrw()[id];
            item.collision.get_shape();
            
            MHLodItemCollision::Param param;
            HashSet<uint32_t> hashes;
            int total = 0;
            int hash_collision = 0;

            for(int i=0; i < 100; i++){
                for(int j=0; j < 100; j++){
                    for(int k=0; k < 100; k++){
                        total++;
                        param.param_1 += i * 0.05;
                        param.param_2 += j * 0.05;
                        param.param_3 += k * 0.05;
                        uint32_t hash = 0;
                        //uint32_t hash = MHLodItemCollision::Param::hash(param);
                        if(hashes.has(hash)){
                            hash_collision++;
                        } else {
                            hashes.insert(hash);
                        }
                    }
                }
            }
            UtilityFunctions::print("Total ",total, " Hash Collistion ",hash_collision);
            //UtilityFunctions::print("Hash collission percentage : ",());
        }
        UtilityFunctions::print("so of MHLodItemMesh  ",sizeof(MHLodItemMesh));
        UtilityFunctions::print("so of MHLodItemCollision  ",sizeof(MHLodItemCollision));
        UtilityFunctions::print("so of MHLodItemCollisionParam  ",sizeof(MHLodItemCollision::Param));
        UtilityFunctions::print("so of Item  ",sizeof(Item));
    }

    void _set_data(const Dictionary& data);
    Dictionary _get_data() const;
};
#endif