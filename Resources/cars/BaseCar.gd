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
@onready var pauseButton = $Hud/pauseButton
@onready var helpButton = $Hud/helpButton
@onready var engine_sound = $EngineSound
@onready var tyre_sound = $TyreSound
@onready var breaklight = $breaklight
@onready var breaklight2 = $breaklight2
@onready var breaklight_emm = $breaklight_emm
@onready var headlight = $headlight
@onready var headlight2 = $headlight2

# --- Wheel References ---
@onready var front_left: VehicleWheel3D = $wheal1
@onready var front_right: VehicleWheel3D = $wheal0
@onready var rear_left: VehicleWheel3D = $wheal3
@onready var rear_right: VehicleWheel3D = $wheal2

var current_speed: float = 0.0
var acceleration: float = 0.0

# Custom braking variable (to avoid conflict with the built-in "brake" property)
var brake_value: float = 0.0

var headlight_active: bool = false  # Store state


func _ready():
	setup_wheels()
	pauseButton.get_popup().connect("id_pressed", Callable(self, "_on_MenuButton_id_pressed"))
	pauseButton.get_popup().connect("popup_hide", Callable(self, "_on_MenuButton_about_to_hide"))

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
	# Note: Using "ui_down" minus "ui_up" to determine throttle.
	var throttle: float = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	var turn_input: float = Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")
	var brake_active: bool = Input.is_action_pressed("ui_brake")
	var handbrake_active: bool = Input.is_action_pressed("handbrake")
	
	if Input.is_action_just_pressed("headlight"):
		headlight_active = !headlight_active
	
	if headlight_active:
		headlight.visible = true
		headlight2.visible = true
	else:
		headlight.visible = false
		headlight2.visible = false
	
	
	# If brake or handbrake is active, override throttle to 0.
	if brake_active or handbrake_active:
		throttle = 0.0
	
	_update_gear(delta, throttle)
	
	# Get the emissive material for brake lights.
	var break_emission = breaklight_emm.get_surface_override_material(0)
	
	# Handle braking input
	if handbrake_active:
		_handle_handbrake(delta)
		# Also, force engine force to zero so acceleration doesn't counteract brakes.
		self.engine_force = 0
		breaklight.visible = true
		breaklight2.visible = true
		break_emission.emission_enabled = true
	elif brake_active:
		_handle_braking(delta, true)
		self.engine_force = 0
		breaklight.visible = true
		breaklight2.visible = true
		break_emission.emission_enabled = true
	else:
		breaklight.visible = false
		breaklight2.visible = false
		break_emission.emission_enabled = false
		_handle_braking(delta, false)
	
	# Only apply engine force if no brake or handbrake is active.
	if not handbrake_active and not brake_active:
		_apply_engine_force(delta, throttle)
	
	_handle_steering(delta, turn_input)
	
	_update_rpm(delta, abs(throttle))
	hud_rpm.text = "%d RPM" % round(current_rpm)
	_update_sounds()

func _update_rpm(delta: float, throttle: float) -> void:
	# Calculate average wheel RPM from the front wheels
	wheel_rpm = (abs(front_left.get_rpm()) + abs(front_right.get_rpm())) / 2.0
	
	if linear_velocity.length() < 0.5:
		current_rpm = lerp(current_rpm, engine_idle_rpm + (engine_max_rpm - engine_idle_rpm) * throttle, delta * 5.0)
	elif gear > 0:
		current_rpm = abs(wheel_rpm) * gear_ratios[gear - 1] * final_drive_ratio
	elif gear == -1:
		current_rpm = abs(wheel_rpm) * reverse_ratio * final_drive_ratio
	else:
		current_rpm = lerp(current_rpm, engine_idle_rpm, delta * 2.0)
	
	current_rpm = clamp(current_rpm, engine_idle_rpm, engine_max_rpm)

func calculate_torque() -> float:
	var rpm_normalized = (current_rpm - engine_idle_rpm) / (engine_max_rpm - engine_idle_rpm)
	var torque_curve = 1.0 - abs(rpm_normalized - 0.7)
	return engine_max_torque * clamp(torque_curve, 0.5, 1.0)

func _apply_engine_force(delta: float, throttle: float) -> void:
	# Do not apply engine force if brakes are active.
	if brake_value > 0:
		return
	
	var torque: float = calculate_torque()
	var engine_force_val: float = 0.0
	if gear == -1:
		engine_force_val = throttle * torque * reverse_ratio * final_drive_ratio
	elif gear > 0:
		engine_force_val = throttle * torque * gear_ratios[gear - 1] * final_drive_ratio
	else:
		engine_force_val = 0.0
	
	# Smooth acceleration.
	var target_acceleration = engine_force_value * throttle
	acceleration = move_toward(acceleration, target_acceleration, acceleration_rate * delta)
	engine_force_val = acceleration
	
	# Set the vehicle’s engine force.
	self.engine_force = engine_force_val

func _handle_braking(delta: float, brake_active: bool) -> void:
	if brake_active:
		# Gradually increase braking force.
		var target_brake = breaking_force * 0.5  # Adjust multiplier as needed.
		var current_brake = move_toward(front_left.brake, target_brake, deceleration_rate * delta)
		for wheel in [front_left, front_right, rear_left, rear_right]:
			wheel.brake = current_brake
		# Smoothly reduce engine acceleration.
		acceleration = move_toward(acceleration, 0.0, deceleration_rate * delta)
		brake_value = current_brake
	else:
		# Reset braking.
		for wheel in [front_left, front_right, rear_left, rear_right]:
			wheel.brake = 0.0
		brake_value = 0.0

func _handle_handbrake(_delta: float) -> void:
	# Apply a strong braking force to rear wheels.
	for wheel in [rear_left, rear_right]:
		wheel.brake = handbrake_force
	# Optionally clear braking on front wheels.
	for wheel in [front_left, front_right]:
		wheel.brake = 0.0
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
			current_rpm = engine_idle_rpm + 0.2 * (current_rpm - engine_idle_rpm)
		return
	
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
		if abs(throttle) > 0.1 and current_speed < 5:
			gear = 1
			is_shifting = true
			shift_timer = shifting_time
	
	if throttle < -0.1 and current_speed < 5:
		gear = -1
		is_shifting = true
		shift_timer = shifting_time

func _update_sounds() -> void:
	engine_sound.update_engine_sound(current_speed, current_rpm, gear)
	var slip = (rear_left.get_skidinfo() + rear_right.get_skidinfo()) / 2.0
	tyre_sound.update_tire_sound(slip, is_drifting or (brake_value > 0))


func _on_pause_button_pressed() -> void:
	get_tree().paused=true
	pauseButton.get_popup().popup_centered()

func _on_MenuButton_about_to_hide() -> void:
	get_tree().paused=false

func _on_MenuButton_id_pressed(id: int) -> void:
	match id:
		0:  # Continue option
			get_tree().paused = false
		1:  # Restart option
			get_tree().paused = false
			get_tree().reload_current_scene()
		2:
			get_tree().paused = false
			get_tree().change_scene_to_file("res://Scene/Main/main.tscn")


func _on_help_button_pressed() -> void:
	helpButton.get_popup().popup_centered()
