# _GLB_FILE_PATH -> will replace by glb filepath
# _BAKER_NAME -> will replace by baker name

#bpy.ops.import_scene.gltf(filepath='_GLB_FILE_PATH')

import bpy
import socket
import json
import pathlib
import mathutils
import struct
import math
from bpy.app.handlers import persistent

TIMER_INTERVAL = 0.5
client = None
last_state = {}
objects = {}
receiving_data = False

def print_matrix(mat):
    print( round(mat[0][0], 2), round(mat[0][1],2), round(mat[0][2],2)) 
    print( round(mat[1][0],2), round(mat[1][1],2),round(mat[1][2], 2))
    print( round(mat[2][0],2), round(mat[2][1],2), round(mat[2][2],2))
    print( "-----------------")
    print( round(mat[0][3],2), round(mat[1][3],2), round(mat[2][3],2))

class TCP_OT_Connect(bpy.types.Operator):
    bl_idname = "mterrain.tcp_connect"
    bl_label = "Open tcp connection"
    bl_options = {"REGISTER", "UNDO"}
    ip: bpy.props.StringProperty(default="127.0.0.1")
    port: bpy.props.IntProperty(default=9997)
    def execute(self, context):      
        global objects  
        for obj in bpy.data.objects:
            bpy.data.objects.remove(obj)
        objects = {}        
        success = tcp_connect(self.ip, self.port)
        last_state = get_state()
        return {'FINISHED'} if success else {'CANCELLED'}

class TCP_OT_Disconnect(bpy.types.Operator):
    bl_idname = "mterrain.tcp_disconnect"
    bl_label = "End tcp connection"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):        
        tcp_disconnect()
        last_state = {}
        return {'FINISHED'}

class TCP_OT_Update_Scene_From_Godot(bpy.types.Operator):
    bl_idname = "mterrain.update_scene_from_godot"
    bl_label = "Load scene from godot data"        
    bl_options = {"REGISTER", "UNDO"}
    message: bpy.props.StringProperty()
    
    def execute(self, context):        
        update_scene_from_godot(self.message)
        return {'FINISHED'}

def update_scene_from_godot(message):
    data = json.loads(message)                                                       
    for node_path in sorted(data.keys()):                       
        ##############
        ## RENAMING ##
        ##############
        if node_path == "__renamed":
            rename_object(data[node_path])                                        
        #################
        ## REPARENTING ##
        #################
        elif node_path == "__reparented":
            pass
            # TODO
        
        if node_path.startswith("__"): continue                                
        #################
        ## NEW OBJECTS ##
        #################                                              
        if not node_path in objects or not get_object_from_node_path(node_path):                    
            create_node(data, node_path)                                        
        if not data[node_path]: continue
        if "location" in data[node_path] or "rotation" in data[node_path] or "scale" in data[node_path]:
            obj = get_object_from_node_path(node_path)
            if node_path == "_root":             
                godot_to_blender_mat = mathutils.Matrix([[1,0,0,0], [0,0,-1,0], [0,1,0,0], [0,0,0,1]])           
                obj.matrix_local = godot_to_blender_mat
            else:
                if "position" in data[node_path]:                        
                    obj.location = parse_vector( data[node_path]["position"])
                if "rotation" in data[node_path]:
                    obj.rotation_euler = mathutils.Euler(parse_vector( data[node_path]["rotation"]))                            
                    #obj.rotation_euler.x -= math.pi/2
                if "scale" in data[node_path]:
                    obj.scale = parse_vector( data[node_path]["scale"])                                                                        
    if "__selected_objects" in data:
        print("Selecting: ", data["__selected_objects"])
        bpy.ops.object.select_all(action='DESELECT')
        for node_path in data['__selected_objects']:                                        
            obj = get_object_from_node_path(node_path)
            obj.select_set(True)          
            bpy.context.view_layer.objects.active = obj
    
def get_state():
    state = {}
    state['__selected_objects'] = tuple([obj.name for obj in bpy.context.selected_objects])
    #for obj in bpy.data.objects:
    #    state[obj.name] = {"matrix_world": obj.matrix_world}
    return state

def compare_states(new_state, old_state):    
    set1 = frozenset(old_state.items())    
    set2 = frozenset(new_state.items())
    return dict(set2-set1)
    

def tcp_connect(ip='127.0.0.1', port = 9997):
    global client
    # Create a socket and connect to the server
    client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)  # TCP socket    
    client.connect((ip, port))  # Connect to Godot server on port 9998
    client.setblocking(False)
    bpy.app.timers.register(_process)
    return True

