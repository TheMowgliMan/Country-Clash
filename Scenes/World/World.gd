extends Node2D

var map = []
var map_size_square = 512
var map_generated = false

var terrain_noise = OpenSimplexNoise.new()

var frame = 1
var thread = null

onready var map_sprite = $RenderManager/MapRender

var draw_mutex = Mutex.new()

func get_terrain_map_item(x, y):
	# HACK: Basic map is stored as RGB8 values
	return [map[x * (map_size_square * 3) + y * 3], map[x * (map_size_square * 3) + y * 3 + 1], map[x * (map_size_square * 3) + y * 3 + 2]]
	
func set_terrain_map_item(x, y, data1, data2, data3):
	map[x * (map_size_square * 3) + y * 3] = data1
	map[x * (map_size_square * 3) + y * 3 + 1] = data2
	map[x * (map_size_square * 3) + y * 3 + 2] = data3

func gen_map():
	for _i in range(0, map_size_square * map_size_square * 3):
		map.append(0)
	
	for x in range(0, map_size_square):
		for y in range(0, map_size_square):
			var noise = terrain_noise.get_noise_2d(x, y)
			if noise > 0:
				set_terrain_map_item(x, y, 10, 255, 50)
			else:
				set_terrain_map_item(x, y, 70, 70, 230)
			
func set_image_from_map():
	# COPY Copied from docs
	var texture = ImageTexture.new()
	var image = Image.new()
	
	var bytearray_map = PoolByteArray(map)
	
	if not bytearray_map.size() == map_size_square * map_size_square * 3:
		push_warning("WARNING: Map size and Image are not the same size!")
		push_warning("Map is " + str((bytearray_map.size() / (map_size_square * map_size_square * 3)) * 100) + "% of proper size.")
		
		if not map_generated:
			push_warning("Possible reason: Map wasn't generated.")
	
	image.create_from_data(map_size_square, map_size_square, false, 4, bytearray_map)
	
	texture.create_from_image(image)
	
	return texture
	
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
	
	return texture
	
func _ready():
	terrain_noise.seed = randi()
	terrain_noise.octaves = 5
	terrain_noise.period = 128
	terrain_noise.persistence = 0.6
	terrain_noise.lacunarity = 2.5

	gen_map()

	var texture = set_image_from_map()

	map_sprite.texture = texture
	
func sifm_thread(data):
	var texture = set_image_from_map_arg(data[0], data[1])
	
	draw_mutex.lock()
	map_sprite.texture = texture
	draw_mutex.unlock()
	
func _process(delta):
	if not thread == null:
		if not thread.is_alive():
			thread.wait_to_finish()
			thread = null
	if frame % 60 == 0 and thread == null:
		thread = Thread.new()
		thread.start(self, "sifm_thread", [map, map_size_square])
		
	frame += 1
	
func _exit_tree():
	thread.wait_to_finish()
