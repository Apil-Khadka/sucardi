extends Control

@onready var background_audio = $backgroundaudio

func _on_music_button_pressed() -> void:
	if background_audio.playing:
		background_audio.stop()
	else:
		background_audio.play()

func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scene/Track/track01.tscn")
