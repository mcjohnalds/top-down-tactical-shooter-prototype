extends Control
class_name Main

const fire_rate = 0.1
const visibility_distance := 98.0
const player_field_of_view := deg_to_rad(120.0)
const laser_length := 100.0
@export var bullet_scene: PackedScene
@export var enemy_scene: PackedScene
@export var flashbang_grenade_scene: PackedScene
@export var flashbang_light_scene: PackedScene
@onready var player: CharacterBody2D = %Player
@onready var player_circle: CircleShape2D = %Player/CollisionShape.shape
@onready var player_body: Sprite2D = %Player/Body
@onready var player_gun: Sprite2D = %Player/Gun
@onready var player_head: Sprite2D = %Player/Head
@onready var debug_point: Sprite2D = %DebugPoint
@onready var enemies_node: Node2D = %Enemies
@onready var bullets_node: Node2D = %Bullets
@onready var global_light: PointLight2D = %GlobalLight
@onready var unrevealed_tile_map: TileMap = %UnrevealedTileMap
@onready var revealed_tile_map: TileMap = %RevealedTileMap
@onready var navigation_region: NavigationRegion2D = %NavigationRegion
@onready var laser: Node2D = %Laser
@onready var fov_light: Light2D = %FovLight
@onready var grenades_node: Node2D = %Grenades
@onready var flashbang_lights_node: Node2D = %FlashbangLights
@onready var root_2d: Node2D = %Root2D
var player_last_fired_at := -1000.0
var player_has_been_detected := false


