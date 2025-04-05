package invaders

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

// Constants remain the same
SCREEN_SIZE :: 800
SCREEN_GRID_SIZE :: 320
PLAYER_SIZE :: 10
PLAYER_POS_Y :: 280
PLAYER_SPEED :: 100

BULLET_SPEED :: 400
ALIEN_BULLET_SPEED :: 100
MAX_BULLET :: 20
BULLET_SIZE :: rl.Vector2{2, 4}

ALIEN_SIZE :: 10
SMALL_ALIENS_ROW :: 1
MEDIUM_ALIENS_ROW :: 2
BIG_ALIENS_ROW :: 2
ALIENS_NUM_X :: 11
ALIENS_NUM_Y :: SMALL_ALIENS_ROW + MEDIUM_ALIENS_ROW + BIG_ALIENS_ROW
ALIENS_SPACING :: 6
ALIENS_BLOCK_WIDTH :: (ALIENS_NUM_X) * (ALIENS_SPACING + ALIEN_SIZE)
ALIENS_BLOCK_HEIGHT :: (ALIENS_NUM_Y) * (ALIENS_SPACING + ALIEN_SIZE)
SMALL_ALIENS_POINTS :: 30
MEDIUM_ALIENS_POINTS :: 20
BIG_ALIENS_POINTS :: 10

SHIELD_Y_POS :: 250
SHIELD_HEIGHT :: 20
SHIELD_WIDTH :: 29
SHIELD_IMPACT_RADIUS :: 4

// Animation constants
ANIMATION_SPEED :: 0.5 // seconds per frame
EXPLOSION_FRAMES :: 3
EXPLOSION_DURATION :: 0.25 // seconds

// Type definitions
Shield :: struct {
	position: rl.Vector2,
	pixels:   [SHIELD_WIDTH][SHIELD_HEIGHT]bool,
	bounds:   rl.Rectangle, // Added for faster bounds checking
}

Bullet :: struct {
	position:         rl.Vector2,
	size:             rl.Vector2,
	is_player_bullet: bool,
}

Explosion :: struct {
	position: rl.Vector2,
	timer:    f32,
	frame:    int,
	active:   bool,
}

// Single Game struct that contains all game state
Game :: struct {
	// Player variables
	player_pos_x:          f32,
	player_bullets:        [dynamic]Bullet, // Changed to Bullet struct
	lifes_available:       int,

	// Alien variables
	alien_direction:       int,
	num_aliens_alive:      int,
	alien_alive:           [ALIENS_NUM_X * ALIENS_NUM_Y]bool,
	alien_stats:           [ALIENS_NUM_X * ALIENS_NUM_Y]rl.Vector4,
	last_alien_moved_x:    int,
	last_alien_moved_y:    int,
	alien_bullets:         [dynamic]Bullet, // Changed to Bullet struct
	alien_animation_timer: f32,
	alien_current_frame:   int,

	// Shield variables
	shields:               [4]Shield,

	// Explosion variables
	explosions:            [dynamic]Explosion,

	// Game state variables
	ufo_time:              f32,
	accumulated_time:      f32,
	accumulated_time2:     f32,
	game_over:             bool,
	difficulty:            f32,
	score:                 f32,
	round_total_shots:     u8,
}

// Sprite sheet texture
AlienSprites :: struct {
	texture:          rl.Texture2D,
	small_frames:     [2]rl.Rectangle,
	medium_frames:    [2]rl.Rectangle,
	large_frames:     [2]rl.Rectangle,
	explosion_frames: [3]rl.Rectangle,
	player_ship:      rl.Rectangle,
	ufo:              rl.Rectangle,
}

// Function to create a shield (improved with bounds)
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
	sprites.ufo = {72, 2, 20, 10}

	return sprites
}

// Updated functions to use the Game struct
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

