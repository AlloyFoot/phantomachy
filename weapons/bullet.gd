class_name Bullet
extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 900.0
var damage: float = 5.0
var knockback_strength: float = 0.0
var shooter: Node = null

@export var lifetime: float = 1.5


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body == shooter:
		return
	if body.has_method("take_hit"):
		if body.is_invulnerable():
			return
		body.take_hit(damage, direction, knockback_strength)
	queue_free()
