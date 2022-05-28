extends Node2D

var texture_map = []
var map = []
# For city adding
var island_map = []

# Format: ..., {"name" : "citynamia", "position" : Vector2(23, 32), "population": 32000}, ...
var cities = []
export var map_size_square = 512
var map_generated = false

export var sea_level = 0.11

var city = preload("res://Scenes/Cities/City.tscn")

var terrain_noise = OpenSimplexNoise.new()
var big_noise = OpenSimplexNoise.new()
var terrain_adjuster = OpenSimplexNoise.new()
var terrain_persistence = 0.6

var frame = 1
var update_sprite_thread = null
var refresh_map_thread = null

var zoom_in = false
var zoom_out = false

onready var map_sprite = $RenderManager/MapRender
onready var camera = $Scroller/Camera
onready var city_controller = $Cities

var draw_mutex = Mutex.new()
var assign_map_mutex = Mutex.new()

var map_scale = 1

# Return the three texture components present at any particular x,y pair
func get_terrain_texture_map(x, y):
	return [texture_map[y * (map_size_square * 3) + x * 3], texture_map[y * (map_size_square * 3) + x * 3 + 1], texture_map[y * (map_size_square * 3) + x * 3 + 2]]

# Set the three texture components at any x,y pair
# Usage: set_terrain_text_map(x, y, redvalue, greenvalue, bluevalue)
func set_terrain_texture_map(x, y, data1, data2, data3):
	assign_map_mutex.lock()
	texture_map[y * (map_size_square * 3) + x * 3] = data1
	texture_map[y * (map_size_square * 3) + x * 3 + 1] = data2
	texture_map[y * (map_size_square * 3) + x * 3 + 2] = data3
	assign_map_mutex.unlock()

# Set the terrain height at any particular x/y pair
func set_terrain_map(x, y, data):
	assign_map_mutex.lock()
	map[(y * map_size_square) + x] = data
	assign_map_mutex.unlock()
	
# Get the terrain height an any particular x/y pair
func get_terrain_map(x, y):
	return map[(y * map_size_square) + x]
	
func set_island_map(x, y, data):
	assign_map_mutex.lock()
	island_map[(y * map_size_square) + x] = data
	assign_map_mutex.unlock()
	
func get_island_map(x, y):
	return island_map[(y * map_size_square) + x]

# Generate the map, terrain-based and then convert it to textures
# TODO: Use multithreading, at least 3
func gen_map():
	
	# Fill out the maps with empty data
	for _i in range(0, map_size_square * map_size_square):
		map.append(0)
		
		island_map.append(false)
		
		# Have to do this three times to get the textures in, as there are 3 color components
		texture_map.append(0)
		texture_map.append(0)
		texture_map.append(0)
	
	# Add the terrain data
	for y in range(0, map_size_square):
		for x in range(0, map_size_square):
			
			# Get an adjuster noise to change the regular and big noise slightly
			var adjuster_noise = terrain_adjuster.get_noise_2d(x, y)
			terrain_noise.persistence = terrain_persistence + (adjuster_noise * 0.3)
			big_noise.persistence = terrain_persistence + (adjuster_noise * 0.3)
			
			# Get the big and regular noises and perform a weighted average to get final result
			var terr_noise = terrain_noise.get_noise_2d(x, y)
			var b_noise = big_noise.get_noise_2d(x, y)
			var noise = ((terr_noise * 0.5) + b_noise) / 1.5
			
			# Sets the map at that spot
			set_terrain_map(x, y, noise)
			
			# Mark it as land
			if noise > sea_level:
				set_island_map(x, y, true)
			
	# Generate Cities
	for _i in range(0, round(map_size_square * map_size_square / (80 * 80))):
		var position = Vector2(round(rand_range(0, map_size_square - 1)), round(rand_range(0, map_size_square - 1)))
		
		if get_island_map(position.x, position.y):
			cities.append({"name" : generate_city_name(), "position" : position, "population": rand_range(3000, 80000)})
			print(position)
	
	# Add the textures
	refresh_map()

