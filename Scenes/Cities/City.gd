extends Node2D

onready var name_label = $Marker/Label
var city_name = "citynamia"

func _ready():
	name_label.text = city_name
	
func _process(delta):
	name_label.text = city_name



func _on_DetectionArea_mouse_entered():
	$Marker.modulate.a = 0.2


func _on_DetectionArea_mouse_exited():
	$Marker.modulate.a = 1
