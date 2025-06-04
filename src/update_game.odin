package invaders

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"


update :: proc(game: ^Game, dt, frame_time: f32) {
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
		update_alien_animation(game, frame_time)

		// Update explosions
		update_explosions(game, frame_time)

		// spawn ufo every 25.6 seconds
		game.ufo_time += frame_time
		if game.ufo_time > 25.6 {
			spawn_ufo(&game.ufo)
			game.ufo_time = 0
		}

		update_ufo(&game.ufo)

		// update
		for game.accumulated_time >= dt {
			// Update player position
			game.player_pos_x += player_move_velocity * dt
			game.player_pos_x = clamp(game.player_pos_x, 5, SCREEN_GRID_SIZE - PLAYER_SIZE - 5)

			// Update all bullets with the new centralized function
			update_bullets(game, dt)

			// Move aliens
			move_alien_horizontally(game)

			if game.last_alien_moved_y >= 0 {
				move_alien_vertically(game)
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

			restart(game, game.difficulty)
		}
	}
}

// ------------------------------ ALIENS ------------------------------

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

// Update alien animation
update_alien_animation :: proc(game: ^Game, dt: f32) {
	game.alien_animation_timer += dt

	if game.alien_animation_timer >= ANIMATION_SPEED {
		game.alien_animation_timer = 0
		game.alien_current_frame = (game.alien_current_frame + 1) % 2
	}
}


// ------------------------------ UFO ------------------------------

spawn_ufo :: proc(ufo: ^Ufo) {
	// decide which position the ufo start randomly
	direction_right := rand.float32() > 0.5
	if (direction_right) {
		ufo.position = {-UFO_SIZE, 30}
		ufo.direction_right = true
	} else {
		ufo.position = {SCREEN_GRID_SIZE + UFO_SIZE, 30}
		ufo.direction_right = false
	}
	ufo.active = true
}

update_ufo :: proc(ufo: ^Ufo) {
	if (ufo.active) {
		if ufo.direction_right {
			ufo.position = {ufo.position.x + UFO_SPEED, ufo.position.y}
			if (ufo.position.x > f32(SCREEN_GRID_SIZE)) {
				ufo.active = false
			}
		} else {
			ufo.position = {ufo.position.x - UFO_SPEED, ufo.position.y}
			if (ufo.position.x < f32(0 - UFO_SIZE)) {
				ufo.active = false
			}
		}
	}
}


// ------------------------------ SHIELD ------------------------------

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


// ------------------------------ BULLETS ------------------------------

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
		had_alien_collision := false
		for alien_stat, alien_index in game.alien_stats {
			if !game.alien_alive[alien_index] {
				continue
			}

			if check_bullet_alien_collision(game.player_bullets[i], alien_stat) {
				game.alien_alive[alien_index] = false
				had_alien_collision = true

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
		if had_alien_collision do continue

		// check collision with bonus ufo
		bullet_rect := get_bullet_rect(game.player_bullets[i])
		ufo_rect := rl.Rectangle {
			x      = game.ufo.position.x,
			y      = game.ufo.position.y,
			width  = UFO_SIZE,
			height = UFO_SIZE / 2,
		}

		if rl.CheckCollisionRecs(bullet_rect, ufo_rect) {
			game.ufo.active = false
			unordered_remove(&game.player_bullets, i)

			game.score += ufo_points[game.round_total_shots]

			explosion := create_explosion(
				game.ufo.position.x - UFO_SIZE * 0.5,
				game.ufo.position.y - UFO_SIZE * 0.25,
			)
			append(&game.explosions, explosion)
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


// ------------------------------ COLLISIONS ------------------------------

// Helper to check collision between aliens and shields
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
		x      = player_x - 5,
		y      = PLAYER_POS_Y - 5,
		width  = 20,
		height = 10,
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
