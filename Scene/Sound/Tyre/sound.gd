extends Node

# Assuming your child nodes are named exactly "roll 0", "roll 1", "roll 2" etc.
@onready var roll_sounds: Array[Variant] = [ get_node("roll 0"), get_node("roll 1"), get_node("roll 2") ]
@onready var peel_sounds: Array[Variant] = [ get_node("peel 0"), get_node("peel 1"), get_node("peel 2") ]
@onready var offroad_sound = $offroad

var is_offroad:bool = false

func update_tire_sound(slip_ratio: float, isBrake: bool) -> void:
	# Scale the raw slip ratio to make the values more sensitive.
	#var slip_ratio: float = raw_slip_ratio * 1000.0
	
	
	# If offroad, play offroad sound and stop other tire sounds.
	if is_offroad:
		if not offroad_sound.playing:
			offroad_sound.play()
		_stop_sounds(roll_sounds)
		_stop_sounds(peel_sounds)
		return
	else:
		if offroad_sound.playing:
			offroad_sound.stop()

	if isBrake:
		var sound = peel_sounds[2]
		if not sound.playing:
			sound.play()
	
	# Determine tire sound based on slip ratio.
	if slip_ratio < 0.8:
		# High slip: use a peel sound.
		var sound = peel_sounds[1]
		if not sound.playing:
			sound.play()
		# _stop_sounds(peel_sounds)
	elif slip_ratio < 0.5:
		# Moderate slip: use a roll sound.
		#var sound = roll_sounds[randi() % roll_sounds.size()]
		var sound = peel_sounds[0]
		if not sound.playing:
			sound.play()
		# _stop_sounds(peel_sounds)
	elif slip_ratio < 0.1:
		# Moderate slip: use a roll sound.
		#var sound = roll_sounds[randi() % roll_sounds.size()]
		var sound = peel_sounds[2]
		if not sound.playing:
			sound.play()
		# _stop_sounds(peel_sounds)
	else:
		# Minimal slip: stop any tire sounds.
	#	_stop_sounds(roll_sounds)
		_stop_sounds(peel_sounds)

# Helper function to stop an array of sound players.
func _stop_sounds(sounds: Array) -> void:
	for sound in sounds:
		if sound.playing:
			sound.stop()

# Stub function: replace with your own offroad logic if needed.
