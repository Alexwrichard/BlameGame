extends Node

@onready var motor: ActorMotor = get_parent()

func _physics_process(delta: float):
	if not motor: return
	
	# Gather Input
	var hor_direction = Input.get_axis("move_left", "move_right")
	var ver_direction = Input.get_axis("move_up", "move_down")
	var jumping = Input.is_action_just_pressed("jump")
	var jump_held = Input.is_action_pressed("jump")
	
	# Send to Motor
	motor.handle_physics(hor_direction, ver_direction, jumping, jump_held, delta)
	# Combat Input
	if Input.is_action_just_pressed("guard"):
		motor.start_guard()
	if Input.is_action_just_released("guard"):
		motor.stop_guard()
	if Input.is_action_just_pressed("attack"):
		motor.start_attack()
	if Input.is_action_just_released("attack"):
		motor.stop_attack()
	if Input.is_action_just_pressed("charge"):
		motor.start_charge()
	if Input.is_action_just_released("charge"):
		motor.stop_charge()
		
	if Input.is_action_just_pressed("dash"):
		motor.start_dash(hor_direction, ver_direction)
	#if Input.is_action_just_released("dash"):
	#	motor.stop_dash()
	
	
