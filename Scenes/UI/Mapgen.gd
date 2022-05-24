extends MarginContainer


var frame = 0

# Goes to the world scene
func _process(delta):
	# Frame Can't == 0 or it'll freeze before displaying the screen.
	if frame == 3:
		get_tree().change_scene("res://Scenes/World/World.tscn")
		
	frame += 1
