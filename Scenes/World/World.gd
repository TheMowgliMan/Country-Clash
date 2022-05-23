extends Node2D

var texture_map = []
var map = []
var map_size_square = 512
var map_generated = false

var terrain_noise = OpenSimplexNoise.new()
var big_noise = OpenSimplexNoise.new()
var terrain_adjuster = OpenSimplexNoise.new()
var terrain_persistence = 0.6

var frame = 1
var update_sprite_thread = null
var refresh_map_thread = null

onready var map_sprite = $RenderManager/MapRender

var draw_mutex = Mutex.new()
var assign_map_mutex = Mutex.new()

func get_terrain_texture_map(x, y):
	# HACK: Basic map is stored as RGB8 values
	return [texture_map[x * (map_size_square * 3) + y * 3], texture_map[x * (map_size_square * 3) + y * 3 + 1], texture_map[x * (map_size_square * 3) + y * 3 + 2]]
	
func set_terrain_texture_map(x, y, data1, data2, data3):
	assign_map_mutex.lock()
	texture_map[x * (map_size_square * 3) + y * 3] = data1
	texture_map[x * (map_size_square * 3) + y * 3 + 1] = data2
	texture_map[x * (map_size_square * 3) + y * 3 + 2] = data3
	assign_map_mutex.unlock()

func set_terrain_map(x, y, data):
	assign_map_mutex.lock()
	map[x * map_size_square + y] = data
	assign_map_mutex.unlock()
	
func get_terrain_map(x, y):
	return map[x * map_size_square + y]

func gen_map():
	for _i in range(0, map_size_square * map_size_square * 3):
		map.append(0)
		texture_map.append(0)
	
	for x in range(0, map_size_square):
		for y in range(0, map_size_square):
			var adjuster_noise = terrain_adjuster.get_noise_2d(x, y)
			terrain_noise.persistence = terrain_persistence + (adjuster_noise * 0.25)
			
			var terr_noise = terrain_noise.get_noise_2d(x, y)
			var b_noise = big_noise.get_noise_2d(x, y)
			var noise = ((terr_noise * 0.5) + b_noise) / 1.5
			
			set_terrain_map(x, y, noise)
	
	refresh_map()
			
func refresh_map():
	for x in range(0, map_size_square):
		for y in range(0, map_size_square):
			var noise = get_terrain_map(x, y)
			
			if noise > 0.12:
				set_terrain_texture_map(x, y, 10 + round((noise-0.11) * 245), 128 + round((noise-0.11) * 127), 25 + round((noise-0.11) * 230))
			elif noise > 0.11:
				set_terrain_texture_map(x, y, 206, 202, 159)
			else:
				set_terrain_texture_map(x, y, 70 + round((noise) * 70), 70 + round((noise) * 70), 230 + round((noise) * 200))

func refresh_map_arg(mss):
	for x in range(0, mss):
		for y in range(0, mss):
			var noise = get_terrain_map(x, y)
			
			if noise > 0.12:
				set_terrain_texture_map(x, y, 10 + round((noise-0.11) * 245), 128 + round((noise-0.11) * 127), 25 + round((noise-0.11) * 230))
			elif noise > 0.11:
				set_terrain_texture_map(x, y, 206, 202, 159)
			else:
				set_terrain_texture_map(x, y, 70 + round((noise) * 70), 70 + round((noise) * 70), 230 + round((noise) * 200))

			
func set_image_from_map():
	# COPY Copied from docs
	var texture = ImageTexture.new()
	var image = Image.new()
	
	var bytearray_map = PoolByteArray(texture_map)
	
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

	gen_map()

	var texture = set_image_from_map()

	map_sprite.texture = texture
	
func sifm_thread(data):
	var texture = set_image_from_map_arg(data[0], data[1])
	
	draw_mutex.lock()
	map_sprite.texture = texture
	draw_mutex.unlock()
	
func rm_thread(mss):
	refresh_map_arg(mss)
	
func _process(delta):
	if not update_sprite_thread == null:
		if not update_sprite_thread.is_alive():
			update_sprite_thread.wait_to_finish()
			update_sprite_thread = null
	if not refresh_map_thread == null:
		if not refresh_map_thread.is_alive():
			refresh_map_thread.wait_to_finish()
			refresh_map_thread = null
	if frame % 60 == 0 and update_sprite_thread == null:
		update_sprite_thread = Thread.new()
		update_sprite_thread.start(self, "sifm_thread", [texture_map, map_size_square])
	if frame % 60 == 20 and refresh_map_thread == null:
		refresh_map_thread = Thread.new()
		refresh_map_thread.start(self, "rm_thread", [texture_map, map_size_square])
		
	frame += 1
	
func _exit_tree():
	if not update_sprite_thread == null:
		update_sprite_thread.wait_to_finish()
	if not refresh_map_thread == null:
		refresh_map_thread.wait_to_finish()
