extends Control

@onready var background_audio = $backgroundaudio

func _on_music_button_pressed() -> void:
	if background_audio.playing:
		background_audio.stop()
	else:
		background_audio.play()
