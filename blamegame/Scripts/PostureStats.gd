extends Resource

class_name PostureStats

@export_group("Capacity")
@export var max_posture: float = 100;
@export var current_max_posture: float = 100;

@export_group("Costs")
@export var guard_tap_cost: float = 2;
@export var guard_sustain_drain: float = .2;
@export var dash_tap_cost: float = 0;
@export var dash_sustain_drain: float = 1
@export var hanging_drain: float = .1;
@export var wall_run_drain: float = 1;
@export var max_charging_drain: float = 10;

@export_group("Recovery")
@export var parry_gain: float = 5;
@export var charging_gain: float = 5;
