# track_01.gd
extends Node3D


@onready var mobile_controls = $car/Hud/ControlMobile
func _ready():
	if OS.get_name() == "Android":
		mobile_controls.visible=true
		prints(OS.get_name());
		return
	else:
		mobile_controls.visible = false
