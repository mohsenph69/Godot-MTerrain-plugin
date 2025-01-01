#ifndef __MTRIEARRAY__
#define __MTRIEARRAY__

#include <godot_cpp/templates/vector.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include "mtrie.h"

using namespace godot;

class MTrieArray : public RefCounted {
    GDCLASS(MTrieArray,RefCounted);
    protected:
    static void _bind_methods();

    private:
    Ref<MTrie> trie;
    Vector<PackedByteArray> arr;

    public:
    MTrieArray();
    ~MTrieArray();
	int64_t size() const;
	bool is_empty() const;
    bool is_element_empty(int p_index) const;
	bool set_element(int64_t p_index,const String& p_value);
    String get_element(int64_t p_index) const; 
	bool push_back(const String& p_value);
    void append_array(const Ref<MTrieArray> p_array);
	void append_string_array(const PackedStringArray &p_array);
	void remove_at(int64_t p_index);
	void clear();
	bool has(const String& p_value) const;
    int find(const String& p_value) const;
    bool resize(int input);
    PackedInt32Array begin_with(const String& input) const;
    PackedStringArray to_packed_string_array();
    
};
#endif