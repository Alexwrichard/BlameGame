extends Node
class_name PostureManager

signal posture_changed(current, max)
signal charge_completed
signal dash_sustain_failed
signal posture_init(current, max)
signal crisis_started
signal crisis_ended

@export var stats: PostureStats

var current_posture: float
var is_in_crisis: bool = false
var is_guarding: bool = false
var is_hanging: bool = false
var is_wall_running: bool = false
var is_in_combat: bool = false
var is_charging: bool = false
var is_dashing: bool = false

@onready var parry_timer = $"../ParryWindowTimer"
@onready var lockout_timer = $"../CrisisLockoutTimer"

func _ready():
	current_posture = stats.max_posture
	GameEvents.request_player_stats.connect(_send_stats)

func _send_stats():
	GameEvents.posture_initialized.emit(stats.max_posture)

func _process(delta):
	if is_guarding and not is_in_crisis:
		damage_posture(stats.guard_sustain_drain * delta)
	if is_hanging:
		damage_posture(stats.hanging_drain * delta)
	if is_wall_running:
		damage_posture(stats.wall_run_drain * delta)
	if is_charging:
		if current_posture >= stats.current_max_posture:
			_auto_stop_charging()
			return
		gain_posture(stats.charging_gain * delta)
		damage_max_posture(stats.max_charging_drain * delta)
	if is_dashing:
		if is_in_crisis: GameEvents.dash_sustain_failed.emit
		damage_posture(stats.dash_sustain_drain * delta)


func start_dash_sustain():
	is_dashing = true
	
func stop_dash_sustain():
	is_dashing = false

func start_dash():
	is_dashing = true

func stop_dash():
	is_dashing = false

func start_guarding():
	is_guarding = true

func stop_guarding():
	is_guarding = false
	
func start_charging():
	if _is_full(): return
	is_charging = true

func stop_charging():
	is_charging = false
	
func start_wall_hang():
	is_hanging = true

func stop_wall_hang():
	is_hanging = false

func start_wall_run():
	is_wall_running = true

func stop_wall_run():
	is_wall_running = false
	
func _auto_stop_charging():
	is_charging = false
	current_posture = stats.current_max_posture # Snap to perfect max
	charge_completed.emit() 
	# This signal tells the Motor to switch ActionState back to NONE

func damage_max_posture(amount: float):
	stats.current_max_posture = max(10, stats.current_max_posture - amount)
	GameEvents.posture_changed.emit(current_posture, stats.current_max_posture)
	print(stats.max_charging_drain)

func damage_posture(amount: float):
	current_posture = max(0, current_posture - amount)
	GameEvents.posture_changed.emit(current_posture, stats.current_max_posture)
	
	if current_posture <= 0 and not is_in_crisis:
		_enter_crisis()
		
func gain_posture(amount: float):
	current_posture = min(stats.current_max_posture, current_posture + amount)
	GameEvents.posture_changed.emit(current_posture, stats.current_max_posture)
	
	if is_in_crisis and current_posture >= stats.current_max_posture:
		_exit_crisis()

func apply_guard_tap_tax():
	if is_in_crisis: return
	damage_posture(stats.guard_tap_cost)
	parry_timer.start()

func apply_dash_tap_tax():
	if is_in_crisis: return
	damage_posture(stats.dash_tap_cost)

func _enter_crisis():
	is_in_crisis = true
	crisis_started.emit()

func _exit_crisis():
	is_in_crisis = false
	crisis_ended.emit()

func _is_full():
	return current_posture >= stats.current_max_posture
