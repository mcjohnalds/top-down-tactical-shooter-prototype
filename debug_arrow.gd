extends Node2D
class_name DebugArrow

const initial_length = 20.0
@onready var start: Node2D = %Start
@onready var end: Node2D = %End
@onready var graphic: Node2D = %Graphic


func _process(delta: float) -> void:
	graphic.global_position = start.global_position
	graphic.rotation = start.global_position.angle_to_point(end.global_position)
	graphic.scale = Vector2.ONE * start.global_position.distance_to(end.global_position) / initial_length