// Improved collision detection between alien and shield
alien_over_shield :: proc(game: ^Game, alien: rl.Vector4, offset: int) {
	if alien.y + alien.w > SHIELD_Y_POS {
		alien_rect := rl.Rectangle {
			x      = alien.x,
			y      = alien.y - f32(offset),
			width  = alien.z,
			height = alien.z + f32(offset),
		}

		for &shield in game.shields {
			// Quick bounds check first
			if !rl.CheckCollisionRecs(alien_rect, shield.bounds) {
				continue
			}

			// Only check pixels if bounds collide
			for x in 0 ..< SHIELD_WIDTH {
				for y in 0 ..< SHIELD_HEIGHT {
					if !shield.pixels[x][y] {
						continue
					}

					pixel_pos := rl.Vector2{shield.position.x + f32(x), shield.position.y + f32(y)}

					if rl.CheckCollisionPointRec(pixel_pos, alien_rect) {
						shield.pixels[x][y] = false
					}
				}
			}
		}
	}
}

move_alien_horizontally :: proc(game: ^Game) {
	if game.alien_alive[game.last_alien_moved_x] {
		game.alien_stats[game.last_alien_moved_x].x =
			f32(game.alien_direction * 2) + game.alien_stats[game.last_alien_moved_x].x

		alien := game.alien_stats[game.last_alien_moved_x]
		alien_over_shield(game, alien, 0)
	}
	game.last_alien_moved_x =
		game.last_alien_moved_x > 0 ? game.last_alien_moved_x - 1 : len(game.alien_stats) - 1
}

move_alien_vertically :: proc(game: ^Game) {
	if game.alien_alive[game.last_alien_moved_y] {
		game.alien_stats[game.last_alien_moved_y].y =
			game.alien_stats[game.last_alien_moved_y].y + ALIEN_SIZE

		alien := game.alien_stats[game.last_alien_moved_y]
		alien_over_shield(game, alien, ALIENS_SPACING)
	}
	game.last_alien_moved_y -= 1
}

// Function to create a new bullet
create_bullet :: proc(x, y: f32, is_player: bool) -> Bullet {
	return Bullet{position = {x, y}, size = BULLET_SIZE, is_player_bullet = is_player}
}

// Create a new explosion
create_explosion :: proc(x, y: f32) -> Explosion {
	return Explosion{position = {x, y}, timer = 0, frame = 0, active = true}
}

delete_bullets :: proc(game: ^Game) {
	if len(game.alien_bullets) > 0 {
		remove_range(&game.alien_bullets, 0, len(game.alien_bullets))
	}
	if len(game.player_bullets) > 0 {
		remove_range(&game.player_bullets, 0, len(game.player_bullets))
	}
}

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

// Helper function to handle shield damage
damage_shield :: proc(shield: ^Shield, x, y: int) {
	// Apply spherical blast damage pattern
	for dx in -SHIELD_IMPACT_RADIUS ..= SHIELD_IMPACT_RADIUS {
		for dy in -SHIELD_IMPACT_RADIUS ..= SHIELD_IMPACT_RADIUS {
			new_x := x + dx
			new_y := y + dy

			// Check if within shield bounds
			if new_x >= 0 && new_x < SHIELD_WIDTH && new_y >= 0 && new_y < SHIELD_HEIGHT {
				// Calculate distance from impact center (squared to avoid sqrt operation)
				dist_sq := f32(dx * dx + dy * dy)

				// Create spherical falloff pattern
				if dist_sq <= SHIELD_IMPACT_RADIUS * SHIELD_IMPACT_RADIUS {
					// Define inner radius for guaranteed damage (about 60% of total radius)
					inner_radius_sq: f32 =
						(f32(SHIELD_IMPACT_RADIUS) * 0.6) * (f32(SHIELD_IMPACT_RADIUS) * 0.6)

					if dist_sq <= inner_radius_sq {
						// Inner area - always damage these pixels
						shield.pixels[new_x][new_y] = false
					} else {
						// Outer area - apply probability based on distance
						damage_prob :=
							1.0 -
							((dist_sq - inner_radius_sq) /
									(f32(SHIELD_IMPACT_RADIUS) * f32(SHIELD_IMPACT_RADIUS) -
											inner_radius_sq))

						// Apply randomized damage with distance-based probability
						if rand.float32() < damage_prob {
							shield.pixels[new_x][new_y] = false
						}
					}
				}
			}
		}
	}
}

