#include "mbrush_layers.h"
#include <godot_cpp/variant/utility_functions.hpp>

#include <godot_cpp/classes/image.hpp>
#include "mcolor_brush.h"
#define BRUSH_NAMES "Color Paint,bitwise brush"


void MBrushLayers::_bind_methods(){
    ClassDB::bind_method(D_METHOD("set_layers_title","input"), &MBrushLayers::set_layers_title);
    ClassDB::bind_method(D_METHOD("get_layers_title"), &MBrushLayers::get_layers_title);
    ADD_PROPERTY(PropertyInfo(Variant::STRING,"layers_title"), "set_layers_title","get_layers_title");
    ClassDB::bind_method(D_METHOD("set_uniform_name","input"), &MBrushLayers::set_uniform_name);
    ClassDB::bind_method(D_METHOD("get_uniform_name"), &MBrushLayers::get_uniform_name);
    ADD_PROPERTY(PropertyInfo(Variant::STRING,"uniform_name"), "set_uniform_name","get_uniform_name");
    ClassDB::bind_method(D_METHOD("set_brush_name","input"), &MBrushLayers::set_brush_name);
    ClassDB::bind_method(D_METHOD("get_brush_name"), &MBrushLayers::get_brush_name);
    ADD_PROPERTY(PropertyInfo(Variant::STRING,"brush_name",PROPERTY_HINT_ENUM,BRUSH_NAMES), "set_brush_name","get_brush_name");
    ClassDB::bind_method(D_METHOD("set_layers","input"), &MBrushLayers::set_layers);
    ClassDB::bind_method(D_METHOD("get_layers"), &MBrushLayers::get_layers);
    ADD_PROPERTY(PropertyInfo(Variant::ARRAY,"layers",PROPERTY_HINT_NONE,"",PROPERTY_USAGE_STORAGE), "set_layers","get_layers");
    ClassDB::bind_method(D_METHOD("set_layers_num","input"), &MBrushLayers::set_layers_num);
    ClassDB::bind_method(D_METHOD("get_layers_num"), &MBrushLayers::get_layers_num);
    ADD_PROPERTY(PropertyInfo(Variant::INT,"layers_num",PROPERTY_HINT_NONE,"",PROPERTY_USAGE_NONE), "set_layers_num","get_layers_num");
}

MBrushLayers::MBrushLayers(){
    Dictionary color_brush;
    color_brush["hardness"] = Variant(0.9);
    color_brush["color"] = Variant(Color(1.0,0.0,0.0,1.0));
    props["Color Paint"]=color_brush;
}
MBrushLayers::~MBrushLayers(){

}

void MBrushLayers::set_layers_title(String input){
    layers_title = input;
}

String MBrushLayers::get_layers_title(){
    return layers_title;
}

void MBrushLayers::set_uniform_name(String input){
    uniform_name = input;
}
String MBrushLayers::get_uniform_name(){
    return uniform_name;
}

void MBrushLayers::set_brush_name(String input){
    if(input == brush_name){
        return;
    }
    brush_name = input;
    for(int i=0;i<layers.size();i++){
        Dictionary org = layers[i];
        Dictionary dic;
        dic["NAME"]=org["NAME"];
        dic["ICON"]=org["ICON"];
        if(props.has(brush_name)){
            Dictionary p = props[brush_name];
            Array n = p.keys();
            for(int k=0;k<n.size();k++){
                dic[n[k]] = p[n[k]];
            }
        }
        layers[i] = dic;
    }
}

String MBrushLayers::get_brush_name(){
    return brush_name;
}

void MBrushLayers::set_layers_num(int input){
    ERR_FAIL_COND(input<0);
    layers.resize(input);
    for(int i=0;i<layers.size();i++){
        if(layers[i].get_type() == Variant::NIL){
            Dictionary dic;
            dic["NAME"]="";
            dic["ICON"]="";
            if(props.has(brush_name)){
                Dictionary p = props[brush_name];
                Array n = p.keys();
                for(int k=0;k<n.size();k++){
                    dic[n[k]] = p[n[k]];
                }
            }
            layers[i] = dic;
        }
    }
    notify_property_list_changed();
}

