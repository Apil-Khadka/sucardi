extends Node3D

@onready var up = $up
@onready var down = $down
@onready var left = $left
@onready var right = $right
@onready var brake = $brake
@onready var car = $car
func _ready():
	car.STEER_SPEED = 30
	car.STEER_LIMIT = 0.8
	car.engine_force_value = 80
	if OS.get_name() != "Android":
		prints(OS.get_name());
		return
	#up.pressed.connect(_on_up_pressed)
	#up.released.connect(_on_up_released)
	#
	#down.pressed.connect(_on_down_pressed)
	#down.released.connect(_on_down_released)
	#
	#left.pressed.connect(_on_left_pressed)
	#left.released.connect(_on_left_released)
	#
	#right.pressed.connect(_on_right_pressed)
	#right.released.connect(_on_right_released)
	#
	#brake.pressed.connect(_on_brake_pressed)
	#brake.released.connect(_on_brake_released)

# Modify the VehicleBody3D properties directly

func _on_up_pressed():
	car.engine_force = -car.engine_force_value  # Forward movement

func _on_up_released():
	car.engine_force = 0

func _on_down_pressed():
	car.engine_force = car.engine_force_value  # Reverse movement

func _on_down_released():
	car.engine_force = 0

func _on_left_pressed():
	car.steer_target = car.STEER_LIMIT  # Turn left

func _on_left_released():
	car.steer_target = 0

func _on_right_pressed():
	car.steer_target = -car.STEER_LIMIT  # Turn right

func _on_right_released():
	car.steer_target = 0

func _on_brake_pressed():
	car.brake = 3  # Apply brake

func _on_brake_released():
	car.brake = 0  # Release brake
