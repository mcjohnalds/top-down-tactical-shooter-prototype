extends Node2D
class_name Bullet

const initial_length = 20.0
const lifetime = 0.2


@export var start := Vector2.ZERO:
	set(value):
		start = value
		if not is_node_ready():
			await ready
		_update()


@export var end := Vector2.ZERO:
	set(value):
		end = value
		if not is_node_ready():
			await ready
		_update()


@onready var created_at := Util.get_ticks_sec()


func _process(delta: float) -> void:
	var time := Util.get_ticks_sec()
	var p := 1.0 - (time - created_at) / lifetime
	modulate.a = p
	if p <= 0.0:
		queue_free()


func _update() -> void:
	position = start
	rotation = start.angle_to_point(end)
	scale.x = start.distance_to(end) / initial_length
