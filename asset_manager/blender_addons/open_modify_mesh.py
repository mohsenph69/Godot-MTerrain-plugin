import bpy
import re
# __OBJ_NAME__    replace with name of the object
# _BLEND_FILE_PATH  replace with glb_file_path
# _GLB_FILE_PATH  replace with glb_file_path

pattern = re.compile("__OBJ_NAME__[_| ]?lod[_| ]?\\d+")

def focus_on_object(obj):
    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            for region in area.regions:
                if region.type == "WINDOW":
                    with bpy.context.temp_override(area=area, region=region):
                        bpy.ops.view3d.view_selected()

def init_traget_object():
    """Focus the view on a specific object if it exists."""
    for obj in bpy.data.objects:
        if obj.name=="__OBJ_NAME__" or pattern.match(obj.name):
            print("Match ",obj.name)
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj
            focus_on_object(obj)
        else:
            obj.select_set(False)




bpy.ops.wm.open_mainfile(filepath="_BLEND_FILE_PATH")
#focus_on_object()
bpy.app.timers.register(init_traget_object, first_interval=0.75)

class ExportGLBOperator(bpy.types.Operator):
    """Export GLB to Default Path"""
    bl_idname = "export.glb_godot_assets"
    bl_label = "Export GLB Godot Assets"

    def execute(self, context):
        bpy.ops.export_scene.gltf(filepath='_GLB_FILE_PATH', export_format='GLB',export_image_format = 'NONE',export_materials = 'EXPORT')
        self.report({'INFO'}, "GLB Exported Successfully to _GLB_FILE_PATH")
        return {'FINISHED'}

def menu_func(self, context):
    self.layout.operator(ExportGLBOperator.bl_idname, text='Export Godot Assets')

def register():
    bpy.utils.register_class(ExportGLBOperator)
    bpy.types.TOPBAR_MT_file_export.append(menu_func)

def unregister():
    bpy.utils.unregister_class(ExportGLBOperator)
    bpy.types.TOPBAR_MT_file_export.remove(menu_func)

if __name__ == "__main__":
    register()
