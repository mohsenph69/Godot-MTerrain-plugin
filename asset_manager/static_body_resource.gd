@tool 
class_name StaticBodyResource extends Resource
@export var friction: float
@export var rough: float
@export var bounce: float
@export var absorbent: float
@export var constant_linear_velocity: float
@export var constant_angular_velocity: float
@export_group("Axis Lock")
@export var axis_lock_linear_x: bool
@export var axis_lock_linear_y: bool
@export var axis_lock_linear_z: bool
@export var axis_lock_angular_x: bool
@export var axis_lock_angular_y: bool
@export var axis_lock_angular_z: bool
@export_group("Collision")
@export_enum("Remove", "Make Static", "Make Active") var disable_mode: int
@export_flags_3d_physics var collision_layer: int
@export_flags_3d_physics var collision_mask: int
@export var collision_priority: int
