#include "mmaterial_table.h"

//#include "masset_table.h"
#include "mhlod.h"
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/resource_saver.hpp>

Ref<MMaterialTable> MMaterialTable::material_table_singelton;

void MMaterialTable::_bind_methods(){
    ClassDB::bind_static_method("MMaterialTable",D_METHOD("get_singleton"), &MMaterialTable::get_singleton);
    ClassDB::bind_static_method("MMaterialTable",D_METHOD("save"), &MMaterialTable::save);
    ClassDB::bind_static_method("MMaterialTable",D_METHOD("get_material_table_path"), &MMaterialTable::get_material_table_path);

    ClassDB::bind_method(D_METHOD("add_material","path"), &MMaterialTable::add_material);
    ClassDB::bind_method(D_METHOD("remove_mateiral","id"), &MMaterialTable::remove_mateiral);
    ClassDB::bind_method(D_METHOD("find_material_id","path"), &MMaterialTable::find_material_id);

    ClassDB::bind_method(D_METHOD("set_table","input"), &MMaterialTable::set_table);
    ClassDB::bind_method(D_METHOD("get_table"), &MMaterialTable::get_table);
    ADD_PROPERTY(PropertyInfo(Variant::DICTIONARY,"table"),"set_table","get_table");
}

Ref<MMaterialTable> MMaterialTable::get_singleton(){
    if(material_table_singelton.is_null()){
        if(ResourceLoader::get_singleton()->exists(MHlod::material_table_path)){
            material_table_singelton = ResourceLoader::get_singleton()->load(MHlod::material_table_path);
        }
        if(material_table_singelton.is_null()){
            material_table_singelton.instantiate();
            save();
        }
    }
    return material_table_singelton;
}

void MMaterialTable::save(){
    if(material_table_singelton.is_null()){
        get_singleton();
    }
    ERR_FAIL_COND(material_table_singelton.is_null());
    ResourceSaver::get_singleton()->save(material_table_singelton,MHlod::material_table_path);
}

String MMaterialTable::get_material_table_path(){
    return String(MHlod::material_table_path);
}

int MMaterialTable::add_material(const String& _path){
    for(int32_t i=0; i < 100000; i++){
        if(paths.has(i)){
            continue;
        }
        paths.insert(i,_path);
        return i;
    }
    ERR_FAIL_V_MSG(-1,"Max number of materials is 100000!");
}

void MMaterialTable::remove_mateiral(int id){
    paths.erase(id);
}

int MMaterialTable::find_material_id(const String& _path) const{
    for(HashMap<int32_t,String>::ConstIterator it=paths.begin();it!=paths.end();++it){
        if(_path == it->value){
            return it->key;
        }
    }
    return -1;
}

void MMaterialTable::set_table(const Dictionary& info){
    paths.clear();
    Array keys = info.keys();
    for(int i=0; i < keys.size(); i++){
        paths.insert(keys[i],info[keys[i]]);
    }
}

Dictionary MMaterialTable::get_table() const{
    Dictionary out;
    for(HashMap<int32_t,String>::ConstIterator it=paths.begin();it!=paths.end();++it){
        out[it->key] = it->value;
    }
    return out;
}
