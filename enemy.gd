extends CharacterBody2D
class_name Enemy

enum State { IDLE, ALERT, MOVING }
const reaction_time = 0.8
@onready var body: Sprite2D = $Body
@onready var head: Sprite2D = $Head
@onready var gun: Sprite2D = %Gun
@onready var collision_shape: CollisionShape2D = %CollisionShape
@onready var navigation_agent: NavigationAgent2D = %NavigationAgent
@onready var initial_position := global_position
@onready var debug_arrow: DebugArrow = %DebugArrow
var last_fired_at := -1000.0
var alive := true
var state := State.IDLE
var reaction_time_remaining := reaction_time
var wait_between_move_time_remaining: float
