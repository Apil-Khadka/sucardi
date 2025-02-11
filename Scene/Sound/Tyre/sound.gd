# Tyre/sound.gd
extends Node

@onready var roll_sounds = [$"roll 0", $"roll 1", $"roll 2"]
@onready var peel_sounds = [$"peel 0", $"peel 1", $"peel 2"]
@onready var offroad_sound = $offroad

@export var skid_threshold = 0.5
@export var roll_threshold = 1.0

func update_tire_sound(slip_ratio):
	if slip_ratio > skid_threshold:
		# Play skid sounds
		peel_sounds[int(clamp(slip_ratio * 2, 0, 2))].playing = true
	else:
		# Play roll sounds
		roll_sounds[int(clamp(slip_ratio * 2, 0, 2))].playing = true