def tcp_disconnect():
    global client
    bpy.app.timers.unregister(_process)
    client.close()

def _process():
    # Send data to Godot    
    global last_state
    global client    
    # data = compare_states(get_state(), last_state)    
    # if data:
    #     message = json.dumps(data).encode('utf-8')    
    #     client.sendall(message)    
    #     last_state = get_state()

    # Receive Data from Godot
    receive_data()  
    return TIMER_INTERVAL

def rename_object(renamed_node_paths):
    for old_node_path in renamed_node_paths.keys():                        
        old_path = pathlib.Path(old_node_path).as_posix()
        new_path = renamed_node_paths[old_node_path]
        new_name = pathlib.Path(new_path).stem
        for old_key in objects:
            if old_path in old_key:
                new_key = old_key.replace(old_path, new_path)
                obj = get_object_from_node_path(old_key)
                if obj:
                    obj.name = new_name
                    objects[new_key] = obj.name
                del objects[old_key]                

def find_asset_name_or_first_lod(matching_names):
    empty_parent = [name for name in matching_names if not "_lod" in name and not "_col" in name and not "collision" in name]
    if empty_parent:
        return empty_parent[0]
    else:
        first_lod = [name for name in matching_names if "_lod" in name]
        if first_lod:
            return first_lod[0]
    return None

def import_asset(blend_file, glb_name):
    library_object_name = None
    ######################################################
    ## 1. if asset already imported, make override copy ##
    ######################################################
    path = pathlib.Path(blend_file)    
    if path.name in bpy.data.libraries:
        imported_objects = [obj for obj in bpy.data.libraries[path.name].users_id if obj.name in bpy.data.objects and glb_name in obj.name and isinstance( obj, bpy.types.Object)]                
        imported_object_names = [obj.name for obj in imported_objects]
        library_object_name = find_asset_name_or_first_lod(imported_object_names)
        linked_object = [obj for obj in imported_objects if obj.name == library_object_name]
        if linked_object:
            obj = linked_object[0].override_create()
            library_object_name = obj.name            
    ################################
    ## 2. If NOT imported, import ##
    ################################
    if not library_object_name:        
        with bpy.data.libraries.load(blend_file, assets_only = False, link = True, ) as (data_from, data_to):        
            matching_names = [name for name in data_from.objects if glb_name in name]
            library_object_name = find_asset_name_or_first_lod(matching_names)
            #library_object_name = [name for name in data_from.objects if glb_name in name and not "_lod" in name and not "_col" in name and not "collision" in name][0]
            if library_object_name:
                data_to.objects.append(library_object_name)                                        
        ## Check if object was imported and added to bpy.data and scene (default behaviors)
        for obj_name in data_to.objects:
            if library_object_name in obj_name:
                library_object_name = obj_name
                if library_object_name in bpy.context.scene.collection.objects:
                    bpy.context.scene.collection.objects.unlink(library_object_name)
        ## If not, Check if object link was made but not added. If so, add to bpy.data
        if not library_object_name:
            imported_objects = [obj.name for obj in bpy.data.libraries[path.name].users_id if obj.name in bpy.data.objects and glb_name in obj.name]                
            library_object_name = find_asset_name_or_first_lod(imported_objects)
            linked_object = [obj for obj in bpy.data.libraries[path.name].users_id if obj.name == library_object_name]
            if linked_object:
                obj = linked_object[0].override_create()
                library_object_name = obj.name        
    ###################################################################################
    ## 3. If success, ensure object overrides are correct and object is in the scene ##
    ###################################################################################
    if library_object_name and library_object_name in bpy.data.objects:                
        original_object = bpy.data.objects[library_object_name]
        if not original_object.override_library:
            obj = original_object.override_create()
            if not obj.name in bpy.context.scene.collection.objects:
                bpy.context.scene.collection.objects.link(bpy.data.objects[obj.name])
            for mesh in [o.mesh for o in obj.mesh_lods.lods]:
                mesh.override_create()                
    return obj if obj else None