# See refresh_map_arg() below for breakdown.
func refresh_map():
	for x in range(0, map_size_square):
		for y in range(0, map_size_square):
			var noise = get_terrain_map(x, y)
			
			if noise > sea_level + 0.28:
				set_terrain_texture_map(x, y, 225 + round((noise-0.11) * 30), 225 + round((noise-0.11) * 30), 245 + round((noise-0.11) * 10))
			elif noise > sea_level + 0.2:
				set_terrain_texture_map(x, y, 64 + round((noise-0.11) * 191), 64 + round((noise-0.11) * 191), 64 + round((noise-0.11) * 191))
			elif noise > sea_level + 0.015:
				set_terrain_texture_map(x, y, 10 + round((noise-0.11) * 245), 128 + round((noise-0.11) * 127), 25 + round((noise-0.11) * 230))
			elif noise > sea_level:
				set_terrain_texture_map(x, y, 206, 202, 159)
			else:
				set_terrain_texture_map(x, y, 70 + round((noise) * 70), 70 + round((noise) * 70), 230 + round((noise) * 200))

# Refreshes the map texture
func refresh_map_arg(mss):
	for x in range(0, mss):
		for y in range(0, mss):
			# Get the terrain height at a tile
			# COPY: Copied from an earlier iteration of the map generator
			var noise = get_terrain_map(x, y)
			
			# Set the terrain type depending on height
			# Adjusts the color slightly based on height/depth
			if noise > sea_level + 0.25:
				# Snowy peaks
				set_terrain_texture_map(x, y, 225 + round((noise-0.11) * 30), 225 + round((noise-0.11) * 30), 245 + round((noise-0.11) * 10))
			elif noise > sea_level + 0.2:
				# Mountain slopes
				set_terrain_texture_map(x, y, 64 + round((noise-0.11) * 191), 64 + round((noise-0.11) * 191), 64 + round((noise-0.11) * 191))
			elif noise > sea_level + 0.015:
				# Grassy plains
				set_terrain_texture_map(x, y, 10 + round((noise-0.11) * 245), 128 + round((noise-0.11) * 127), 25 + round((noise-0.11) * 230))
			elif noise > sea_level:
				# Beaches
				set_terrain_texture_map(x, y, 206, 202, 159)
			else:
				# Water
				set_terrain_texture_map(x, y, 70 + round((noise) * 70), 70 + round((noise) * 70), 230 + round((noise) * 200))

# Adds the map texture to the sprite
func set_image_from_map():
	# Initialize the image and texture
	# COPY Copied from docs
	var texture = ImageTexture.new()
	var image = Image.new()
	
	# Get a ByteArray of the texture map
	var bytearray_map = PoolByteArray(texture_map)
	
	# Some error handling
	if not bytearray_map.size() == map_size_square * map_size_square * 3:
		push_warning("WARNING: Map size and Image are not the same size!")
		push_warning("Map is " + str((bytearray_map.size() / (map_size_square * map_size_square * 3)) * 100) + "% of proper size.")
		
		if not map_generated:
			push_warning("Possible reason: Map wasn't generated.")
	
	# Create an image from the bytearray
	image.create_from_data(map_size_square, map_size_square, false, 4, bytearray_map)
	
	# Create a texture from the image
	texture.create_from_image(image)
	# Remove filters
	texture.flags = 0
	
	# Return it
	return texture

# Same as set_image_from_map(). See above for a breakdown
func set_image_from_map_arg(map_arg, map_size_square_arg):
	# COPY Copied from docs
	var texture = ImageTexture.new()
	var image = Image.new()
	
	var bytearray_map = PoolByteArray(map_arg)
	
	if not bytearray_map.size() == map_size_square_arg * map_size_square_arg * 3:
		push_warning("WARNING: Map size and Image are not the same size!")
		push_warning("Map is " + str((bytearray_map.size() / (map_size_square_arg * map_size_square_arg * 3)) * 100) + "% of proper size.")
		
		if not map_generated:
			push_warning("Possible reason: Map wasn't generated.")
	
	image.create_from_data(map_size_square_arg, map_size_square_arg, false, 4, bytearray_map)
	
	texture.create_from_image(image)
	
	texture.flags = 0
	
	return texture