int MBrushLayers::get_layers_num(){
    return layers.size();
}

void MBrushLayers::set_layers(Array input){
    layers = input;
}
Array MBrushLayers::get_layers(){
    return layers;
}



void MBrushLayers::_get_property_list(List<PropertyInfo> *p_list) const {
    PropertyInfo lnum(Variant::INT, "layers_num",PROPERTY_HINT_NONE,"",PROPERTY_USAGE_EDITOR);
    p_list->push_back(lnum);
    for(int i=0;i<layers.size();i++){
        PropertyInfo lsub(Variant::INT, "layers "+itos(i),PROPERTY_HINT_NONE,"",PROPERTY_USAGE_SUBGROUP);
        PropertyInfo lname(Variant::STRING, "L_NAME_"+itos(i),PROPERTY_HINT_NONE,"",PROPERTY_USAGE_EDITOR);
        PropertyInfo licon(Variant::STRING, "L_ICON_"+itos(i),PROPERTY_HINT_GLOBAL_FILE,"",PROPERTY_USAGE_EDITOR);
        p_list->push_back(lsub);
        p_list->push_back(lname);
        p_list->push_back(licon);
        if(props.has(brush_name)){
            Dictionary p = props[brush_name];
            Array keys=p.keys();
            for(int k=0;k<keys.size();k++){
                PropertyInfo ll(p[keys[k]].get_type(), "L_ "+String(keys[k])+"_"+itos(i),PROPERTY_HINT_NONE,"",PROPERTY_USAGE_EDITOR);
                p_list->push_back(ll);
            }
        }
    }
}
bool MBrushLayers::_get(const StringName &p_name, Variant &r_ret) const{
    if(p_name.begins_with("L_")){
        PackedStringArray parts = p_name.split("_");
        int index = parts[2].to_int();
        Dictionary dic = layers[index];
        String key = parts[1].strip_edges();
        r_ret = dic[key];
        return true;
    }
    return false;
}
bool MBrushLayers::_set(const StringName &p_name, const Variant &p_value){
    if(p_name.begins_with("L_")){
        PackedStringArray parts = p_name.split("_");
        int index = parts[2].to_int();
        Dictionary dic = layers[index];
        String key = parts[1].strip_edges();
        dic[key] = p_value;
        layers[index] = dic;
        return true;
    }
    return false;
}

Array MBrushLayers::get_layers_info(){
    Array out;
    HashMap<String,Ref<ImageTexture>> current_textures;
    for(int i=0;i<layers.size();i++){
        Dictionary l = layers[i];
        Dictionary dic;
        dic["name"]=l["NAME"];
        if(textures.has(l["ICON"])){
            current_textures.insert(l["ICON"],textures.get(l["ICON"]));
            dic["icon"]=textures.get(l["ICON"]);
        } else {
            Ref<Image> img = Image::load_from_file(l["ICON"]);
            Ref<ImageTexture> tex;
            if(img.is_valid()){
                img->resize(64,64);
                tex = ImageTexture::create_from_image(img);
            }
            textures.insert(l["ICON"],tex);
            current_textures.insert(l["ICON"],tex);
            dic["icon"]=tex;
        }
        out.push_back(dic);
    }
    for(HashMap<String,Ref<ImageTexture>>::Iterator it=textures.begin();it!=textures.end();++it){
        if(!current_textures.has(it->key)){
            textures.erase(it->key);
        }
    }
    return out;
}

void MBrushLayers::set_layer(int index,MColorBrush* brush){
    Dictionary info = layers[index];
    Array keys = info.keys();
    for(int i=0;i<keys.size();i++){
        if(keys[i]!="NAME" && keys[i]!="ICON"){
            brush->_set_property(keys[i],info[keys[i]]);
        }
    }
}