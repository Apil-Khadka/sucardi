# track_01.gd
extends Node3D


@onready var car = $car
func _ready():
	car.STEER_SPEED = 30
	car.STEER_LIMIT = 0.8
	car.engine_force_value = 80
	if OS.get_name() != "Android":
		prints(OS.get_name());
		return
