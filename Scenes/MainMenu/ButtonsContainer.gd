extends VBoxContainer

var newcenter;
var oldcenter;
var size = self.rect_size / 2

# Called when the node enters the scene tree for the first time.
func _ready():
	pass
# HACK: Note to 3qc: If you use the "Full Rect" anchor in the editor, it will automatically center.
# Called each frame.
func _process(delta):
	# FPS takes quite a hit on rising. TODO: Boost resize FPS
	newcenter = get_viewport_rect().size / 2
	if not newcenter == oldcenter:
		self.rect_position = Vector2(newcenter.x - size.x, newcenter.y - size.y)
	oldcenter = newcenter
