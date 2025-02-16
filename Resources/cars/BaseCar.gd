extends VehicleBody3D

# --- Steering ---
@export var STEER_SPEED: float = 2.5
@export var STEER_LIMIT: float = 0.8
var steer_target: float = 0.0

# --- Engine & Transmission ---
@export var engine_force_value: int = 150
@export var max_speed: int = 200
@export var acceleration_rate: int = 800
@export var deceleration_rate: int = 50
@export var breaking_rate: int = 30  # Increased braking rate

var current_speed: float = 0.0
var acceleration: float = 0.0

# --- Gear System ---
var torque_ratios: Array[float] = [2.0, 0, 3.0, 2.2, 1.6, 1.2, 1.0]  # Index 0 = reverse
var gears: Array[float] = [-30, 0, 30, 60, 100, 150, max_speed]     # Gear 0 = reverse
var gear: int = 1                      # Start in neutral
@export var shifting_time: float = 0.2
var shift_timer: float = 0.0
var is_shifting: bool = false
var is_braking: bool = false

# --- Cached Node References ---
@onready var engine_sound = $EngineSound
@onready var tyre_sound = $TyreSound
@onready var wheel: VehicleWheel3D = $wheal0
@onready var hud_speed = $Hud/speed
@onready var hud_rpm = $Hud/rpm

var rpm: float = 0.0

func _physics_process(delta: float) -> void:
	current_speed = linear_velocity.length() * 3.6
	hud_speed.text = "%d KMPH" % round(current_speed)

	var throttle: float = Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down")
	var turn_input: float = Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")
	var brake_ac: bool = Input.is_action_pressed("ui_brake")

	_update_gear(delta, throttle)
	_apply_engine_force(delta, throttle)

	steer_target = turn_input * STEER_LIMIT
	steering = lerp(steering, steer_target, STEER_SPEED * delta)

	_update_rpm()

	# Instant braking
	if brake_ac:
		is_braking = true
		brake = breaking_rate
		acceleration = 0.0  # Immediate engine cut
		engine_force = 0.0   # Remove any residual force
	else:
		is_braking = false
		brake = 0

	engine_sound.update_engine_sound(current_speed, rpm, gear)
	hud_rpm.text = "%d RPM" % round(rpm)

	var slip_ratio: float = wheel.get_skidinfo()
	tyre_sound.update_tire_sound(slip_ratio, is_braking)

func _update_rpm() -> void:
	rpm = abs(wheel.get_rpm()) if wheel else 0.0

func _update_gear(delta: float, throttle: float) -> void:
	if is_shifting:
		shift_timer -= delta
		if shift_timer <= 0:
			is_shifting = false
		return

	# Reverse gear handling
	if throttle < -0.1 && gear != 0:
		if current_speed < 5:  # Only shift to reverse when almost stopped
			gear = 0
			is_shifting = true
			shift_timer = shifting_time
	elif throttle > 0.1 && gear == 0:
		if current_speed < 5:  # Only shift from reverse when almost stopped
			gear = 1
			is_shifting = true
			shift_timer = shifting_time

	# Normal gear shifting (forward gears)
	if gear > 0:
		if gear < gears.size() - 1 and current_speed >= gears[gear] - 5:
			gear += 1
			is_shifting = true
			shift_timer = shifting_time
		elif gear > 1 and current_speed < gears[gear - 1] * 0.7:
			gear -= 1
			is_shifting = true
			shift_timer = shifting_time

func _apply_engine_force(delta: float, throttle: float) -> void:
	if is_braking:
		return  # No engine force during braking

	var target_acceleration = 0.0

	if gear == 0:  # Reverse gear
		target_acceleration = throttle * engine_force_value * -1
	else:
		target_acceleration = throttle * engine_force_value

	if throttle != 0:
		acceleration = move_toward(acceleration, target_acceleration, acceleration_rate * delta)
	else:
		acceleration = move_toward(acceleration, 0.0, deceleration_rate * delta)

	# Apply different torque ratios for reverse/forward
	if gear == 0:
		engine_force = -acceleration * torque_ratios[0]
	else:
		engine_force = -acceleration * torque_ratios[gear]