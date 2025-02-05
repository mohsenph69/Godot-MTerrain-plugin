#ifndef __LRUCACHE__
#define __LRUCACHE__

#include <godot_cpp/templates/vector.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/variant/string.hpp>

#include <limits>
#include <type_traits>

using namespace godot;
// Index Zero in Data is invalid
template<typename KeyType,typename DataType,typename IndexType=uint16_t>
class MLRUCache {
    static_assert(std::is_same<IndexType,uint8_t>()||std::is_same<IndexType,uint16_t>()||std::is_same<IndexType,uint32_t>()||std::is_same<IndexType,uint64_t>());

    struct NodeData{
        IndexType left = 0;
        IndexType right = 0;
        KeyType key;
        DataType data;
    };
    // Zero index is invalid
    static constexpr IndexType most_left = 1;
    static constexpr IndexType most_right = 2;
    NodeData* data = nullptr;
    Vector<IndexType> free_indicies;
    HashMap<KeyType,IndexType> data_hashmap;
    public:
    MLRUCache() = default;
    ~MLRUCache(){
        if(data!=nullptr){
            memdelete_arr(data);
        }
    }
    MLRUCache(uint64_t size){
        init_cache(size);
    }
    _FORCE_INLINE_ bool is_empty() const{
        return data==nullptr;
    }
    void clear(){
        if(is_empty()){
            return;
        }
        memdelete_arr(data);
        data = nullptr;
        free_indicies.clear();
        data_hashmap.clear();
    }
    
    void init_cache(uint64_t size){
        clear();
        if(size==0){
            return;
        }
        uint64_t max_size = std::numeric_limits<IndexType>::max() - 4;
        ERR_FAIL_COND_MSG(size > max_size,"LRU Cache can not be bigger than "+itos(max_size));
        size += 3;
        data = memnew_arr(NodeData,size);
        data[most_left].left = 0;
        data[most_left].right = most_right;
        data[most_right].right = 0;
        data[most_right].left = most_left;
        for(int i=3; i < size; i++){
            free_indicies.push_back(i);
        }
    }
    void set_invalid_data(const DataType& _data){
        ERR_FAIL_COND_MSG(is_empty(),"You should call set_invalid_data after init_cache");
        data[0].data = _data;
    }
    private:
    _FORCE_INLINE_ const DataType& get_invalid_data() const{
        return data[0].data;
    }

    template<bool removeData=true>
    _FORCE_INLINE_ void remove_by_index(const IndexType remove_index){
        IndexType left = data[remove_index].left;
        IndexType right = data[remove_index].right;
        ERR_FAIL_COND(left==0||right==0||remove_index==0);
        data[left].right = right;
        data[right].left = left;
        // clearing
        if constexpr (removeData){
            data[remove_index].data = get_invalid_data();
            data_hashmap.erase(data[remove_index].key);
            free_indicies.push_back(remove_index);
        }
        data[remove_index].left = 0;
        data[remove_index].right = 0;
    }
    // Data should be added before calling this, also hashmap should be updated
    // this just fix left and right in the most right place
    _FORCE_INLINE_ void insert_by_index(const IndexType index){ // no data set here
        IndexType left = data[most_right].left;
        ERR_FAIL_COND(left==0||index==0);
        data[most_right].left = index;
        data[left].right = index;
        data[index].right = most_right;
        data[index].left = left;
    }
    public:
    _FORCE_INLINE_ bool has(const KeyType key) const{
        return data_hashmap.has(key);
    }

    _FORCE_INLINE_ void remove_left(){
        remove_by_index(data[most_left].right);
    }

    void erase(const Key key){
        if(data_hashmap.has(key)){
            remove_by_index(data_hashmap[key]);
        }
    }

    void insert(KeyType key,const DataType& _data){
        if(data_hashmap.has(key)){
            IndexType index = data_hashmap[key];
            data[index].data = _data;
            // remove only indices not data
            remove_by_index<false>(index);
            insert_by_index(index);
            return;
        }
        if(free_indicies.size()==0){
            remove_left();
        }
        // Getting new add index in data buffer
        ERR_FAIL_COND(free_indicies.size()==0);
        IndexType add_index = free_indicies[free_indicies.size() - 1];
        free_indicies.remove_at(free_indicies.size() - 1);
        data[add_index].data = _data;
        data[add_index].key = key;
        data_hashmap.insert(key,add_index);
        insert_by_index(add_index);
    };

    const DataType& get_data(const KeyType key){
        UtilityFunctions::print("Data is null ",data==nullptr);
        if(!data_hashmap.has(key)){
            return get_invalid_data();
        }
        IndexType index = data_hashmap[key];
        // remove only indices not data
        remove_by_index<false>(index);
        insert_by_index(index);
        return data[index].data;
    }
};
#endif