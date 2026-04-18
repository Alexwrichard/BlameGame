extends CharacterBody2D
class_name ActorMotor

@export_group("Horizontal Movement")
@export var speed = 6000.0
@export var accel = 6000.0
@export var friction = 23000.0

@export_group("Vertical Movement")
@export var wall_run_mult = 12
@export var terminal_velocity: float = 100000.0 

@export_group("Jump Geometry")
@export var jump_height: float = 1800
@export var time_to_jump: float = 0.33
@export var time_to_fall: float = 0.25
@export var wall_jump_mult: float = .7
@export var dash_impulse: float = 18000.0

@export_group("Mantle System")
@export var mantle_impulse_v: float = -4000.0 
@export var mantle_impulse_h: float = 4500.0   
@export var wall_jump_reset_dist: float = 200.0

# Power Permissions
@export_group("Permissions")
@export var wall_jump_max: int = 1
@export var double_jump_max: int = 1
@export var air_dash_max: int = 1
@export var allow_wall_hang: bool = true
@export var allow_wall_run: bool = true

# Physics State
var jump_velocity: float
var jump_gravity: float
var fall_gravity: float
var double_jump_count = 0
var wall_jump_count = 0
var last_wall_side = 0
var was_on_floor = false
var was_wall_running: bool = false
var last_wall_jump_x: float = 0.0
var was_feet_colliding: bool = false
var mantle_primed: bool = false
var last_known_wall_side: int = 0
var mantle_capable: bool = true
var wall_run_start: bool = false
var air_dash_count = 0

# Nodes
@onready var posture = $PostureManager
@onready var ray_head_right = $RightHeadRay
@onready var ray_head_left = $LeftHeadRay
@onready var ray_chest_right = $RightChestRay
@onready var ray_chest_left = $LeftChestRay
@onready var ray_foot_right = $RightFootRay
@onready var ray_foot_left = $LeftFootRay
@onready var coyote_timer = $CoyoteTimer
@onready var jump_buffer = $JumpBufferTimer
@onready var dash_timer = $DashTimer

# State Enums
enum MovementState { IDLE, MOVE, JUMPING, AIRBORNE, WALL_RUN, WALL_HANG, WALL_SLIDE }
enum ActionState { NONE, DASH, CHARGE, GUARD, ATTACK }

var current_move_state = MovementState.IDLE
var current_action_state = ActionState.NONE

func _ready():
	_calculate_physics()
	posture.charge_completed.connect(stop_charge)
	dash_timer.timeout.connect(_on_dash_timer_timeout)
	$AnimationPlayer.play("Idle")

func _calculate_physics():
	jump_gravity = (2.0 * jump_height) / pow(time_to_jump, 2)
	fall_gravity = (2.0 * jump_height) / pow(time_to_fall, 2)
	jump_velocity = (-2.0 * jump_height) / time_to_jump

## --- PUBLIC API FOR CONTROLLER ---

func handle_physics(h_dir: float, v_dir: float, jump_pressed: bool, jump_held: bool, delta: float):
	if jump_pressed:
		jump_buffer.start()
	
	if was_on_floor and not is_on_floor() and velocity.y >= 0:
		coyote_timer.start()

	_update_states(h_dir, v_dir)
	_apply_gravity(jump_held, h_dir, delta)
	_handle_horizontal_movement(h_dir, delta)
	_handle_vertical_movement(v_dir, delta)
	_process_jump_logic()
	
	was_on_floor = is_on_floor()
	move_and_slide()

## --- ACTION API ---

func start_guard():
	if current_move_state == MovementState.WALL_RUN: return
	current_action_state = ActionState.GUARD
	posture.apply_guard_tap_tax()
	posture.start_guarding()

func stop_guard():
	if current_action_state == ActionState.GUARD:
		current_action_state = ActionState.NONE
		posture.stop_guarding()

func start_charge():
	if posture._is_full() or !is_on_floor(): return
	current_action_state = ActionState.CHARGE
	posture.start_charging()

