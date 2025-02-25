@tool
class_name TCPSerializer extends RefCounted

enum TYPES {
	NONE=0,
	NODEPATH=1, 	
	SELECTION=2, RENAMED=3, REMOVED=4, ADDED=5,
	MASSET_MESH=20, COLLISION_SHAPE=21, SPOT_LIGHT=22, POINT_LIGHT=23, DIRECTIONAL_LIGHT=24, BAKER=25,
	BOX=51, SPHERE=52, CAPSULE=53, CYLINDER=54,
	POSITION=100, ROTATION=101, SCALE=102, NODE_TYPE=103, BLEND_FILE=104, GLB_NAME=105, MESH_CUTOFF=106, COLLISION_CUTOFF = 107
}

var data:PackedByteArray
var dict:Dictionary
var head = 0	

const FLOAT_SIZE = 4 #in bytes
func decode_byte():
	var value = data.decode_u8(head)
	head += 1
	return value
	
func decode_string():
	var nodepath_length = data.decode_u8(head)	
	head += 1	
	var result = data.slice(head, head+nodepath_length).get_string_from_utf8()
	head += nodepath_length
	return result

func decode_float(size = FLOAT_SIZE):
	var result
	if size == 4:
		result = data.decode_float(head)
		head += 4
	elif size == 2:
		result = data.decode_half(head)
		head += 2
	elif size == 8:
		result = data.decode_double(head)
		head += 8
	return result

func decode_vector3():
	var x = decode_float()
	var y = decode_float()
	var z = decode_float()	
	var vec := Vector3(x,y,z)	
	return vec	

func encode_byte(value):
	data.encode_u8(head, value)
	head += 1
	
func encode_string(nodepath):
	var chars = str(nodepath).to_utf8_buffer()
	data.encode_u8(head, len(chars))
	head += 1				
	for char in chars:		
		data.set(head, char)		
		head += 1

func encode_float(value, size = FLOAT_SIZE):	
	if size == 4:
		data.encode_float(head, value)
		head += 4
	elif size == 2:
		data.encode_half(head, value)
		head += 2
	elif size == 8:
		data.encode_double(head, value)
		head += 8	
	
func encode_vector3(vec:Vector3):
	encode_float(vec.x)
	encode_float(vec.y)
	encode_float(vec.z)	

func pack():
	data = PackedByteArray()	
	data.resize(pow(2,16))
	head = 4 # encode the size at the end, or verification
	var dict_keys = dict.keys()	
	data.encode_u16(head, len(dict_keys)) # encode the number of keys
	head += 2		
	for key in dict_keys:		
		if not key is NodePath:
			if key == "__renamed":
				encode_byte(TYPES.RENAMED)			
				var renamed_keys = dict["__renamed"].keys()
				encode_byte(renamed_keys.size())
				for from in renamed_keys:
					encode_string(from)				
					encode_string(dict[key][from])										
			elif key =="__removed":
				encode_byte(TYPES.REMOVED)			
				encode_byte( len(dict["__removed"]))					
				for path in dict["__removed"]:
					encode_string(path)
			elif key == "__selected":
				encode_byte(TYPES.SELECTION)			
				encode_byte(len(dict["__selected"]))		
				for path in dict["__selected"]:
					encode_string(path)
		else:			
			encode_byte(TYPES.NODEPATH)			
			encode_string(key)					
			for prop in dict[key]:
				if prop in ["position", "rotation", "scale"]:
					if prop == "position": encode_byte(TYPES.POSITION)				
					if prop == "rotation": encode_byte(TYPES.ROTATION)				
					if prop == "scale": encode_byte(TYPES.SCALE)																						
					encode_vector3(dict[key][prop])								
				elif prop == "type":
					encode_byte(TYPES.NODE_TYPE)										
					encode_byte(dict[key][prop])
				elif prop == "shape":
					encode_byte(TYPES.COLLISION_SHAPE)					
					encode_byte(dict[key][prop]['type'])						
					if dict[key][prop].has('x'): # box						
						encode_float(dict[key][prop]['x'])					
						encode_float(dict[key][prop]['y'])					
						encode_float(dict[key][prop]['z'])					
					elif dict[key][prop].has('height'): #capsule of cylinder
						encode_float(dict[key][prop]['radius'])
						encode_float(dict[key][prop]['height'])										
					else: #sphere
						encode_float(dict[key][prop]['radius'])											
				elif prop == "blend_file":
					encode_byte(TYPES.BLEND_FILE)					
					encode_string(dict[key][prop])					
				elif prop == "glb_name":
					encode_byte(TYPES.GLB_NAME)					
					encode_string(dict[key][prop])					
				elif prop == "meshcutoff":
					encode_byte(TYPES.MESH_CUTOFF)					
					encode_byte(dict[key][prop])										
				elif prop == "colcutoff":
					encode_byte(TYPES.COLLISION_CUTOFF)					
					encode_byte(dict[key][prop])										
				elif prop == "variation_layers":
					pass					
		
	data.encode_u32(0, head)	
	data.resize(head+1)
	
