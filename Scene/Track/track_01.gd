# track_01.gd
extends Node3D


@onready var car = $car
func _ready():
	if OS.get_name() != "Android":
		prints(OS.get_name());
		return
