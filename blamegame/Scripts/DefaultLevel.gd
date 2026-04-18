extends Node

func _ready():
	$CanvasLayer/PostureBar/RightPostureBar.setup_manager($Player/PostureManager)
	$CanvasLayer/PostureBar/LeftPostureBar.setup_manager($Player/PostureManager)