func stop_charge():
	if current_action_state == ActionState.CHARGE:
		current_action_state = ActionState.NONE
		posture.stop_charging()

## --- INTERNAL PHYSICS LOGIC ---

func _update_states(h_dir: float, v_dir: float):
	if current_action_state == ActionState.DASH: return
	var chest_colliding = _is_chest_colliding()
	var feet_colliding = _is_feet_colliding()
	var near_wall = _is_near_wall()
	
	if _is_right_colliding(): last_known_wall_side = 1
	elif _is_left_colliding(): last_known_wall_side = -1

	var previous_move_state = current_move_state

	if is_on_floor():
		current_move_state = MovementState.MOVE if h_dir != 0 else MovementState.IDLE
		mantle_primed = false
		last_known_wall_side = 0
	if near_wall:
		# WALL RUN UP (Requires permission and posture)
		if allow_wall_run and v_dir < 0:
			if not wall_run_start and not chest_colliding:
				current_move_state = MovementState.AIRBORNE
			else:
				if chest_colliding: wall_run_start = true
				current_move_state = MovementState.WALL_RUN
		
		# WALL SLIDE DOWN (Free, no permission required)
		elif v_dir > 0:
			current_move_state = MovementState.WALL_SLIDE
			
		# WALL HANG
		elif allow_wall_hang and h_dir == last_known_wall_side:
			current_move_state = MovementState.WALL_HANG
		else:
			current_move_state = MovementState.AIRBORNE
	else:
		current_move_state = MovementState.AIRBORNE
		wall_run_start = false

	# POSTURE SYNC
	if current_move_state != previous_move_state:
		# Always stop previous state effects
		if previous_move_state == MovementState.WALL_RUN: posture.stop_wall_run()
		if previous_move_state == MovementState.WALL_HANG: posture.stop_wall_hang()
		
		# Only start posture effects for WALL_RUN (up) and WALL_HANG
		if current_move_state == MovementState.WALL_RUN: posture.start_wall_run()
		if current_move_state == MovementState.WALL_HANG: posture.start_wall_hang()

	# MANTLE LOGIC
	if chest_colliding and feet_colliding:
		mantle_capable = true
	if not chest_colliding and feet_colliding and mantle_capable:
		mantle_primed = true
	if mantle_primed and was_feet_colliding and not feet_colliding:
		var holding_toward = (h_dir == last_known_wall_side or h_dir == 0)
		var moving_toward = (sign(velocity.x) == last_known_wall_side or velocity.x == 0)
		if v_dir < 0 and holding_toward and moving_toward and jump_buffer.is_stopped():
			_execute_mantle(h_dir)
	if chest_colliding:
		mantle_primed = false
	was_feet_colliding = feet_colliding

func _handle_vertical_movement(v_dir: float, delta: float):
	# Apply controlled movement if in any active wall state
	if current_action_state == ActionState.DASH: return
	var is_wall_moving = current_move_state in [MovementState.WALL_RUN, MovementState.WALL_SLIDE]
	
	if is_wall_moving:
		var mult = (friction + accel * 0.1)
		velocity.y = move_toward(velocity.y, v_dir * speed, mult * delta * wall_run_mult)

func _apply_gravity(is_jump_held: bool, h_dir: float, delta: float):
	if is_on_floor():
		#velocity.y = 0
		wall_jump_count = 0
		double_jump_count = 0
		last_wall_side = 0
		air_dash_count = 0
		return
		
	if not dash_timer.is_stopped():
		return
	
	# Skip gravity for all wall states so handle_vertical_movement has full control
	var is_wall_state = current_move_state in [MovementState.WALL_RUN, MovementState.WALL_HANG, MovementState.WALL_SLIDE]
	
	if is_wall_state:
		velocity.y = 0
		return

	var gravity = jump_gravity if (velocity.y < 0 and is_jump_held) else fall_gravity
	velocity.y += gravity * delta
	velocity.y = min(velocity.y, terminal_velocity)
	
	if _is_near_wall() and velocity.y > 0:
		velocity.y = min(velocity.y, 1000.0)

