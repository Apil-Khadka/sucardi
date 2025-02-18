extends Control

@export var base_resolution: Vector2 = Vector2(1024, 600)

func _ready():
	base_resolution = get_window().size
	print("Current screen resolution: ", base_resolution)
