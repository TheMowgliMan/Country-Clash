extends CanvasLayer

func _ready():
	pass # Replace with function body.

# Go to the MapGen screen
func _on_Start_pressed():
	get_tree().change_scene("res://Scenes/UI/Mapgen.tscn")

func _on_Quit_pressed():
	get_tree().quit()
