extends Node3D
class_name ViVeCarEngineSFX

#–– Calculated values ––
var pitch: float = 0.0
var volume: float = 0.0
var fade: float = 0.0
var vacuum: float = 0.0
var maxfades: float = 0.0
var childcount: int = 0

#–– Exported tuning parameters ––
@export var pitch_calibrate: float = 7500.0
@export var vacuum_crossfade: float = 0.7
@export var vacuum_loudness: float = 4.0
@export var crossfade_vvt: float = 5.0
@export var crossfade_throttle: float = 0.0
@export var crossfade_influence: float = 5.0
@export var overall_volume: float = 1.0

#–– This multiplier affects how strongly RPM influences pitch. ––
var pitch_influence: float = 1.0

func _ready() -> void:
	# Start playing all children.
	play()
	# Store the number of children (audio nodes).
	childcount = get_child_count()
	maxfades = float(childcount - 1)

func play() -> void:
	# Loop through each child and call play() if it is an AudioStreamPlayer3D.
	for child in get_children():
		if child is AudioStreamPlayer3D:
			child.play()

func stop() -> void:
	# Loop through each child and stop playback.
	for child in get_children():
		if child is AudioStreamPlayer3D:
			child.stop()

#–– update_engine_sound() ––
func update_engine_sound(current_speed: float, rpm: float, gear: int) -> void:
	# Normalize pitch based on RPM and calibration
	pitch = clamp(rpm * pitch_influence / pitch_calibrate, 0.5, 3.0)

	# Volume control based on speed, ensuring it never fully mutes
	volume = clamp(current_speed / 300.0, 0.3, 1.0)

	# Ensure gear stays within range (1 to 8)
	gear = clamp(gear, 1, 8)

	# Select primary and secondary audio indexes based on gear
	var gear_idx = gear - 1
	var next_gear_idx = min(gear, 7)  # Prevent going beyond the last index

	# Interpolation factor between gears (how much we're transitioning)
	var gear_blend = fposmod(gear, 1.0)  # Fractional part to blend between gears

	# Iterate through audio children
	for i in range(8):
		var child = get_child(i)
		if child is AudioStreamPlayer3D:
			# Check if this child is part of the gear selection
			var is_primary = (i == gear_idx)
			var is_secondary = (i == next_gear_idx)

			# Determine volume contribution
			var vol_factor: float = 0.0
			if is_primary:
				vol_factor = 1.0 - gear_blend
			elif is_secondary:
				vol_factor = gear_blend

			# Get base volume and pitch values
			var base_vol: float = child.get_meta("base_volume") if child.has_meta("base_volume") else 100.0
			var base_pitch: float = child.get_meta("base_pitch") if child.has_meta("base_pitch") else 100000.0

			# Normalize volume and pitch
			var maxvol: float = base_vol / 100.0
			var maxpitch: float = base_pitch / 100000.0

			# Apply final volume and pitch
			child.volume_db = max(linear_to_db(vol_factor * maxvol * (volume * overall_volume)), -50.0)
			child.set("max_db", child.volume_db)

			# Smooth pitch scaling
			var pit: float = clamp(pitch * maxpitch, 0.8, 2.5)
			child.pitch_scale = lerp(child.pitch_scale, pit, 0.2)  # Smooth transition

			# Enable or disable sound based on its relevance to the current gear
			child.playing = vol_factor > 0.01  # Only play if volume factor is significant
