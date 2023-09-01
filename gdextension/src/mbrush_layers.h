#ifndef MBRUSHLAYERS
#define MBRUSHLAYERS


#include <godot_cpp/classes/resource.hpp>


using namespace godot;


class MBrushLayers : public Resource {
    GDCLASS(MBrushLayers,Resource);

    protected:
    static void _bind_methods();

    public:
    Dictionary props;
    String layers_title;
    String uniform_name;
    String brush_name="color brush";
    Array layers;

    MBrushLayers();
    ~MBrushLayers();

    void set_layers_title(String input);
    String get_layers_title();

    void set_uniform_name(String input);
    String get_uniform_name();

    void set_brush_name(String input);
    String get_brush_name();

    void set_layers_num(int input);
    int get_layers_num();

    void set_layers(Array input);
    Array get_layers();


    void _get_property_list(List<PropertyInfo> *p_list) const;
    bool _get(const StringName &p_name, Variant &r_ret) const;
    bool _set(const StringName &p_name, const Variant &p_value);

};
#endif