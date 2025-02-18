# _GLB_FILE_PATH -> will replace by glb filepath
# _BAKER_NAME -> will replace by baker name
import bpy

#bpy.ops.wm.read_factory_settings(use_empty=True)
for obj in bpy.data.objects:
    bpy.data.objects.remove(obj)

bpy.ops.import_scene.gltf(filepath='_GLB_FILE_PATH')

for area in bpy.context.screen.areas:
    if area.type == 'VIEW_3D':
        for space in area.spaces:
            if space.type == 'VIEW_3D':
                # Set shading mode to 'MATERIAL'
                space.shading.type = 'MATERIAL'

if _REPLACE_MATERIALS:
    material_names = set()
    materials_data = {}
    for obj in bpy.data.objects:
        materials_data[obj.name] = []
        for material in obj.material_slots:
            materials_data[obj.name].append(material.name)
            material_names.add(material.name)
            material.material = None
    for material in bpy.data.materials:
        bpy.data.materials.remove(material)
    with bpy.data.libraries.load(filepath='_MATERIALS_BLEND_PATH', assets_only = True, link = True) as (data_from, data_to):
        for i, mat in enumerate(data_from.materials):                
            data_to.materials.append(data_from.materials[i])
    for obj_name in materials_data.keys():
        for i, slot in enumerate(bpy.data.objects[obj_name].material_slots):
            material_name = materials_data[obj_name][i]
            if material_name in bpy.data.materials:
                slot.material = bpy.data.materials[material_name]
            else:
                print("material with name %s not found" % material_name)

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
