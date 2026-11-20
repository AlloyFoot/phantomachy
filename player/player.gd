extends CharacterBody2D


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

var facing: int = 1
var jumps_left: int = 0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO

var left_action: String
var right_action: String
var jump_action: String
var down_action: String

@onready var visual: Polygon2D = $Polygon2D


func _ready() -> void:
	left_action = "p%d_left" % player_number
	right_action = "p%d_right" % player_number
	jump_action = "p%d_jump" % player_number
	down_action = "p%d_down" % player_number
	
	
func _physics_process(delta: float) -> void:
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

	# --- Drop through one-way platforms ---
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
