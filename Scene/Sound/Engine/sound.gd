# Engine/sound.gd
extends Node

@onready var audio_players = [
	$"Audio 1", $"Audio 2", $"Audio 3", $"Audio 4",
	$"Audio 5", $"Audio 6", $"Audio 7", $"Audio 8"
]

@export var min_pitch = 0.8
@export var max_pitch = 3.0
@export var max_speed = 300.0  # Adjust based on your max vehicle speed

func update_engine_sound(speed):
	# Normalize speed for pitch scaling
	var pitch = lerp(min_pitch, max_pitch, speed / max_speed)

	# Find the appropriate sound layer
	var index = int(clamp(speed / (max_speed / 8), 0, 7))  # Selects between 1-8
	for i in range(audio_players.size()):
		audio_players[i].volume_db = -20 if i != index else 0  # Mute others

	# Apply pitch to active sound
	audio_players[index].pitch_scale = pitch
	audio_players[index].playing = true
