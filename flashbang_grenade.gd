extends RigidBody2D
class_name FlashbangGrenade

const radius := 400.0
const lifetime := 1.0
@onready var created_at := Util.get_ticks_sec()
@onready var collision_shape: CollisionShape2D = %CollisionShape