// Get bullet rectangle for collision detection
get_bullet_rect :: proc(bullet: Bullet) -> rl.Rectangle {
	return rl.Rectangle {
		x = bullet.position.x,
		y = bullet.position.y,
		width = bullet.size.x,
		height = bullet.size.y,
	}
}

// Centralized collision detection for bullets and shields
check_bullet_shield_collision :: proc(bullet: Bullet, shield: ^Shield) -> bool {
	bullet_rect := get_bullet_rect(bullet)

	// Quick bounds check first
	if !rl.CheckCollisionRecs(bullet_rect, shield.bounds) {
		return false
	}

	// Only if bounds collide, check pixels
	for y in 0 ..< SHIELD_HEIGHT {
		for x in 0 ..< SHIELD_WIDTH {
			if !shield.pixels[x][y] {
				continue
			}

			pixel_pos := rl.Vector2{shield.position.x + f32(x), shield.position.y + f32(y)}

			if rl.CheckCollisionPointRec(pixel_pos, bullet_rect) {
				damage_shield(shield, x, y)
				return true
			}
		}
	}

	return false
}

// Check collision between bullets
check_bullet_collision :: proc(bullet1, bullet2: Bullet) -> bool {
	rect1 := get_bullet_rect(bullet1)
	rect2 := get_bullet_rect(bullet2)

	return rl.CheckCollisionRecs(rect1, rect2)
}

// Check collision between bullet and alien
check_bullet_alien_collision :: proc(bullet: Bullet, alien_stats: rl.Vector4) -> bool {
	bullet_rect := get_bullet_rect(bullet)
	alien_rect := rl.Rectangle {
		x      = alien_stats.x,
		y      = alien_stats.y,
		width  = alien_stats.z,
		height = alien_stats.z,
	}

	return rl.CheckCollisionRecs(bullet_rect, alien_rect)
}

// Check collision between bullet and player
check_bullet_player_collision :: proc(bullet: Bullet, player_x: f32) -> bool {
	bullet_rect := get_bullet_rect(bullet)

	// Use dimensions that match the player ship sprite (20×10)
	player_rect := rl.Rectangle {
		// Center the player rectangle on the player position
		x      = player_x - 5, // Adjust x to center the collision box
		y      = PLAYER_POS_Y - 5, // Adjust y to align with the sprite
		width  = 20, // Match the player ship sprite width
		height = 10, // Match the player ship sprite height
	}

	// If we detect a basic rectangle collision first
	if rl.CheckCollisionRecs(bullet_rect, player_rect) {
		// Then do a more precise check considering the pyramid shape
		// The player sprite is triangular/pyramid shaped, so we need additional logic
		// to see if the bullet is actually hitting the visible part

		// Calculate relative position of bullet within player rectangle
		rel_x := bullet_rect.x - player_rect.x
		rel_y := bullet_rect.y - player_rect.y

		// Check if bullet overlaps with the pyramid shape
		// The pyramid gets wider as y increases:
		// - At the top (rel_y = 0), it's 2 pixels wide centered
		// - At the middle (rel_y = 4), it's 12 pixels wide
		// - At the bottom (rel_y = 8-10), it's the full 20 pixels wide

		if rel_y >= 0 && rel_y < player_rect.height {
			// Figure out the width of the pyramid at this y-coordinate
			// Width increases as we go down (as y increases)
			width_at_y: f32
			if rel_y < 2 {
				width_at_y = 2 // Top part (narrowest)
			} else if rel_y < 4 {
				width_at_y = 8 // Middle-top part
			} else if rel_y < 6 {
				width_at_y = 12 // Middle part
			} else if rel_y < 8 {
				width_at_y = 16 // Middle-bottom part
			} else {
				width_at_y = 20 // Bottom part (widest)
			}

			// Calculate x-range for pyramid at this y-level
			left_edge := (player_rect.width - width_at_y) / 2
			right_edge := left_edge + width_at_y

			// Check if bullet's x position overlaps with pyramid at this y-level
			// This checks if any part of the bullet overlaps with pyramid
			bullet_right := rel_x + bullet_rect.width
			if rel_x < right_edge && bullet_right > left_edge {
				return true
			}
		}

		return false // Bullet hit rectangle but missed the pyramid shape
	}

	return false // No rectangle collision
}

