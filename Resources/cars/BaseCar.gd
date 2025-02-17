extends VehicleBody3D

# --- Engine & Transmission ---
@export var engine_idle_rpm: float = 800.0
@export var engine_max_rpm: float = 8000.0
@export var engine_max_torque: float = 400.0  # Example maximum torque value
@export var gear_ratios: Array[float] = [3.5, 2.8, 2.0, 1.5, 1.1, 0.8]  # Forward gear ratios (gears 1..6)
@export var reverse_ratio: float = 3.5                     # Reverse gear ratio
@export var final_drive_ratio: float = 3.2

var current_rpm: float = engine_idle_rpm
var wheel_rpm: float = 0.0

# Gear: -1 = reverse, 0 = neutral, 1+ = forward gears
var gear: int = 0
@export var shifting_time: float = 0.2
var shift_timer: float = 0.0
var is_shifting: bool = false

# --- Steering ---
@export var STEER_SPEED: float = 3.0
@export var STEER_LIMIT: float = 0.8
@export var steering_assist_factor: float = 0.7
@export var steering_return_speed: float = 3.0
var steer_target: float = 0.0

# --- Drifting & Traction ---
@export var handbrake_force: float = 60.0
@export var drift_slip_threshold: float = 0.7
var is_drifting: bool = false

# --- Vehicle Forces ---
@export var engine_force_value: float = 180.0  # Base engine force value (for smoothing)
@export var breaking_force: float = 150.0
@export var deceleration_rate: float = 60.0
@export var acceleration_rate: float = 1000.0

# --- HUD & Audio ---
@onready var hud_speed = $Hud/speed
@onready var hud_rpm = $Hud/rpm
@onready var engine_sound = $EngineSound
@onready var tyre_sound = $TyreSound
@onready var breaklight = $breaklight
@onready var breaklight2 = $breaklight2
@onready var breaklight_emm = $breaklight_emm
# --- Wheel References ---
@onready var front_left: VehicleWheel3D = $wheal1
@onready var front_right: VehicleWheel3D = $wheal0
@onready var rear_left: VehicleWheel3D = $wheal3
@onready var rear_right: VehicleWheel3D = $wheal2


var current_speed: float = 0.0
var acceleration: float = 0.0

func _ready():
	setup_wheels()

func setup_wheels():
	# Configure wheel properties for realistic handling
	for wheel in [front_left, front_right]:
		wheel.suspension_stiffness = 25.0
		wheel.wheel_friction_slip = 3.5
		wheel.damping_compression = 4.0
		wheel.damping_relaxation = 2.0
	
	for wheel in [rear_left, rear_right]:
		wheel.suspension_stiffness = 22.0
		wheel.wheel_friction_slip = 2.8
		wheel.damping_compression = 3.5
		wheel.damping_relaxation = 1.8

func _physics_process(delta: float) -> void:
	# Update speed and HUD
	current_speed = linear_velocity.length() * 3.6
	hud_speed.text = "%d KMPH" % round(current_speed)
	
	# Process input
	var throttle: float = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	var turn_input: float = Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")
	var brake_active: bool = Input.is_action_pressed("ui_brake")
	var handbrake_active: bool = Input.is_action_pressed("handbrake")
	
	_update_gear(delta, throttle)
	
	var break_emission = breaklight_emm.get_surface_override_material(0)
	# Use handbrake if active; otherwise apply gradual braking via ui_brake
	if handbrake_active:
		_handle_handbrake(delta)
		breaklight.visible = true
		breaklight2.visible = true
		break_emission.emission_enabled = true
	elif brake_active:
		_handle_braking(delta, brake_active)
		breaklight.visible=true
		breaklight2.visible = true
		break_emission.emission_enabled = true
	else:
		breaklight.visible = false
		breaklight2.visible = false
		break_emission.emission_enabled = false

	# Only apply engine force when not handbraking
	if not handbrake_active:
		if not brake_active:
			_apply_engine_force(delta, throttle)
	
	_handle_steering(delta, turn_input)
	
	_update_rpm(delta, abs(throttle))
	hud_rpm.text = "%d RPM" % round(current_rpm)
	_update_sounds()

func _update_rpm(delta: float, throttle: float) -> void:
	# Calculate average wheel RPM from the front wheels
	wheel_rpm = (abs(front_left.get_rpm()) + abs(front_right.get_rpm())) / 2.0
	
	if linear_velocity.length() < 0.5:
		# When nearly stationary (e.g., against a wall), simulate the engine revving with throttle.
		current_rpm = lerp(current_rpm, engine_idle_rpm + (engine_max_rpm - engine_idle_rpm) * throttle, delta * 5.0)
	elif gear > 0:
		# Calculate RPM based on wheel speed and gear ratio
		current_rpm = abs(wheel_rpm) * gear_ratios[gear - 1] * final_drive_ratio
	elif gear == -1:
		current_rpm = abs(wheel_rpm) * reverse_ratio * final_drive_ratio
	else:
		# Neutral: gentle ramp up toward idle
		current_rpm = lerp(current_rpm, engine_idle_rpm, delta * 2.0)
	
	current_rpm = clamp(current_rpm, engine_idle_rpm, engine_max_rpm)

