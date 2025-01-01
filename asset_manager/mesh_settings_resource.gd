@tool 
class_name MeshSettingsResource extends Resource
@export_enum("On", "Off", "Double-Sided", "Shadows only") var shadow_settings: int
@export_enum("Static", "Dynamic", "Off") var global_illumination_mode: int
@export_flags_3d_render var layers