def create_node(data, node_path):
    global objects
    path = pathlib.Path(node_path)                                                 
    obj = None
    obj_name = path.stem
    if not "_root" in objects or not "_root" in bpy.data.objects:        
        bpy.data.objects.new("_root", None)                
        if "_root" in bpy.data.objects:
            objects["_root"] = "_root"
            bpy.context.scene.collection.objects.link( get_object_from_node_path("_root") )
    
    node_class = data[node_path]["type"] if "type" in data[node_path] else None
    if node_class == "MAssetMesh":
        print("masset ---------------------------")
        if "blend_file" in data[node_path] and "glb_name" in data[node_path]:            
            blend_file = data[node_path]["blend_file"]
            asset_name = data[node_path]["glb_name"]
            obj = import_asset(blend_file,asset_name)
            objects[node_path] = obj.name
        
    if not obj or not node_path in objects or not objects[node_path]:
        obj = bpy.data.objects.new(obj_name, None)
        objects[node_path] = obj.name
        obj.empty_display_type = "CUBE"        
    
    ## ASSIGN PARENT
    if len(path.parts)>1:
        obj.parent = get_object_from_node_path(path.parent.as_posix())
    elif node_path != "_root":
        obj.parent = get_object_from_node_path("_root")
        
    if not obj.name in bpy.context.scene.collection.objects:
        bpy.context.scene.collection.objects.link( obj )

def get_object_from_node_path(node_path):
    global objects
    return bpy.data.objects[objects[node_path]] if node_path in objects and objects[node_path] in bpy.data.objects else None

def parse_vector(text):    
    return mathutils.Vector([float(x) for x in text.split("(")[1].split(")")[0].split(",")])

def parse_transform(text):    
    x = mathutils.Vector([float(value) for value in text.split('(')[1][:-6].split(", ")])
    y = mathutils.Vector([float(value) for value in text.split('(')[2][:-6].split(", ")])
    z = mathutils.Vector([float(value) for value in text.split('(')[3][:-6].split(", ")])
    loc = mathutils.Vector([float(value) for value in text.split('(')[4][:-2].split(", ")])
    loc = mathutils.Vector((loc[0], loc[1], loc[2]))
    
    godot_to_blender_mat = mathutils.Matrix([[1,0,0,0], [0,0,-1,0], [0,1,0,0], [0,0,0,1]])        
    return mathutils.Matrix([
        [x.x,x.y,x.z,loc.x],
        [y.x,y.y,y.z,loc.y],
        [z.x,z.y,z.z,loc.z],
        
        [0., 0., 0., 1.]
        ]) #@ godot_to_blender_mat
    
def transform_to_string(mat):
    blender_to_godot_mat = mathutils.Matrix([[1,0,0,0], [0,0,-1,0], [0,1,0,0], [0,0,0,1]]).inverted()
    final_mat = mat @ blender_to_godot_mat
    loc = [final_mat[0][3], final_mat[1][3], final_mat[2][3]]
    x = [final_mat[0][0], final_mat[0][1], final_mat[0][2]]
    y = [final_mat[1][0], final_mat[1][1], final_mat[1][2]]
    z = [final_mat[2][0], final_mat[2][1], final_mat[2][2]]
    return "[X: (%s, %s, %s), Y: (%s, %s, %s),Z: (%s, %s, %s), O: (%s, %s, %s)]" % [x[0],x[1],x[2],loc[0], y[0],y[1],y[2],loc[1], z[0],z[1],z[2],loc[2]]
    
    
def receive_data():
    global client
    global objects
    global receiving_data
    if receiving_data: return
    receiving_data = True
    try:
        count_bytes = client.recv(4)
        if len(count_bytes)==2:                         
            count = struct.unpack("<H", count_bytes)[0]        
        elif len(count_bytes)==4:
            count = struct.unpack("<I", count_bytes)[0]   
        else:
            receiving_data = False    
            return
        message = bytearray()        
        while len(message) < count:            
            packet = client.recv(1024)
            message.extend(packet)  # Receive message (up to 1024 bytes)            
        if message:       
            bpy.ops.mterrain.update_scene_from_godot(message=message.decode('utf-8'))                                          
            receiving_data = False
    except socket.error:
        receiving_data = False
        pass
        #print("socket error: ", socket.error)    

def send_data():
    pass
    #transform_to_string()

classes = [TCP_OT_Update_Scene_From_Godot, TCP_OT_Disconnect, TCP_OT_Connect]

@persistent
def first_start():
    obj = bpy.data.objects.new("test", None)
    bpy.context.scene.collection.objects.link(obj)
    try:
        if bpy.ops.mterrain.tcp_connect() != {'FINISHED'}: return 1.0
    except:
        return 1.0
    
def register():    
    for c in classes:
        bpy.utils.register_class(c)
    bpy.app.handlers.load_post.append(first_start)    
    self.report({"INFO"}, "registered")
        
def unregister():
    for c in classes:
        bpy.utils.unregister_class(c)    

if __name__ == "__main__":
    register()