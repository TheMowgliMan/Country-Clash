extends KinematicBody2D

# COPY: This entire script is copied from the Godot docs

export (int) var speed = 200

var velocity = Vector2()

func get_input():
	velocity = Vector2()
	if Input.is_action_pressed("right"):
		velocity.x += 1
	if Input.is_action_pressed("left"):
		velocity.x -= 1
	if Input.is_action_pressed("down"):
		velocity.y += 1
	if Input.is_action_pressed("up"):
		velocity.y -= 1
	velocity = velocity.normalized() * (speed / get_node("..").map_scale)

func _physics_process(delta):
	get_input()
	velocity = move_and_slide(velocity)
