#include "mtrie.h"

#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/templates/pair.hpp>

void MTrie::_bind_methods(){
    ClassDB::bind_method(D_METHOD("insert","input","id","unique"), &MTrie::insert);
    ClassDB::bind_method(D_METHOD("remove","input"), &MTrie::remove);
    ClassDB::bind_method(D_METHOD("search","input"), &MTrie::search);
    ClassDB::bind_method(D_METHOD("begin_with","input"), &MTrie::begin_with);
    ClassDB::bind_method(D_METHOD("clear"), &MTrie::clear);
}

MTrie::Nd::Nd(){
}

MTrie::Nd::~Nd(){
}

bool MTrie::Nd::has_children(){
    return nodes.size() > 0;
}

// should not remove node current_index=0 as it is root

bool MTrie::_remove_rec(Nd* node,const PackedByteArray& input, bool &removed,int current_index){
    if(current_index == input.size() - 1){
        if(node->id >= 0){
            node->id = -1;
            removed = true;

            if(!node->has_children()){
                return true;
            }
        }
        return false;
    }
    int nindex = node->nodes.find(input[current_index+1]);
    if(nindex < 0){
        return false;
    }
    if(_remove_rec(&node->nodes.get_array()[nindex].value,input,removed,current_index + 1)){
        node->nodes.erase(input[current_index]);
    }

    if(removed && !node->has_children() && node->id < 0 && current_index != 0){
        return true;
    }
    return false;
}

void MTrie::_add_ids_rec(const Nd* node,PackedInt32Array& ids) const {
    if(node->id >= 0){
        ids.push_back(node->id);
    }
    for(int i=0; i < node->nodes.size(); i++){
        _add_ids_rec(&node->nodes.get_array()[i].value, ids);
    }
}

bool MTrie::insert_b(const PackedByteArray& data,int id,bool unique){
    Nd* cur = &root;
    for(int i=0; i < data.size(); i++){
        int index = cur->nodes.find(data[i]);
        if(index == -1){
            index = cur->nodes.insert(data[i],Nd());
        }
        cur = &cur->nodes.get_array()[index].value;
    }
    ERR_FAIL_COND_V_MSG(cur->id >= 0 && unique,false,"The word "+data.get_string_from_ascii()+" is not unique!");
    cur->id = id;
    return true;
}

bool MTrie::insert(const String& input,int id,bool unique){
    PackedByteArray data = input.to_ascii_buffer();
    return insert_b(data,id,unique);
}

bool MTrie::update_id_b(const PackedByteArray& data,int new_id){
    Nd* cur = &root;
    for(int i=0; i < data.size(); i++){
        if(!cur->nodes.has(data[i])){
            return false;
        }
        cur = &cur->nodes[data[i]];
    }
    if(cur->id >= 0){
        cur->id = new_id;
        return true;
    }
    return false;
}

bool MTrie::update_id(const String& input,int new_id){
    PackedByteArray data = input.to_ascii_buffer();
    return update_id_b(data,new_id);
}

/*
    input values should be between 0 upto 26
*/
bool MTrie::remove_b(const PackedByteArray& data){
    int findex = root.nodes.find(data[0]);
    if(findex < 0){
        return false;
    }
    bool removed = false;
    _remove_rec(&root.nodes.get_array()[findex].value,data,removed);
    return removed;
}

bool MTrie::remove(const String& input){
    if(input.length()==0){
        return false;
    }
    PackedByteArray data = input.to_ascii_buffer();
    return remove_b(data);
}

int MTrie::search(const String& input) const {
    if(input.length()==0){
        return -1;
    }
    PackedByteArray data = input.to_ascii_buffer();
    const Nd* cur = &root;
    for(int i=0; i < data.size(); i++){
        if(!cur->nodes.has(data[i])){
            return -1;
        }
        cur = &cur->nodes[data[i]];
    }
    return cur->id;
}


PackedInt32Array MTrie::begin_with(const String& input) const {
    PackedInt32Array out;
    if(input.length() == 0){
        return out;
    }
    PackedByteArray data = input.to_ascii_buffer();
    const Nd* cur = &root;
    for(int i=0; i < data.size(); i++){
        int pindex = cur->nodes.find(data[i]);
        if(pindex < 0){
            return out;
        }
        cur = &cur->nodes.get_array()[pindex].value;
    }
    _add_ids_rec(cur,out);
    return out;
}

void MTrie::clear(){
    for(int i=root.nodes.size() - 1; i >= 0 ; i--){
        root.nodes.erase(root.nodes.get_array()[i].key);
    }
}

