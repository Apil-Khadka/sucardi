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
func update_engine_sound(current_speed: float, rpm: float, gear: int, throttle: float = 0.0) -> void:
	# Use a minimum engine RPM (idle RPM). Even if rpm is lower, the engine should sound active.
	var base_rpm: float = 800.0
	var effective_rpm: float = max(rpm, base_rpm)
	
	# Compute pitch so that at idle (800 rpm) the pitch is near a base value (e.g. 1.0)
	# and it scales up as rpm increases. Adjust pitch_influence and pitch_calibrate to taste.
	# (For example, here pitch increases linearly from 1.0 at 800rpm.)
	pitch = clamp(1.0 + (effective_rpm - base_rpm) * pitch_influence / (pitch_calibrate - base_rpm), 0.8, 3.0)
	
	# Determine volume.
	# Normally volume is based on speed, but if you're stuck (very low speed) yet the throttle is pressed,
	# we force a minimum volume so the engine sound shows that it's working.
	if current_speed < 5.0 and throttle > 0.1:
		volume = 0.6
	else:
		volume = clamp(current_speed / 300.0, 0.3, 1.0)
	
	# Gear-based sound blending.
	# Ensure gear is at least 1 (or treat nonpositive gear as neutral).
	gear = clamp(gear, 1, 8)
	var gear_idx: int = gear - 1
	# For this example, the “next” gear sound is used for blending during a shift.
	# (Since gear is an integer, gear_blend remains 0; you can later extend this logic for fractional gear changes.)
	var next_gear_idx: int = min(gear, 7)
	var gear_blend: float = 0.0
	
	# Iterate through the expected 8 engine sound children.
	for i in range(8):
		var child = get_child(i)
		if child is AudioStreamPlayer3D:
			# Determine how much this audio node should contribute.
			var vol_factor: float = 0.0
			if i == gear_idx:
				vol_factor = 1.0 - gear_blend
			elif i == next_gear_idx:
				vol_factor = gear_blend
			else:
				vol_factor = 0.0
			
			# Read base volume and pitch from metadata if set (you can use these to fine-tune each child).
			var base_vol: float = child.get_meta("base_volume") if child.has_meta("base_volume") else 1.0
			var base_pitch: float = child.get_meta("base_pitch") if child.has_meta("base_pitch") else 1.0
			
			# Calculate final volume (converted to decibels) and pitch.
			# We multiply the vol_factor by the child’s base volume and our computed volume.
			var final_vol: float = vol_factor * base_vol * (volume * overall_volume)
			child.volume_db = max(linear_to_db(final_vol), -50.0)
			child.set("max_db", child.volume_db)
			
			# Adjust pitch based on our computed pitch and the child’s base pitch.
			var target_pitch: float = clamp(pitch * base_pitch, 0.8, 3.0)
			child.pitch_scale = lerp(child.pitch_scale, target_pitch, 0.2)
			
			# Finally, only play this child if its volume contribution is significant.
			child.playing = vol_factor > 0.01
