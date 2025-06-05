package invaders

import rl "vendor:raylib"

// Create and initialize a new game
init_game :: proc() -> Game {
	game: Game

	// Initialize dynamic arrays
	game.player_bullets = make([dynamic]Bullet)
	game.alien_bullets = make([dynamic]Bullet)
	game.explosions = make([dynamic]Explosion)

	// Set initial values
	game.player_pos_x = f32(SCREEN_GRID_SIZE - PLAYER_SIZE) * 0.5
	game.lifes_available = 3
	game.difficulty = 0
	game.alien_direction = 1
	game.alien_animation_timer = 0
	game.alien_current_frame = 0

	// Initialize the game state
	restart(&game, game.difficulty)

	return game
}

// Init or restart game for new round
restart :: proc(game: ^Game, difficulty_to_use: f32) {
	delete_bullets(game)
	game.player_pos_x = f32(SCREEN_GRID_SIZE - PLAYER_SIZE) * 0.5
	game.alien_direction = 1
	game.round_total_shots = 0
	game.ufo_time = 0
	place_aliens(game, difficulty_to_use)
	for &shield, i in game.shields {
		shield = create_shield(
			2 * f32(i + 1) * SCREEN_GRID_SIZE / 10 - SHIELD_WIDTH / 2,
			SHIELD_Y_POS,
		)
	}

	// Clear explosions
	if len(game.explosions) > 0 {
		remove_range(&game.explosions, 0, len(game.explosions))
	}
}

// Initialize alien sprites from spritesheet
init_alien_sprites :: proc(spritesheet_path: cstring) -> AlienSprites {
	sprites := AlienSprites{}

	// Load the sprite sheet texture
	sprites.texture = rl.LoadTexture(spritesheet_path)

	// Small aliens (top row, magenta)
	sprites.small_frames[0] = {24, 2, 12, 12} // Frame 1 position in spritesheet
	sprites.small_frames[1] = {48, 2, 12, 12} // Frame 2 position in spritesheet

	// Medium aliens (middle row, cyan)
	sprites.medium_frames[0] = {24, 18, 16, 12} // Frame 1 position in spritesheet
	sprites.medium_frames[1] = {48, 18, 16, 12} // Frame 2 position in spritesheet

	// Large aliens (bottom row, green)
	sprites.large_frames[0] = {24, 34, 20, 12} // Frame 1 position in spritesheet
	sprites.large_frames[1] = {48, 34, 20, 12} // Frame 2 position in spritesheet

	// Explosion animation frames
	sprites.explosion_frames[0] = {72, 34, 20, 12} // Explosion frame 1
	sprites.explosion_frames[1] = {96, 34, 20, 12} // Explosion frame 2
	sprites.explosion_frames[2] = {120, 34, 20, 12} // Explosion frame 3

	// Player ship
	sprites.player_ship = {72, 18, 20, 10}

	// UFO
	sprites.ufo = {72, 2, 20, 14}

	return sprites
}

// TODO: update crappy crt shader
setup_shader :: proc() -> (rl.RenderTexture2D, rl.Shader, i32) {
	// setup the kinda crt shader
	target_texture := rl.LoadRenderTexture(SCREEN_GRID_SIZE, SCREEN_GRID_SIZE)
	crt_shader := rl.LoadShader(nil, "assets/crt.glsl")

	i_time_loc := rl.GetShaderLocation(crt_shader, "iTime")
	screen_resolution_loc := rl.GetShaderLocation(crt_shader, "screenResolution")
	curvature_loc := rl.GetShaderLocation(crt_shader, "curvature")
	width := rl.GetScreenWidth()
	height := rl.GetScreenHeight()
	size := height > width ? height : width

	screen_resolution: [2]f32 = {f32(size), f32(size)}
	rl.SetShaderValue(crt_shader, screen_resolution_loc, &screen_resolution, .VEC2)

	curvature: f32 = 30
	rl.SetShaderValue(crt_shader, curvature_loc, &curvature, .FLOAT)

	return target_texture, crt_shader, i_time_loc
}

place_aliens :: proc(game: ^Game, difficulty_to_use: f32) {
	start_y := (SCREEN_GRID_SIZE - ALIENS_BLOCK_HEIGHT) * 0.2 + difficulty_to_use * 7

	for alien in 0 ..< ALIENS_NUM_X * ALIENS_NUM_Y {
		game.alien_alive[alien] = true
		row := int(alien / ALIENS_NUM_X)
		y: f32 = start_y + f32(row) * (ALIENS_SPACING + ALIEN_SIZE)

		width: f32
		points: f32

		if row == 0 {
			width = 6
			points = 30
		} else if row < 3 {
			width = 8
			points = 20
		} else {
			width = 10
			points = 10
		}

		x: f32 = (ALIENS_BLOCK_WIDTH - 16) * 0.5 - width * 0.5 + f32(alien % ALIENS_NUM_X) * 16

		game.alien_stats[alien] = {x, y, width, points}
	}
	game.num_aliens_alive = ALIENS_NUM_X * ALIENS_NUM_Y
	game.last_alien_moved_x = game.num_aliens_alive - 1
	game.last_alien_moved_y = -1

	// Reset animation
	game.alien_animation_timer = 0
	game.alien_current_frame = 0
}

create_shield :: proc(x, y: f32) -> Shield {
	pixels: [SHIELD_WIDTH][SHIELD_HEIGHT]bool
	end_part := SHIELD_HEIGHT / 6
	first_part := SHIELD_HEIGHT / 4
	plain_part := SHIELD_HEIGHT / 2
	arch_part := 3 * SHIELD_HEIGHT / 5 + end_part

	for y in 0 ..< SHIELD_HEIGHT {
		for x in 0 ..< SHIELD_WIDTH {
			if y < first_part {
				if x < first_part - y || x > SHIELD_WIDTH - (first_part - y + 1) {
					pixels[x][y] = false
				} else {
					pixels[x][y] = true
				}
			} else if y < plain_part {
				pixels[x][y] = true
			} else if y < arch_part {
				if x < (arch_part + (end_part * 2) - y) ||
				   x > SHIELD_WIDTH - (arch_part + (end_part * 2) - y + 1) {
					pixels[x][y] = true
				}
			} else if y < SHIELD_HEIGHT - end_part {
				if x < (end_part * 2) || x > SHIELD_WIDTH - (end_part * 2) - 1 {
					pixels[x][y] = true
				}
			}
		}
	}

	// Add bounds rectangle for faster collision checking
	bounds := rl.Rectangle {
		x      = x,
		y      = y,
		width  = SHIELD_WIDTH,
		height = SHIELD_HEIGHT,
	}

	return Shield{position = {x, y}, pixels = pixels, bounds = bounds}
}