func unpack():
	dict = {}	
	head = 0
	#var data_size = data.decode_u32(head)
	#head += 4	
	var key_count = data.decode_u16(head)
	head += 2	
	var nodepath		
	for j in key_count:			
		var type = decode_byte()		
		if type == TYPES.NODEPATH: 
			nodepath = decode_string()															
			if not dict.has(nodepath): dict[nodepath] = {}			
			while head < len(data) and data.decode_u8(head) >=100: #100+ means object property in [TYPES.POSITION, TYPES.ROTATION, TYPES.SCALE, TYPES.NODE_TYPE]:
				var prop_type = decode_byte()								
				if prop_type == TYPES.POSITION: dict[nodepath].position = decode_vector3()
				elif prop_type == TYPES.ROTATION: dict[nodepath].rotation = decode_vector3()
				elif prop_type == TYPES.SCALE: dict[nodepath].scale = decode_vector3()
				elif prop_type == TYPES.NODE_TYPE: dict[nodepath].node_path = decode_byte()				
				elif prop_type == TYPES.COLLISION_SHAPE:
					var shape_type = decode_byte()					
					var shape: Shape3D
					if shape_type == TYPES.BOX:										
						shape = BoxShape3D.new()						
						shape.size = Vector3(decode_float(), decode_float(), decode_float())
					if shape_type in [TYPES.CYLINDER, TYPES.CAPSULE]:						
						if shape_type == TYPES.CYLINDER:
							shape = CylinderShape3D.new()
						if shape_type == TYPES.CAPSULE:
							shape = CapsuleShape3D.new()
						shape.radius = decode_float()
						shape.height = decode_float()
						
					else: #sphere
						shape = SphereShape3D.new()
						shape.radius = decode_float()
					dict[nodepath]["shape"] = shape
				elif prop_type == "blend_file":					
					dict[nodepath]["blend_file"] = decode_string()					
				elif prop_type == "glb_name":
					dict[nodepath]["blend_file"] = decode_string()					
				elif prop_type == "meshcutoff":
					dict[nodepath]["meshcutoff"] = decode_byte()															
				elif prop_type == "colcutoff":
					dict[nodepath]["colcutoff"] = decode_byte()																																
		elif type == TYPES.RENAMED:			
			if not dict.has("__renamed"):
				dict["__renamed"] = {}
			var count = decode_byte()		
			for i in count:				
				var from = decode_string()
				var to = decode_string()
				dict["__renamed"][from] = to
		elif type == TYPES.REMOVED:
			if not dict.has("__removed"):
				dict["__removed"] = PackedStringArray()
			var count = decode_byte()
			for i in count:
				dict["__removed"].push_back(decode_string())
		elif type == TYPES.SELECTION:			
			if not dict.has("__selected"):
				dict["__selected"] = PackedStringArray()
			var count = decode_byte()			
			for i in count:
				dict["__selected"].push_back(decode_string())				
		
		
