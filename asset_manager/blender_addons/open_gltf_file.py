# _GLB_FILE_PATH -> will replace by glb filepath
# _BAKER_NAME -> will replace by baker name
import bpy

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath='_GLB_FILE_PATH')


class ExportGLBOperator(bpy.types.Operator):
    """Export GLB to Default Path"""
    bl_idname = "export.glb_join_mesh"
    bl_label = "Export GLB Join mesh"

    def execute(self, context):
        default_path = '_GLB_FILE_PATH'
        bpy.ops.export_scene.gltf(filepath=default_path, export_format='GLB',export_image_format = 'NONE',export_materials = 'EXPORT')
        self.report({'INFO'}, "GLB Exported Successfully to _GLB_FILE_PATH")
        return {'FINISHED'}

def menu_func(self, context):
    self.layout.operator(ExportGLBOperator.bl_idname, text='Export Join Mesh _BAKER_NAME')

def register():
    bpy.utils.register_class(ExportGLBOperator)
    bpy.types.TOPBAR_MT_file_export.append(menu_func)

def unregister():
    bpy.utils.unregister_class(ExportGLBOperator)
    bpy.types.TOPBAR_MT_file_export.remove(menu_func)

if __name__ == "__main__":
    register()