## --- HELPERS & JUMP LOGIC ---

func _is_chest_colliding():
	return ray_chest_right.is_colliding() or ray_chest_left.is_colliding()

func _is_feet_colliding():
	return ray_foot_right.is_colliding() or ray_foot_left.is_colliding()

func _is_near_wall() -> bool:
	return _is_right_colliding() or _is_left_colliding()

func _is_right_colliding() -> bool:
	return ray_chest_right.is_colliding() or ray_foot_right.is_colliding()

func _is_left_colliding() -> bool:
	return ray_chest_left.is_colliding() or ray_foot_left.is_colliding()

func _execute_mantle(h_dir):
	if last_known_wall_side == 0: return
	mantle_primed = false
	var push_dir = last_known_wall_side
	velocity.y = mantle_impulse_v
	velocity.x = push_dir * (mantle_impulse_h/3 if h_dir != 0 else mantle_impulse_h)
	mantle_capable = false
	posture.stop_wall_run()

func _process_jump_logic():
	if not jump_buffer.is_stopped():
		if (is_on_floor() or (double_jump_count < double_jump_max and !_is_near_wall()) or not coyote_timer.is_stopped()):
			_execute_normal_jump()
		
		elif _is_near_wall():
			var current_side = 1 if _is_right_colliding() else -1
			var distance_from_last_jump = abs(global_position.x - last_wall_jump_x)
			
			# REFRESH LOGIC: 
			# Reset if we touch the OPPOSITE side OR if we have moved far enough horizontally
			if current_side != last_wall_side or distance_from_last_jump >= wall_jump_reset_dist:
				wall_jump_count = 0
			
			if wall_jump_count < wall_jump_max:
				_execute_wall_jump(current_side)

func _execute_normal_jump():
	velocity.y = jump_velocity
	if !is_on_floor():
		double_jump_count += 1
	jump_buffer.stop()
	coyote_timer.stop()

func _execute_wall_jump(wall_side: int):
	# Update the "Memory"
	last_wall_side = wall_side
	last_wall_jump_x = global_position.x # Store the X coordinate of this jump
	
	wall_jump_count += 1
	
	# Apply forces
	velocity.x = -wall_side * (abs(jump_velocity)) * wall_jump_mult
	velocity.y = jump_velocity * wall_jump_mult
	
	jump_buffer.stop()
	coyote_timer.stop()

func _handle_horizontal_movement(h_dir: float, delta: float):
	if not dash_timer.is_stopped():
		return
	var effective_speed = speed
	if (current_action_state == ActionState.GUARD or current_action_state == ActionState.ATTACK) and is_on_floor():
		effective_speed *= 0
	elif current_action_state == ActionState.CHARGE:
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		return

	if h_dir != 0:
		var mult = (friction + accel) if (h_dir > 0 and velocity.x < 0) or (h_dir < 0 and velocity.x > 0) else accel
		velocity.x = move_toward(velocity.x, h_dir * effective_speed, mult * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)

func start_dash(h_dir: float, v_dir: float):
	if current_action_state == ActionState.DASH or posture.is_in_crisis: return
	
	# Air Dash Permission Check
	if not is_on_floor():
		if air_dash_count >= air_dash_max: return
		air_dash_count += 1
	
	current_action_state = ActionState.DASH
	posture.apply_dash_tap_tax()
	# Directional Logic
	if h_dir == 0 and v_dir == 0:
		h_dir = last_known_wall_side if last_known_wall_side != 0 else 1.0
	
	var dash_vec = Vector2(h_dir, v_dir).normalized()
	velocity = dash_vec * dash_impulse
	
	# Disable character collision
	set_collision_mask_value(2, false)
	
	# Posture costs (if applicable)
	posture.apply_dash_tap_tax()
	
	dash_timer.start()

func _on_dash_timer_timeout():
	current_action_state = ActionState.NONE
	set_collision_mask_value(2, true)
	
	# Optional: "Snap" velocity to stop the instant the timer ends
	velocity = velocity * 0.4
