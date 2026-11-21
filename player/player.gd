extends CharacterBody2D

signal eliminated(player)
const BULLET_SCENE = preload("res://weapons/bullet.tscn")

@export var player_number: int = 1

@export var move_speed: float = 350.0
@export var ground_accel: float = 2500.0
@export var ground_decel: float = 3000.0
@export var air_accel: float = 1500.0
@export var air_decel: float = 800.0
@export var jump_velocity: float = -600.0
@export var jump_cut: float = 0.5
@export var gravity: float = 1600.0
@export var fast_fall_gravity: float = 3200.0
@export var max_fall_speed: float = 700.0
@export var fast_fall_max_speed: float = 1000.0
@export var max_jumps: int = 2
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.1
@export var stocks: int = 3
@export var respawn_invuln_time: float = 2.0
@export var start_with_pistol: bool = true
@export var pistol: WeaponData 
@export var shove_damage: float = 3.0
@export var shove_knockback: float = 400.0 
@export var melee_cooldown: float = 0.4

var facing: int = 1
var jumps_left: int = 0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO
var damage_percent: float = 0.0
var invuln_timer: float = 0.0
var is_out: bool = false
var weapon: WeaponData = null
var ammo: int = 0
var attack_cooldown: float = 0.0
var shoot_action: String

var left_action: String
var right_action: String
var jump_action: String
var down_action: String

@onready var visual: Polygon2D = $Polygon2D
@onready var melee_area: Area2D = $MeleeArea


func _ready() -> void:
	add_to_group("players") 
	left_action = "p%d_left" % player_number
	right_action = "p%d_right" % player_number
	jump_action = "p%d_jump" % player_number
	down_action = "p%d_down" % player_number
	shoot_action = "p%d_shoot" % player_number
	equip_starting_weapon()
	
	
func _physics_process(delta: float) -> void:
	if invuln_timer > 0:
		invuln_timer -= delta
		visual.visible = int(invuln_timer * 10) % 2 == 0
	else:
		visual.visible = true
	
	if is_on_floor():
		jumps_left = max_jumps
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta
		if coyote_timer <= 0 and jumps_left == max_jumps:
			jumps_left = max_jumps - 1
	
	if Input.is_action_just_pressed(jump_action):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta
	
	var falling := velocity.y > 0
	if not is_on_floor() and falling and Input.is_action_pressed(down_action):
		velocity.y += fast_fall_gravity * delta
		velocity.y = min(velocity.y, fast_fall_max_speed)
	else:
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)

	if is_on_floor() and Input.is_action_just_pressed(down_action):
		var platform := get_one_way_floor()
		if platform:
			drop_through(platform)
			
	if jump_buffer_timer > 0 and jumps_left > 0:
		velocity.y = jump_velocity
		jumps_left -= 1
		jump_buffer_timer = 0
		coyote_timer = 0
		
	if Input.is_action_just_released(jump_action) and velocity.y < 0:
		velocity.y *= jump_cut
	
	var direction := Input.get_axis(left_action, right_action)
	if direction != 0:
		var accel := ground_accel if is_on_floor() else air_accel
		velocity.x = move_toward(velocity.x, direction * move_speed, accel * delta)
		facing = int(sign(direction))
	else: 
		var decel := ground_decel if is_on_floor() else air_decel
		velocity.x = move_toward(velocity.x, 0, decel * delta)
		
	visual.scale.x = facing
	
	
	melee_area.position.x = abs(melee_area.position.x) * facing

	attack_cooldown -= delta
	if Input.is_action_just_pressed(shoot_action) and attack_cooldown <= 0:
		attack()
	
	# knockback plugs
	
	move_and_slide()


func get_one_way_floor() -> Node:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision.get_normal().y < -0.5:
			var shape = collision.get_collider_shape()
			if shape is CollisionShape2D and shape.one_way_collision:
				return collision.get_collider()
	return null


func drop_through(platform: Node) -> void:
	add_collision_exception_with(platform)
	position.y += 2 
	await get_tree().create_timer(0.3).timeout
	remove_collision_exception_with(platform)


func ko() -> void:
	if is_out:
		return
	stocks -= 1
	print("Player %d KO'd! Stocks left: %d" % [player_number, stocks])

	if stocks <= 0:
		is_out = true
		hide()
		set_physics_process(false) 
		$CollisionShape2D.set_deferred("disabled", true)
		eliminated.emit(self)
	else:
		call_deferred("respawn")


func respawn() -> void:
	global_position = get_spawn_position()
	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	damage_percent = 0.0
	jumps_left = max_jumps
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	invuln_timer = respawn_invuln_time
	attack_cooldown = 0.0
	equip_starting_weapon()


func is_invulnerable() -> bool:
	return invuln_timer > 0


func get_spawn_position() -> Vector2:
	var points := get_tree().get_nodes_in_group("spawn_points")
	if points.is_empty():
		return Vector2(576, 100) 
	return points[(player_number - 1) % points.size()].global_position


func equip_starting_weapon() -> void:
	if start_with_pistol and pistol != null:
		weapon = pistol
		ammo = pistol.max_ammo
	else:
		weapon = null
		ammo = 0


func attack() -> void:
	var targets := get_enemies_in_reach()
	if weapon == null:
		melee(targets, shove_damage, shove_knockback, "shove")
	elif not targets.is_empty():
		melee(targets, weapon.melee_damage, weapon.knockback_strength, "pistol-whip")
	else:
		shoot()


func get_enemies_in_reach() -> Array:
	var result := []
	for body in melee_area.get_overlapping_bodies():
		if body != self and body.has_method("take_hit") and not body.is_invulnerable():
			result.append(body)
	return result


func melee(targets: Array, damage: float, knockback_strength: float, attack_name: String) -> void:
	attack_cooldown = melee_cooldown
	print("P%d used %s (%d target(s))" % [player_number, attack_name, targets.size()])
	for target in targets:
		target.take_hit(damage, Vector2(facing, 0), knockback_strength)


func shoot() -> void:
	attack_cooldown = weapon.cooldown
	var bullet: Bullet = BULLET_SCENE.instantiate()
	bullet.direction = Vector2(facing, 0)
	bullet.speed = weapon.bullet_speed
	bullet.damage = weapon.damage
	bullet.knockback_strength = weapon.knockback_strength
	bullet.shooter = self
	get_parent().add_child(bullet)
	bullet.global_position = global_position + Vector2(facing * 30, 0)
	
	ammo -= 1
	print("P%d fired. Ammo: %d/%d" % [player_number, ammo, weapon.max_ammo])
	if ammo <= 0:
		print("P%d is out of ammo, melee only" % player_number)
		weapon = null


func take_hit(damage: float, direction: Vector2, knockback_strength: float) -> void:
	if is_invulnerable() or is_out:
		return
	damage_percent += damage
	print("P%d hit! Damage: %.0f%%" % [player_number, damage_percent])
	# LATER: real knockback goes here, using damage_percent and
	# knockback_strength to set knockback_velocity.
	# For now, just a tiny nudge so you can see the hit land:
	velocity += direction * 150.0
