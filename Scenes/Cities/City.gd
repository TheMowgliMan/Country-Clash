extends Node2D

onready var name_label = $Label

func setup(name):
	name_label.text = name
