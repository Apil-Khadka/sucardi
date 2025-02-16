extends VehicleBody3D

# --- Steering ---
@export var STEER_SPEED: float = 1.5
@export var STEER_LIMIT: float = 0.6
var steer_target: float = 0.0

# --- Engine & Transmission ---
@export var engine_force_value: int = 40
@export var max_speed: int = 200         # Max speed in KMPH
@export var acceleration_rate: int = 5   # For acceleration smoothness
@export var deceleration_rate: int = 10  # For deceleration when throttle is released
@export var breaking_rate: int = 20      # For braking smoothness

var current_speed: float = 0.0
var acceleration: float  = 0.0

# --- Gear System ---
var gears: Array[float] = [0, 30, 60, 100, 150, max_speed]
var gear: int = 1                      # Start in first gear (above 0)
@export var shifting_time: float = 0.3 # Delay when shifting gears
var shift_timer: float = 0.0
var is_shifting: bool = false
var is_braking: bool = false

# --- Cached Node References ---
@onready var engine_sound = $EngineSound
@onready var tyre_sound = $TyreSound
# Ensure the node name matches your scene (e.g. "$wheel0")
@onready var wheel: VehicleWheel3D = $wheal0
@onready var hud_speed = $Hud/speed
@onready var hud_rpm = $Hud/rpm

# RPM value (initialized safely)
var rpm: float = 0.0

func _physics_process(delta: float) -> void:
	# --- Speed Calculation ---
	current_speed = linear_velocity.length() * 3.6  # Convert m/s to KMPH
	hud_speed.text = str(round(current_speed)) + " KMPH"

	# --- Traction ---
	_apply_traction(current_speed)

	# --- Input Handling ---
	var throttle: float = Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down")
	var turn_input: float = Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")
	# Use a continuous check so that brake is applied as long as the key is held down
	var brake_ac: bool = Input.is_action_pressed("ui_brake")

	# --- Gear & Engine Force Update ---
	_update_gear(delta)
	_apply_engine_force(delta, throttle)   # Always call this so deceleration is applied when throttle == 0

	# --- Steering ---
	steer_target = turn_input * STEER_LIMIT
	steering = move_toward(steering, steer_target, STEER_SPEED * delta)

	# --- Update RPM ---
	_update_rpm()

	# --- Braking ---
	if brake_ac:
		is_braking = true
		brake = breaking_rate
	else:
		is_braking = false
		brake = 0

	# --- Update Engine Sound & RPM Display ---
	engine_sound.update_engine_sound(current_speed, rpm, gear)
	hud_rpm.text = str(round(rpm)) + " RPM"

	# --- Calculate Slip Ratio for Tire Sound ---
	var slip_ratio: float = wheel.get_skidinfo()
	print(slip_ratio)
	tyre_sound.update_tire_sound(slip_ratio, is_braking)

func _update_rpm() -> void:
	"""Update engine RPM using the wheel's value.
	   Use abs() so forward motion displays a positive RPM."""
	if wheel:
		rpm = abs(wheel.get_rpm())
	else:
		rpm = 0.0

func _update_gear(delta: float) -> void:
	"""Automatic gear shifting logic."""
	if is_shifting:
		shift_timer -= delta
		if shift_timer <= 0:
			is_shifting = false
		return

	# Upshift if speed exceeds the current gear threshold (with tolerance)
	if gear < gears.size() - 1 and current_speed >= gears[gear] - 5:
		gear += 1
		is_shifting = true
		shift_timer = shifting_time
		rpm = abs(wheel.get_rpm()) + 2000 if wheel else rpm
		# Downshift if speed is below 70% of the previous gear threshold
	elif gear > 1 and current_speed < gears[gear - 1] * 0.7:
		gear -= 1
		is_shifting = true
		shift_timer = shifting_time
		rpm = abs(wheel.get_rpm()) - 4000 if wheel else rpm

func _apply_engine_force(delta: float, throttle: float) -> void:
	"""Apply engine force or deceleration based on throttle input."""
	if throttle > 0:
		if current_speed < max_speed:
			acceleration += acceleration_rate * delta
			acceleration = clamp(acceleration, 0, engine_force_value)
		else:
			acceleration = 0  # Prevent over-speeding
	else:
		# When throttle is released, apply deceleration
		acceleration -= deceleration_rate * delta
		acceleration = max(acceleration, 0)

	# Apply engine force; assumes the vehicle's forward is along -Z
	if transform.basis.z.z <= 1:
		engine_force = -acceleration * (gear / float(gears.size()))
	else:
		brake = 1 if throttle < 0 else 0

func _apply_traction(speed: float) -> void:
	"""Applies a downward force to simulate traction."""
	apply_central_force(Vector3.DOWN * speed)
