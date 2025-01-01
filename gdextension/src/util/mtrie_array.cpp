#include "mtrie_array.h"

#include <godot_cpp/variant/utility_functions.hpp>

void MTrieArray::_bind_methods(){
    ClassDB::bind_method(D_METHOD("size"), &MTrieArray::size);
    ClassDB::bind_method(D_METHOD("is_empty"), &MTrieArray::is_empty);
    ClassDB::bind_method(D_METHOD("set_element","p_index","p_value"), &MTrieArray::set_element);
    ClassDB::bind_method(D_METHOD("get_element","p_index"), &MTrieArray::get_element);
    ClassDB::bind_method(D_METHOD("push_back","input"), &MTrieArray::push_back);
    ClassDB::bind_method(D_METHOD("append_array","input"), &MTrieArray::append_array);
    ClassDB::bind_method(D_METHOD("append_string_array","input"), &MTrieArray::append_string_array);
    ClassDB::bind_method(D_METHOD("remove_at","p_index"), &MTrieArray::remove_at);
    ClassDB::bind_method(D_METHOD("clear"), &MTrieArray::clear);
    ClassDB::bind_method(D_METHOD("has"), &MTrieArray::has);
    ClassDB::bind_method(D_METHOD("find"), &MTrieArray::find);
    ClassDB::bind_method(D_METHOD("resize","input"), &MTrieArray::resize);
    ClassDB::bind_method(D_METHOD("begin_with","input"), &MTrieArray::begin_with);
    ClassDB::bind_method(D_METHOD("to_packed_string_array"), &MTrieArray::to_packed_string_array);

    
}


MTrieArray::MTrieArray(){
    trie.instantiate();
}

MTrieArray::~MTrieArray(){

}

int64_t MTrieArray::size() const{
    return arr.size();
}

bool MTrieArray::is_empty() const{
    return arr.is_empty();
}

bool MTrieArray::is_element_empty(int p_index) const {
    if(p_index < 0 || p_index >= arr.size()){
        return false;
    }
    return arr[p_index].is_empty();
}

bool MTrieArray::set_element(int64_t p_index,const String& p_value){
    ERR_FAIL_INDEX_V(p_index,arr.size(),false);
    PackedByteArray data = p_value.to_ascii_buffer();
    if(arr[p_index].size() > 0){
        if(!trie->remove_b(arr[p_index])){
            ERR_FAIL_V_MSG(false,"Can not set_element because can not remove! "+arr[p_index].get_string_from_ascii());
        }
    }
    if(data.size()==0){
        arr.set(p_index,data);
        return true;
    }
    if(trie->insert_b(data,p_index,true)){
        arr.set(p_index,data);
        return true;
    }
    return false;
}

String MTrieArray::get_element(int64_t p_index) const {
    ERR_FAIL_INDEX_V(p_index,arr.size(),String());
    return arr[p_index].get_string_from_ascii();
}

bool MTrieArray::push_back(const String& p_value){
    PackedByteArray data = p_value.to_ascii_buffer();
    if(data.size() > 0){
        if(!trie->insert_b(data,arr.size(),true)){
            return false;
        }
    }
    arr.push_back(data);
    return true;
}

void MTrieArray::append_array(const Ref<MTrieArray> p_array){
    for(int i=0; i < p_array->size(); i++){
        push_back(p_array->get_element(i));
    }
}

void MTrieArray::append_string_array(const PackedStringArray &p_array){
    for(int i=0; i < p_array.size(); i++){
        push_back(p_array[i]);
    }
}

void MTrieArray::remove_at(int64_t p_index){
    ERR_FAIL_INDEX(p_index,arr.size());
    arr.remove_at(p_index);
    for(int i=p_index; i < arr.size(); i++){
        UtilityFunctions::print("update ",arr[i].get_string_from_ascii()," to ",i);
        trie->update_id_b(arr[i],i);
    }
}

void MTrieArray::clear(){
    trie->clear();
    arr.clear();
}

bool MTrieArray::has(const String& p_value) const{
    return trie->search(p_value) >= 0;
}

int MTrieArray::find(const String& p_value) const{
    return trie->search(p_value);
}

bool MTrieArray::resize(int input){
    if(input == arr.size()){
        return true;
    }
    if(input > arr.size()){
        return arr.resize(input) == godot::OK;
    }
    for(int i=input; i < arr.size(); i++){
        trie->remove_b(arr[i]);
    }
    arr.resize(input);
    return true;
}

PackedInt32Array MTrieArray::begin_with(const String& input) const{
    return trie->begin_with(input);
}

PackedStringArray MTrieArray::to_packed_string_array(){
    PackedStringArray out;
    out.resize(arr.size());
    for(int i=0 ; i < arr.size(); i++){
        out.set(i,arr[i].get_string_from_ascii());
    }
    return out;
}