func calculate_torque() -> float:
	# Simulate a simple torque curve with peak torque around 70% of max RPM
	var rpm_normalized = (current_rpm - engine_idle_rpm) / (engine_max_rpm - engine_idle_rpm)
	var torque_curve = 1.0 - abs(rpm_normalized - 0.7)
	return engine_max_torque * clamp(torque_curve, 0.5, 1.0)

func _apply_engine_force(delta: float, throttle: float) -> void:
	# If any brake is applied, skip engine force application
	if brake > 0:
		return
	
	var torque: float = calculate_torque()
	if gear == -1:
		engine_force = throttle * torque * reverse_ratio * final_drive_ratio
	elif gear > 0:
		engine_force = throttle * torque * gear_ratios[gear - 1] * final_drive_ratio
	else:
		engine_force = 0.0
	
	# Smooth acceleration using interpolation
	var target_acceleration = engine_force_value * throttle
	acceleration = move_toward(acceleration, target_acceleration, acceleration_rate * delta)
	engine_force = acceleration
	
	# Set the engine force for the vehicle (a built-in property)
	self.engine_force = engine_force

func _handle_braking(delta: float, brake_active: bool) -> void:
	if brake_active:
		# For ui_brake: apply a moderate, gradually increasing braking force to all wheels.
		var target_brake = breaking_force * 0.5  # Adjust multiplier for desired deceleration
		# Here we use one wheel’s current brake value as reference.
		var current_brake = move_toward(front_left.brake, target_brake, deceleration_rate * delta)
		for wheel in [front_left, front_right, rear_left, rear_right]:
			wheel.brake = current_brake
		# Reduce engine acceleration during braking
		acceleration = move_toward(acceleration, 0.0, deceleration_rate * delta)
		brake = current_brake
	else:
		for wheel in [front_left, front_right, rear_left, rear_right]:
			wheel.brake = 0.0
		brake = 0.0

func _handle_handbrake(delta: float) -> void:
	# For a real-car feel, the handbrake applies a strong, immediate braking force to the rear wheels.
	for wheel in [rear_left, rear_right]:
		wheel.brake = handbrake_force
	# Optionally clear braking from the front wheels to emphasize oversteer/drift.
	for wheel in [front_left, front_right]:
		wheel.brake = 0.0
	# You might also want to reduce engine force to simulate a locked rear end.
	acceleration = 0.0

func _handle_steering(delta: float, turn_input: float) -> void:
	steer_target = turn_input * STEER_LIMIT
	var speed_factor = clamp(linear_velocity.length() / 20.0, 0.0, 1.0)
	var steering_assist = 1.0 - (steering_assist_factor * speed_factor)
	
	if abs(turn_input) < 0.1:
		steering = move_toward(steering, 0.0, steering_return_speed * delta * (1.0 + speed_factor))
	else:
		steering = lerp(steering, steer_target, STEER_SPEED * delta * steering_assist)

func _update_gear(delta: float, throttle: float) -> void:
	if is_shifting:
		shift_timer -= delta
		if shift_timer <= 0:
			is_shifting = false
			# Simulate a brief rpm drop when a gear shift completes
			current_rpm = engine_idle_rpm + 0.2 * (current_rpm - engine_idle_rpm)
		return
	
	# RPM-based gear shifting logic with a brief delay
	if gear > 0:
		if current_rpm > engine_max_rpm * 0.8 and gear < gear_ratios.size():
			gear += 1
			is_shifting = true
			shift_timer = shifting_time
		elif gear > 1 and current_rpm < engine_max_rpm * 0.3:
			gear -= 1
			is_shifting = true
			shift_timer = shifting_time
	elif gear == 0:
		# In neutral, shift into first gear if throttle is applied and car is nearly stationary.
		if abs(throttle) > 0.1 and current_speed < 5:
			gear = 1
			is_shifting = true
			shift_timer = shifting_time
	
	# Engage reverse gear if negative throttle is applied while stationary.
	if throttle < -0.1 and current_speed < 5:
		gear = -1
		is_shifting = true
		shift_timer = shifting_time

func _update_sounds() -> void:
	# Update engine and tire sounds based on current parameters.
	engine_sound.update_engine_sound(current_speed, current_rpm, gear)
	var slip = (rear_left.get_skidinfo() + rear_right.get_skidinfo()) / 2.0
	tyre_sound.update_tire_sound(slip, is_drifting or (brake > 0))
