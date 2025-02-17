extends Control

@onready var background_audio = $backgroundaudio


@onready var nextScene = load("res://Scene/Track/track01.tscn")

func _on_music_button_pressed() -> void:
	if background_audio.playing:
		background_audio.stop()
	else:
		background_audio.play()
	


func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_packed(nextScene)
