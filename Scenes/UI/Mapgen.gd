extends MarginContainer


var frame = 0

func _process(delta):
	if frame == 3:
		get_tree().change_scene("res://Scenes/World/World.tscn")
		
	frame += 1