func _ready() -> void:
	var width := 50
	var height := 50
	unrevealed_tile_map.clear()
	var rows: Array = DungeonGenerator.generate_dungeon(width, height)
	for i in height:
		for j in width:
			var layer := 0
			var source_id := 2
			var coords := Vector2i(j, i)
			var atlas_coords := Vector2i(1 if rows[i][j] else 0, 0)
			unrevealed_tile_map.set_cell(
				layer, coords, source_id, atlas_coords
			)
	var has_person := {}
	while true:
		var x := randi_range(0, width - 1)
		var y := randi_range(0, height - 1)
		var map_pos := Vector2i(x, y)
		has_person[map_pos] = true
		if not rows[y][x]:
			player.position = unrevealed_tile_map.map_to_local(map_pos)
			break
	navigation_region.bake_navigation_polygon(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var enemies := 50
	for i in enemies:
		while true:
			var x := randi_range(0, width - 1)
			var y := randi_range(0, height - 1)
			var map_pos := Vector2i(x, y)
			var local_pos := unrevealed_tile_map.map_to_local(map_pos)
			if (
				not rows[y][x]
				and not enemy_see_player_ray_cast(local_pos, 1000.0)
				and not has_person.has(map_pos)
			):
				var enemy: Enemy = enemy_scene.instantiate()
				enemy.position = local_pos
				enemies_node.add_child(enemy)
				has_person[map_pos] = true
				break


func _physics_process(delta: float) -> void:
	if root_2d.process_mode == PROCESS_MODE_DISABLED:
		return
	_update_player_movement(delta)
	_update_player_shooting()
	_update_player_tile_reveal()
	_update_player_laser()
	for enemy: Enemy in enemies_node.get_children():
		_update_enemy(enemy, delta)
		if root_2d.process_mode == PROCESS_MODE_DISABLED:
			return
	for g: FlashbangGrenade in grenades_node.get_children():
		_update_flashbang_grenade(g, delta)
	for fl: FlashbangLight in flashbang_lights_node.get_children():
		_update_flashbang_light(fl, delta)


func _update_player_movement(delta: float) -> void:
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var a := 25.0 if input_dir.is_zero_approx() else 14.0
	player.velocity = player.velocity.lerp(input_dir * 100.0, delta * a)
	player.move_and_slide()
	player.rotation = player.global_position.angle_to_point(
		root_2d.get_global_mouse_position()
	)


func _update_player_shooting() -> void:
	var time := Util.get_ticks_sec()
	if (
		Input.is_action_pressed("shoot")
		and time - player_last_fired_at > fire_rate
	):
		player_last_fired_at = time
		# TODO: specify bullet direction to be mouse
		var hit := fire_bullet(player, root_2d.get_global_mouse_position())
		if hit is Enemy:
			var enemy: Enemy = hit
			enemy.daze_stars.visible = false
			enemy.body.modulate = Color(0.8, 0.2, 0.2, 0.5)
			enemy.gun.modulate = Color(0.8, 0.2, 0.2, 0.5)
			enemy.head.modulate = Color(0.8, 0.2, 0.2, 0.5)
			enemy.process_mode = PROCESS_MODE_DISABLED
		for enemy: Enemy in enemies_node.get_children():
			if enemy.process_mode == PROCESS_MODE_DISABLED:
				continue
			player_has_been_detected = true
			# TODO: 0.2 may be too small
			if (
				enemy.reaction_time_remaining > 0.2
				and not enemy_see_player_ray_cast(
					enemy.global_position, visibility_distance
				)
			):
				enemy.reaction_time_remaining = 0.2


func _update_player_tile_reveal() -> void:
	var angle_samples := 100
	for i in angle_samples:
		var angle := (
			player_field_of_view * (0.5 - float(i) / float(angle_samples - 1))
		)
		var query := PhysicsRayQueryParameters2D.new()
		query.from = player.global_position
		var dir := Vector2.from_angle(player.global_rotation + angle)
		query.to = player.global_position + dir * visibility_distance
		var collision := (
			root_2d.get_world_2d().direct_space_state.intersect_ray(query)
		)
		var point: Vector2 = (
			collision.position if 
				collision and collision.collider == unrevealed_tile_map
			else query.to
		)
		var line_samples := 100
		for j in line_samples:
			var layer := 0
			var source_id := 2
			var local_pos := query.from.lerp(
				point, float(j) / float(line_samples - 1) * 1.01
			)
			var coords := unrevealed_tile_map.local_to_map(local_pos)
			var atlas_coords := unrevealed_tile_map.get_cell_atlas_coords(
				layer, coords
			)
			var alternative_id := 2
			revealed_tile_map.set_cell(
				layer, coords, source_id, atlas_coords, alternative_id
			)


func _update_player_laser() -> void:
	var query = PhysicsRayQueryParameters2D.new()
	query.from = player.global_position
	query.to = (
		player.global_position
		+ player.global_transform.x * visibility_distance
	)
	var collision = (
		root_2d.get_world_2d().direct_space_state.intersect_ray(query)
	)
	if collision:
		laser.scale.x = collision.position.distance_to(query.from) / 100.0
	else:
		laser.scale.x = visibility_distance / 100.0


func _update_enemy(enemy: Enemy, delta: float) -> void:
	if enemy.process_mode == PROCESS_MODE_DISABLED:
		return

	# Daze time coundown
	if enemy.daze_time_remaining > 0.0:
		enemy.daze_time_remaining -= delta
		enemy.daze_stars.visible = true
		enemy.daze_stars.rotation += TAU * delta
		return
	else:
		enemy.daze_stars.visible = false

	var seen_player_pos := enemy_see_player_ray_cast(
		enemy.global_position, visibility_distance
	)

	# Reaction time countdown
	if seen_player_pos:
		enemy.reaction_time_remaining -= delta
	else:
		enemy.reaction_time_remaining += enemy.reaction_time
	enemy.reaction_time_remaining = clampf(
		enemy.reaction_time_remaining, 0.0, enemy.reaction_time
	)

	# Rotation
	if seen_player_pos:
		enemy.rotation = enemy.global_position.angle_to_point(seen_player_pos)

	# Shooting
	var time := Util.get_ticks_sec()
	if (
		seen_player_pos
		and time - enemy.last_fired_at > fire_rate
		and enemy.reaction_time_remaining == 0.0
	):
		enemy.last_fired_at = time
		var hit := fire_bullet(enemy, seen_player_pos)
		if hit == player:
			player_body.modulate = Color(0.0, 0.0, 0.8, 0.9)
			player_gun.modulate = Color(0.0, 0.0, 0.8, 0.9)
			player_head.modulate = Color(0.0, 0.0, 0.8, 0.9)
			fov_light.visible = false
			laser.visible = false
			global_light.visible = true
			revealed_tile_map.visible = false
			root_2d.process_mode = Node.PROCESS_MODE_DISABLED
			return

	# AI state machine
	var target_velocity := Vector2.ZERO
	match enemy.state:
		Enemy.State.IDLE:
			if seen_player_pos:
				player_has_been_detected = true
			if player_has_been_detected:
				enemy.state = Enemy.State.ALERT
		Enemy.State.ALERT:
			enemy.wait_between_move_time_remaining -= delta
			if enemy.wait_between_move_time_remaining <= 0.0:
				enemy.state = Enemy.State.MOVING
				var angle := TAU * randf()
				var distance := randf_range(20.0, 50.0)
				var random_pos := (
					enemy.initial_position
					+ Vector2.from_angle(angle) * distance
				)
				enemy.navigation_agent.target_position = random_pos
		Enemy.State.MOVING:
			var next := enemy.navigation_agent.get_next_path_position()
			target_velocity = enemy.position.direction_to(next) * 80.0
			enemy.debug_arrow.start.global_position = enemy.global_position
			enemy.debug_arrow.end.global_position = next
			if enemy.navigation_agent.is_navigation_finished():
				enemy.state = Enemy.State.ALERT
				enemy.wait_between_move_time_remaining = randf_range(1.0, 10.0)

	# Physics
	var accel := 1.0 if target_velocity else 6.0
	enemy.velocity = enemy.velocity.lerp(target_velocity, delta * accel)
	enemy.move_and_slide()


func _update_flashbang_grenade(fg: FlashbangGrenade, delta: float) -> void:
	fg.linear_velocity = fg.linear_velocity - fg.linear_velocity * 1.5 * delta
	if Util.get_ticks_sec() - fg.created_at > fg.lifetime:
		fg.queue_free()
		var light: FlashbangLight = flashbang_light_scene.instantiate()
		light.position = fg.position
		flashbang_lights_node.add_child(light)
		for enemy: Enemy in enemies_node.get_children():
			if enemy.process_mode == PROCESS_MODE_DISABLED:
				continue
			var query := PhysicsRayQueryParameters2D.new()
			query.from = fg.global_position
			var dir := fg.global_position.direction_to(enemy.global_position)
			query.to = query.from + dir * fg.radius
			query.exclude = [fg]
			var collision := (
				root_2d.get_world_2d().direct_space_state.intersect_ray(query)
			)
			if collision and collision.collider == enemy:
				enemy.daze_time_remaining = enemy.daze_time
				enemy.reaction_time_remaining = enemy.reaction_time


func _update_flashbang_light(lg: FlashbangLight, delta: float) -> void:
	lg.sprite.modulate.a -= delta / 0.2
	if lg.sprite.modulate.a <= 0.0:
		lg.queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("quit"):
		get_tree().quit()
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
	if (
		root_2d.process_mode != PROCESS_MODE_DISABLED
		and event.is_action_pressed("secondary")
	):
		player_has_been_detected = true
		var g: FlashbangGrenade = flashbang_grenade_scene.instantiate()
		g.add_collision_exception_with(player)
		g.position = player.global_position
		g.linear_velocity = (
			4.0
			* (root_2d.get_global_mouse_position() - player.global_position)
		)
		g.angular_velocity = 6.0
		grenades_node.add_child(g)


func enemy_see_player_ray_cast(
	enemy_position: Vector2, distance: float
) -> Vector2:
	var p1 := enemy_position
	var p2 := player.global_position
	var o := p1.direction_to(p2).orthogonal()
	var r := player_circle.radius
	var see_player_positions: Array[Vector2] = []
	var samples := 100
	for i in samples:
		var query := PhysicsRayQueryParameters2D.new()
		query.from = p1
		var d := 1.0 - 2.0 * float(i) / float(samples - 1)
		var v := (p2 + o * r * d) - p1
		query.to = p1 + v.limit_length(distance)
		var collision := (
			root_2d.get_world_2d().direct_space_state.intersect_ray(query)
		)
		if collision and collision.collider == player:
			see_player_positions.append(query.to)
	if not see_player_positions.is_empty():
		var pos_sum := Vector2.ZERO
		for pos in see_player_positions:
			pos_sum += pos
		var pos_avg := pos_sum / see_player_positions.size()
		return pos_avg
	return Vector2.ZERO


func fire_bullet(shooter: PhysicsBody2D, target: Vector2) -> Node2D:
	var query = PhysicsRayQueryParameters2D.new()
	query.from = shooter.global_position
	var dir := target - shooter.global_position
	query.to = shooter.global_position + dir * 1000.0
	query.exclude = [shooter]
	var collision := (
		root_2d.get_world_2d().direct_space_state.intersect_ray(query)
	)
	var bullet: Bullet = bullet_scene.instantiate()
	bullet.start = query.from
	if collision:
		bullet.end = collision.position
	else:
		bullet.end = query.to
	bullets_node.add_child(bullet)
	return collision.collider if collision else null