# Initializez stuff
func _ready():
	# Setup the varios mapgen noises
	# TODO: move this and mapgen to a menu
	# COPY: Copied and modified from docs
	terrain_noise.seed = randi()
	terrain_noise.octaves = 5
	terrain_noise.period = 384
	terrain_noise.persistence = terrain_persistence
	terrain_noise.lacunarity = 3
	
	big_noise.seed = randi()
	big_noise.octaves = 5
	big_noise.period = 512
	big_noise.persistence = terrain_persistence
	big_noise.lacunarity = 3
	
	terrain_adjuster.seed = randi()
	terrain_adjuster.octaves = 3
	terrain_adjuster.period = 384
	terrain_adjuster.persistence = 0.6
	terrain_adjuster.lacunarity = 2.5
	
	# Generate a map
	gen_map()
	
	# Gets a texture
	var texture = set_image_from_map()
	
	# Sets the texture to a sprite
	map_sprite.texture = texture
	
	# Set it's position for alignment
	var align = map_size_square / 2
	map_sprite.position = Vector2(align, align)
	
	spawn_cities()
	
# A thread for set_image_from_map()
func sifm_thread(data):
	var texture = set_image_from_map_arg(data[0], data[1])
	
	draw_mutex.lock()
	map_sprite.texture = texture
	draw_mutex.unlock()

# A thread for refresh_map()
func rm_thread(mss):
	refresh_map_arg(mss)
	
# Do this stuff every frame on the main thread
func _process(delta):
	
	# Thread stuff
	
	# Check to see if the threads are finished and if so, kill them
	if not update_sprite_thread == null:
		if not update_sprite_thread.is_alive():
			update_sprite_thread.wait_to_finish()
			update_sprite_thread = null
	if not refresh_map_thread == null:
		if not refresh_map_thread.is_alive():
			refresh_map_thread.wait_to_finish()
			refresh_map_thread = null
			
	# Start the threads
	# TODO: Maybe re-start the threads as soon as they finish?
	if frame % 60 == 0 and update_sprite_thread == null:
		# COPY: Copied and modified from docs
		update_sprite_thread = Thread.new()
		update_sprite_thread.start(self, "sifm_thread", [texture_map, map_size_square])
	if frame % 60 == 20 and refresh_map_thread == null:
		# COPY: Copied and modified from docs
		refresh_map_thread = Thread.new()
		refresh_map_thread.start(self, "rm_thread", map_size_square)
		
	# Zoom in or out
	if zoom_in:
		map_scale -= (map_scale / 35.0)
	if zoom_out:
		map_scale += (map_scale / 35.0)
		
	# Apply the zooming
	camera.zoom = Vector2(map_scale, map_scale)
	
	# Increase frame, for thread operations
	frame += 1
	
# Wait for the threads to finish before exiting.
func _exit_tree():
	if not update_sprite_thread == null:
		update_sprite_thread.wait_to_finish()
	if not refresh_map_thread == null:
		refresh_map_thread.wait_to_finish()

# The next four functions are signals for when the zooming buttons are pressed/released
func _on_ZoomIn_button_down():
	zoom_out = false
	zoom_in = true


func _on_ZoomIn_button_up():
	zoom_in = false


func _on_ZoomOut_button_down():
	zoom_out = true
	zoom_in = false


func _on_ZoomOut_button_up():
	zoom_out = false

# Generates city names
func generate_city_name():
	var vowels = ["a", "e", "i", "o", "u", "ee", "oo", "aa"]
	var consonants = ["q", "w", "r", "t", "y", "p", "s", "d", "f", "g", "h", "j", "k", "l", "z", "x", "c", "v", "b", "n", "m", "'"]
	
	var result = ""
	
	# Combine the letters into some words
	for _i in range(0, rand_range(2, 4)):
		result = result + consonants[rand_range(0, len(consonants) - 1)] + vowels[rand_range(0, len(vowels) - 1)]
		
		if rand_range(1, 3) == 1:
			result = result + consonants[rand_range(0, len(consonants) - 1)]
			
	return result.capitalize()

func spawn_cities():
	for i in cities:
		var ins = city.instance()
		
		ins.city_name = i["name"]
		ins.position = i["position"]
		
		city_controller.add_child(ins)
