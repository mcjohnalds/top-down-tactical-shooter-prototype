extends CharacterBody2D
class_name Enemy

enum State { IDLE, ALERT, MOVING, DAZED, DEAD }
const reaction_time := 0.8
const daze_time := 3.0
@onready var body: Sprite2D = $Body
@onready var head: Sprite2D = $Head
@onready var gun: Sprite2D = %Gun
@onready var collision_shape: CollisionShape2D = %CollisionShape
@onready var navigation_agent: NavigationAgent2D = %NavigationAgent
@onready var initial_position := global_position
@onready var debug_arrow: DebugArrow = %DebugArrow
@onready var daze_stars: Node2D = %DazeStars
var last_fired_at := -1000.0
var alive := true
var state := State.IDLE
var reaction_time_remaining := reaction_time
var wait_between_move_time_remaining := 0.0
var daze_time_remaining := -1.0
var can_see_player := false
var see_player_position := Vector2.ZERO
var target_velocity := Vector2.ZERO