// Update explosions
update_explosions :: proc(game: ^Game, dt: f32) {
	for i := len(game.explosions) - 1; i >= 0; i -= 1 {
		explosion := &game.explosions[i]

		explosion.timer += dt

		// Update explosion frame
		frame_duration := EXPLOSION_DURATION / f32(EXPLOSION_FRAMES)
		explosion.frame = int(explosion.timer / frame_duration)

		// Remove explosion when animation is complete
		if explosion.timer >= EXPLOSION_DURATION {
			unordered_remove(&game.explosions, i)
		}
	}
}

// Update bullets
update_bullets :: proc(game: ^Game, dt: f32) {
	// Update player bullets
	for i := len(game.player_bullets) - 1; i >= 0; i -= 1 {
		bullet := &game.player_bullets[i]

		// Move bullet
		bullet.position.y -= BULLET_SPEED * dt

		// Check if bullet went off screen
		if bullet.position.y < -bullet.size.y {
			unordered_remove(&game.player_bullets, i)
			continue
		}

		// Check collision with shields
		had_shield_collision := false
		for &shield in game.shields {
			if check_bullet_shield_collision(game.player_bullets[i], &shield) {
				// Add explosion at the collision point
				bullet_pos := game.player_bullets[i].position
				explosion := create_explosion(bullet_pos.x - 9, bullet_pos.y - 4) // Center explosion
				append(&game.explosions, explosion)

				unordered_remove(&game.player_bullets, i)
				had_shield_collision = true
				break
			}
		}
		if had_shield_collision {
			continue
		}

		// Check collision with aliens
		for alien_stat, alien_index in game.alien_stats {
			if !game.alien_alive[alien_index] {
				continue
			}

			if check_bullet_alien_collision(game.player_bullets[i], alien_stat) {
				game.alien_alive[alien_index] = false

				// Create explosion at alien position
				explosion := create_explosion(
					alien_stat.x - alien_stat.z * 0.5,
					alien_stat.y - alien_stat.z * 0.25,
				)
				append(&game.explosions, explosion)

				unordered_remove(&game.player_bullets, i)
				game.num_aliens_alive -= 1
				game.score += alien_stat.w

				if game.num_aliens_alive == 0 {
					game.difficulty = f32(int(1 + game.difficulty) % 11)
					restart(game, game.difficulty)
				}
				break
			}
		}
	}

	// Update alien bullets
	for i := len(game.alien_bullets) - 1; i >= 0; i -= 1 {
		bullet := &game.alien_bullets[i]

		// Move bullet
		bullet.position.y += ALIEN_BULLET_SPEED * dt

		// Check if bullet went off screen
		if bullet.position.y > SCREEN_GRID_SIZE {
			unordered_remove(&game.alien_bullets, i)
			continue
		}

		// Check collision with player bullets
		for j := len(game.player_bullets) - 1; j >= 0; j -= 1 {
			if check_bullet_collision(game.alien_bullets[i], game.player_bullets[j]) {
				// Create explosion at collision point
				bullet_pos := game.alien_bullets[i].position
				explosion := create_explosion(
					game.alien_bullets[i].position.x - game.alien_bullets[i].size.x * 4,
					game.alien_bullets[i].position.y - game.alien_bullets[i].size.y,
				)
				append(&game.explosions, explosion)

				if i < len(game.alien_bullets) { 	// Make sure index is still valid
					unordered_remove(&game.alien_bullets, i)
				}
				unordered_remove(&game.player_bullets, j)
				break
			}
		}

		// Skip if bullet was removed in collision with player bullet
		if i >= len(game.alien_bullets) {
			continue
		}

		// Check collision with shields
		had_shield_collision := false
		for &shield in game.shields {
			if check_bullet_shield_collision(game.alien_bullets[i], &shield) {
				// Create explosion at collision point
				// bullet_pos := game.alien_bullets[i].position
				explosion := create_explosion(
					game.alien_bullets[i].position.x - game.alien_bullets[i].size.x * 4,
					game.alien_bullets[i].position.y - game.alien_bullets[i].size.y,
				)
				append(&game.explosions, explosion)

				unordered_remove(&game.alien_bullets, i)
				had_shield_collision = true
				break
			}
		}
		if had_shield_collision {
			continue
		}

		// Check collision with player
		if check_bullet_player_collision(game.alien_bullets[i], game.player_pos_x) {
			game.lifes_available -= 1

			// Create explosion at player position
			explosion := create_explosion(
				game.alien_bullets[i].position.x - game.alien_bullets[i].size.x * 4,
				game.alien_bullets[i].position.y - game.alien_bullets[i].size.y,
			)
			append(&game.explosions, explosion)

			unordered_remove(&game.alien_bullets, i)

			if game.lifes_available < 1 {
				game.game_over = true
			}
		}
	}
}

