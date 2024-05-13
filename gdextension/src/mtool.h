#ifndef MTOOL
#define MTOOL

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/texture.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/templates/vector.hpp>
#include "mconfig.h"

using namespace godot;

class MTool : public Object
{
    GDCLASS(MTool, Object);
private:
    static Vector<Node3D*> editor_cameras;
    static Vector<Vector3> editor_cameras_last_pos;
    static int camera_index;
    static bool editor_plugin_active;

protected:
    static void _bind_methods();
public:
    MTool();
    ~MTool();
    static Ref<Image> get_r16_image(const String& file_path, const uint64_t width, const uint64_t height,double min_height, double max_height,const bool is_half);
    static void write_r16(const String& file_path,const PackedByteArray& data,double min_height,double max_height);
    static PackedByteArray normalize_rf_data(const PackedByteArray& data,double min_height,double max_height); 
    static Node3D* find_editor_camera(bool changed_camera);
    static void enable_editor_plugin();
    static bool is_editor_plugin_active();
};







#endif