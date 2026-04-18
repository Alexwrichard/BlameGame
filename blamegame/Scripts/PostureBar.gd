extends ProgressBar

@onready var timer = $Timer
@onready var damage_bar = $DamageBar
@onready var size_multipler = 5

func _ready():
	# Connect to both signals
	GameEvents.posture_initialized.connect(init_posture)
	GameEvents.posture_changed.connect(_on_posture_changed)
	GameEvents.request_player_stats.emit()

func setup_manager(manager: PostureManager):
	# Connect signals from the manager to this bar
	manager.posture_changed.connect(_on_posture_changed)
	manager.crisis_started.connect(_on_crisis_started)

func init_posture(max_val):
	custom_minimum_size.x = size_multipler*max_val
	damage_bar.custom_minimum_size.x = custom_minimum_size.x
	value = max_val
	damage_bar.value = max_val

func _on_posture_changed(current, max_val):
	if max_value != max_val:
		max_value = max_val
		damage_bar.max_value = max_val
	custom_minimum_size.x = size_multipler*max_val
	damage_bar.custom_minimum_size.x = custom_minimum_size.x
		
	var prev_value = value
	value = current
	
	if current < prev_value:
		timer.start()
	else:
		damage_bar.value = current

func _on_crisis_started():
	# Visual flare for when posture breaks
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.RED, 0.1).from(Color.WHITE)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

func _on_timer_timeout():
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(damage_bar, "value", value, 0.5)
	damage_bar.value = value