// Update alien animation
update_alien_animation :: proc(game: ^Game, dt: f32) {
	game.alien_animation_timer += dt

	if game.alien_animation_timer >= ANIMATION_SPEED {
		game.alien_animation_timer = 0
		game.alien_current_frame = (game.alien_current_frame + 1) % 2
	}
}

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(SCREEN_SIZE, SCREEN_SIZE, "Space Invaders")
	defer rl.CloseWindow()

	rl.SetTargetFPS(200)

	// Initialize the game state
	game := init_game()
	defer {
		delete(game.player_bullets) // Clean up dynamic arrays
		delete(game.alien_bullets)
		delete(game.explosions)
	}

	// Load sprites
	sprites := init_alien_sprites("alien-sprites.png")
	defer rl.UnloadTexture(sprites.texture)

	// kinda crt shader
	target_texture := rl.LoadRenderTexture(SCREEN_GRID_SIZE, SCREEN_GRID_SIZE)
	crt_shader := rl.LoadShader(nil, "crt.glsl")

	i_time_loc := rl.GetShaderLocation(crt_shader, "iTime")
	screen_resolution_loc := rl.GetShaderLocation(crt_shader, "screenResolution")
	curvature_loc := rl.GetShaderLocation(crt_shader, "curvature")

	screen_resolution: [2]f32 = {f32(SCREEN_SIZE), f32(SCREEN_SIZE)}
	rl.SetShaderValue(crt_shader, screen_resolution_loc, &screen_resolution, .VEC2)

	curvature: f32 = 30
	rl.SetShaderValue(crt_shader, curvature_loc, &curvature, .FLOAT)

	for !rl.WindowShouldClose() {
		dt := f32(game.num_aliens_alive) / (game.difficulty * 500 + 4000)
		time_elapsed := rl.GetTime()
		frame_time := rl.GetFrameTime()

		rl.SetShaderValue(crt_shader, i_time_loc, &time_elapsed, .FLOAT)

		// update state
		if !game.game_over {
			game.accumulated_time += frame_time

			player_move_velocity: f32
			if rl.IsKeyDown(.LEFT) {
				player_move_velocity -= PLAYER_SPEED
			}
			if rl.IsKeyDown(.RIGHT) {
				player_move_velocity += PLAYER_SPEED
			}

			if rl.IsKeyPressed(.SPACE) {
				if len(game.player_bullets) < 1 {
					new_bullet := create_bullet(
						game.player_pos_x + (PLAYER_SIZE - BULLET_SIZE.x) * 0.5,
						PLAYER_POS_Y - BULLET_SIZE.y,
						true,
					)
					append(&game.player_bullets, new_bullet)
					game.round_total_shots = (game.round_total_shots + 1) % 15
				}
			}

			// Update alien animation
			update_alien_animation(&game, frame_time)

			// Update explosions
			update_explosions(&game, frame_time)

			game.ufo_time += frame_time
			if game.ufo_time > 25.6 {
				// TODO: make ufo appear
				game.ufo_time = 0
			}

			// update
			for game.accumulated_time >= dt {
				// Update player position
				game.player_pos_x += player_move_velocity * dt
				game.player_pos_x = clamp(game.player_pos_x, 5, SCREEN_GRID_SIZE - PLAYER_SIZE - 5)

				// Update all bullets with the new centralized function
				update_bullets(&game, dt)

				// Move aliens
				move_alien_horizontally(&game)

				if game.last_alien_moved_y >= 0 {
					move_alien_vertically(&game)
				}

				// Alien shooting logic
				if game.accumulated_time2 > 0 {
					game.accumulated_time2 -= dt
				} else {
					if len(game.alien_bullets) < 3 {
						random_alien_to_count := rand.int_max(game.num_aliens_alive + 1)
						alien_to_fire: rl.Vector4
						alien_index: int
						for is_alive, index in game.alien_alive {
							if is_alive do random_alien_to_count -= 1
							if random_alien_to_count == 0 {
								alien_index = index
								break
							}
						}

						is_alive := game.alien_alive[alien_index]
						if is_alive {
							alien_to_fire = game.alien_stats[alien_index]
							new_bullet := create_bullet(
								alien_to_fire.x + alien_to_fire.z / 2,
								alien_to_fire.y + alien_to_fire.z,
								false,
							)
							append(&game.alien_bullets, new_bullet)

							random_time := rand.float32()
							game.accumulated_time2 = random_time + 0.2
						}
					}
				}

				// Check if aliens reached an edge or the player
				if game.last_alien_moved_x == len(game.alien_stats) - 1 {
					for alien, index in game.alien_stats {
						if game.alien_alive[index] {
							if alien.x < 10 || alien.x > SCREEN_GRID_SIZE - ALIEN_SIZE - 10 {
								game.alien_direction *= -1
								game.last_alien_moved_y = len(game.alien_stats) - 1
								break
							}
						}
						if alien.y > PLAYER_POS_Y {
							game.game_over = true
						}
					}
				}

				game.accumulated_time -= dt
			}

		} else {
			if rl.IsKeyPressed(.SPACE) {
				game.game_over = false
				game.difficulty = 1
				game.lifes_available = 3
				game.score = 0

				restart(&game, game.difficulty)
			}
		}

		// draw
		rl.BeginDrawing()
		defer rl.EndDrawing()

		camera := rl.Camera2D {
			zoom = f32(SCREEN_SIZE) / SCREEN_GRID_SIZE,
		}
		rl.BeginMode2D(camera)
		defer rl.EndMode2D()

		if !game.game_over {
			score_text := fmt.ctprint(game.score)
			rl.DrawText(score_text, 5, 5, 10, rl.WHITE)

			lifes_text := fmt.ctprintf("Lifes available: %v", game.lifes_available)
			lifes_text_size := rl.MeasureText(lifes_text, 10)
			rl.DrawText(lifes_text, SCREEN_GRID_SIZE - lifes_text_size - 5, 5, 10, rl.WHITE)

			// Draw player
			rl.DrawTextureRec(
				sprites.texture,
				sprites.player_ship,
				{game.player_pos_x - 5, PLAYER_POS_Y - 5}, // Center the sprite
				rl.WHITE,
			)

			for bullet in game.player_bullets {
				rl.DrawRectangleV(bullet.position, bullet.size, rl.YELLOW)
			}

			for bullet in game.alien_bullets {
				rl.DrawRectangleV(bullet.position, bullet.size, rl.GREEN)
			}

			// Draw aliens with animation
			for alien_number in 0 ..< ALIENS_NUM_X * ALIENS_NUM_Y {
				if game.alien_alive[alien_number] {
					alien_stat := game.alien_stats[alien_number]
					row := int(alien_number / ALIENS_NUM_X)

					frame_rect: rl.Rectangle
					if row == 0 {
						// Small alien (top row)
						frame_rect = sprites.small_frames[game.alien_current_frame]
					} else if row < 3 {
						// Medium alien (middle rows)
						frame_rect = sprites.medium_frames[game.alien_current_frame]
					} else {
						// Large alien (bottom rows)
						frame_rect = sprites.large_frames[game.alien_current_frame]
					}

					// Scale factor to match game dimensions
					scale := 0.5 * ALIEN_SIZE / frame_rect.height

					// Calculate the centered position
					draw_pos_x := alien_stat.x + (alien_stat.z - frame_rect.width * scale) * 0.5
					draw_pos_y := alien_stat.y

					// Draw the alien sprite at its position with scaling
					source_rec := frame_rect
					dest_rec := rl.Rectangle {
						x      = draw_pos_x,
						y      = draw_pos_y,
						width  = alien_stat.z,
						height = alien_stat.z,
					}

					rl.DrawTexturePro(sprites.texture, source_rec, dest_rec, {0, 0}, 0.0, rl.WHITE)
				}
			}

			for shield in game.shields {
				for row, x in shield.pixels {
					for pixel, y in row {
						if pixel {
							rl.DrawRectangleRec(
								{shield.position.x + f32(x), shield.position.y + f32(y), 1, 1},
								rl.PURPLE,
							)
						}
					}
				}
			}

			// Draw explosions
			for explosion in game.explosions {
				if explosion.active {
					// Use the appropriate explosion frame from the spritesheet
					frame_rect := sprites.explosion_frames[explosion.frame]

					// Draw the explosion at its position
					dest_rec := rl.Rectangle {
						x      = explosion.position.x,
						y      = explosion.position.y,
						width  = frame_rect.width,
						height = frame_rect.height,
					}

					rl.DrawTexturePro(sprites.texture, frame_rect, dest_rec, {0, 0}, 0.0, rl.WHITE)
				}
			}
		} else {
			game_over_text := fmt.ctprint("GAME OVER")
			game_over_font_size := i32(u8(time_elapsed / 0.01)) / 3

			game_over_text_width := rl.MeasureText(game_over_text, game_over_font_size)
			game_over_color := rl.Color {
				u8(time_elapsed * 5),
				u8(time_elapsed / 0.01),
				u8(time_elapsed),
				255,
			}

			rl.DrawText(
				game_over_text,
				SCREEN_GRID_SIZE / 2 - game_over_text_width / 2,
				SCREEN_GRID_SIZE / 2 - game_over_font_size / 2,
				game_over_font_size,
				game_over_color,
			)

			score_over_text := fmt.ctprintf("Score: %v", game.score)
			score_over_font_size: i32 = 20
			score_over_text_width := rl.MeasureText(score_over_text, score_over_font_size)
			rl.DrawText(
				score_over_text,
				SCREEN_GRID_SIZE / 2 - score_over_text_width / 2,
				SCREEN_GRID_SIZE / 3 - score_over_font_size / 2,
				score_over_font_size,
				game_over_color,
			)

			restart_over_text := fmt.ctprint("PRESS SPACE TO RESTART")
			restart_over_font_size: i32 = 10
			restart_over_text_width := rl.MeasureText(restart_over_text, restart_over_font_size)
			restart_over_color := rl.Color{255, 255, 255, u8(time_elapsed * 1000)}
			rl.DrawText(
				restart_over_text,
				SCREEN_GRID_SIZE / 2 - restart_over_text_width / 2,
				SCREEN_GRID_SIZE - score_over_font_size - 10,
				restart_over_font_size,
				restart_over_color,
			)
		}

		rl.ClearBackground(
			rl.Color(
				{
					u8((game.difficulty) * 13),
					u8((game.difficulty) * 8),
					u8((game.difficulty) * 21),
					1,
				},
			),
		)

		rl.BeginShaderMode(crt_shader)
		defer rl.EndShaderMode()

		rl.DrawTextureRec(
			target_texture.texture,
			rl.Rectangle {
				0,
				0,
				f32(target_texture.texture.width),
				f32(target_texture.texture.height),
			},
			{0, 0},
			rl.WHITE,
		)
	}
}
