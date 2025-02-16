extends VehicleBody3D

# --- Steering ---
@export var STEER_SPEED: float = 1.5
@export var STEER_LIMIT: float = 0.6
var steer_target: float          = 0.0

# --- Engine & Transmission ---
@export var engine_force_value: int = 40
@export var max_speed: int = 200            # Max speed in KMPH
@export var acceleration_rate: int = 5      # Adjust for acceleration smoothness
@export var deceleration_rate = 10     # Adjust for braking smoothness

var current_speed: float = 0.0
var acceleration: float  = 0.0

# --- Gear System ---
# Define gear thresholds in KMPH; adjust values as needed.
var gears: Array[Variant] = [0, 30, 60, 100, 150, max_speed]  
var gear: int             = 1              # Start from first gear (index 1 corresponds to speeds above 0)
var shifting_time: float = 0.3   # Delay (in seconds) when shifting gears
var shift_timer: float   = 0.0
var is_shifting: bool    = false

# --- Sound Nodes ---
@onready var engine_sound = $EngineSound
@onready var tyre_sound = $TyreSound
@onready var wheel = $wheal0

var rpm: float = wheel.get_rpm()

func _physics_process(delta):
	# Calculate the vehicle's speed in KMPH.
	current_speed = linear_velocity.length() * 3.8
	
	# Update traction and display the speed on the HUD.
	traction(current_speed)
	$Hud/speed.text = str(round(current_speed)) + " KMPH"
	
	# Update gear shifting and engine force.
	update_gear(delta)
	if Input.is_action_pressed("ui_up") or  Input.is_action_pressed("ui_down"):
		apply_engine_force(delta)
	
	# Update engine sound.
	# Your EngineSound script should expect (current_speed, rpm, gear) to adjust pitch/volume.
	engine_sound.update_engine_sound(current_speed, rpm, gear)
	
	# --- Steering ---
	steer_target = Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")
	steer_target *= STEER_LIMIT
	steering = move_toward(steering, steer_target, STEER_SPEED * delta)
	
	var radius = wheel.get_radius()
	
	
func update_gear(delta):
	""" Automatic gear shifting logic. """
	# If currently in a gear shift, wait until the shift delay expires.
	if is_shifting:
		shift_timer -= delta
		if shift_timer <= 0:
			is_shifting = false
		return  # Skip further gear changes during the shift delay.
	
	# Upshift logic: if current speed exceeds the threshold for the current gear (with some tolerance).
	if gear < gears.size() - 1 and current_speed >= gears[gear] - 5:
		gear += 1
		is_shifting = true
		shift_timer = shifting_time
		rpm = wheel.get_rpm() + 2000  # Reset RPM when upshifting.
	
	# Downshift logic: if current speed is significantly below the threshold of the previous gear.
	elif gear > 1 and current_speed < gears[gear - 1] * 0.7:
		gear -= 1
		is_shifting = true
		shift_timer = shifting_time
		rpm = wheel.get_rpm() - 4000  # Increase RPM on downshift.
	
func apply_engine_force(delta):
	""" Applies engine force and braking based on throttle input and gear. """
	var fwd_mps = transform.basis.x.x
	# Calculate throttle: positive when accelerating, negative for braking.
	# Note: Depending on your input mappings, you might want to reverse these.
	var throttle = Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down")
	# --- Acceleration ---
	if throttle > 0:
		if current_speed < max_speed:
			acceleration += acceleration_rate * delta
			acceleration = clamp(acceleration, 0, engine_force_value)
		else:
			acceleration = 0  # Prevent acceleration beyond max speed.
	else:
		# Natural deceleration when throttle is not applied.
		acceleration -= deceleration_rate * delta
		acceleration = max(acceleration, 0)
	
	# --- Engine Force ---
	# If the forward direction is valid, apply engine force.
	if fwd_mps >= -1:
		engine_force = - acceleration * (gear / float(gears.size()))
	else:
		brake = 1 if throttle < 0 else 0
	
	# --- RPM Simulation ---
	# get rpm from VehicleWheel3d
	rpm = - wheel.get_rpm()

	$Hud/rpm.text = str(round(rpm)) + " RPM"
	
func traction(speed):
	""" Applies a downward force to improve tire grip on the road. """
	apply_central_force(Vector3.DOWN * speed)

func get_slip_ratio(wheel_radius: float, wheel_angular_speed: float, wheel_linear_speed: float) -> float:
	var wheel_surface_speed = wheel_angular_speed * wheel_radius
	var slip_ratio = 0.0
	if wheel_linear_speed != 0:
		slip_ratio = abs(wheel_surface_speed - wheel_linear_speed) / wheel_linear_speed
	return slip_ratio
