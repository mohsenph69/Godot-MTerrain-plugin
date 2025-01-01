#ifndef __MTRIE__
#define __MTRIE__

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/templates/vset.hpp>
#include <godot_cpp/templates/vmap.hpp>

using namespace godot;


// only lower case ascii is allowed

#define MTRIE_MAX_CHAR 26
#define MTRIE_START_INDEX 97 // Start index which is lower case a

class MTrie : public RefCounted {
    GDCLASS(MTrie,RefCounted);

    protected:
    static void _bind_methods();

    private:
    struct Nd
    {
        int id = -1;
        VMap<uint8_t,Nd> nodes;
        Nd();
        ~Nd();
        bool has_children();
    };

    Nd root;
    bool _remove_rec(Nd* node,const PackedByteArray& input, bool &removed,int current_index=0);
    void _add_ids_rec(const Nd* node,PackedInt32Array& ids) const;
    public:
    bool insert_b(const PackedByteArray& input,int id,bool unique);
    bool insert(const String& input,int id,bool unique);
    bool update_id_b(const PackedByteArray& data,int new_id);
    bool update_id(const String& input,int new_id);
    bool remove_b(const PackedByteArray& input);
    bool remove(const String& input);
    int search(const String& input) const;
    PackedInt32Array begin_with(const String& input) const;
    void clear();

};
#endif