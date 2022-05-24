# Button to open the file explorer
tool
extends Button

### Member Variables and Dependencies -----
# signals 
# enums
# constants
# public variables - order: export > normal var > onready 

# Title that should appear in the File Explorer Window
export var window_title: = ""

# private variables - order: export > normal var > onready 

onready var _file_dialog: FileDialog = get_node("FileDialog")

### ---------------------------------------


### Built in Engine Methods ---------------

func _ready():
	if window_title != "":
		_file_dialog.window_title = window_title


func _pressed() -> void:
	_file_dialog.popup_centered()

### ---------------------------------------


### Public Methods ------------------------
### ---------------------------------------


### Private Methods -----------------------
### ---------------------------------------


