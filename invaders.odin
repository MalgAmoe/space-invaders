package invaders

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

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

Shield :: struct {
	position: rl.Vector2,
	pixels:   [SHIELD_WIDTH][SHIELD_HEIGHT]bool,
}

Game :: struct {
	// Player variables
	player_pos_x:       f32,
	player_bullets:     [dynamic]rl.Vector2,
	lifes_available:    int,

	// Alien variables
	alien_direction:    int,
	num_aliens_alive:   int,
	alien_alive:        [ALIENS_NUM_X * ALIENS_NUM_Y]bool,
	alien_stats:        [ALIENS_NUM_X * ALIENS_NUM_Y]rl.Vector4,
	last_alien_moved_x: int,
	last_alien_moved_y: int,
	alien_bullets:      [dynamic]rl.Vector2,

	// Shield variables
	shields:            [4]Shield,

	// Game state variables
	time:               f32,
	accumulated_time:   f32,
	accumulated_time2:  f32,
	game_over:          bool,
	difficulty:         f32,
	score:              f32,
}

// Function to create a shield (unchanged)
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

	return Shield{position = {x, y}, pixels = pixels}
}

// Updated functions to use the Game struct
place_aliens :: proc(game: ^Game, difficulty_to_use: f32) {
	start_y := (SCREEN_GRID_SIZE - ALIENS_BLOCK_HEIGHT) * 0.3 + difficulty_to_use * 10

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
}

alien_over_shield :: proc(game: ^Game, alien: rl.Vector4, offset: int) {
	if alien.y + alien.w > SHIELD_Y_POS {
		for &shield in game.shields {
			if rl.CheckCollisionRecs(
				{alien.x, alien.y, alien.w, alien.w},
				{
					shield.position.x,
					shield.position.y,
					shield.position.x + SHIELD_WIDTH,
					shield.position.y + SHIELD_HEIGHT,
				},
			) {
				for &column, column_index in shield.pixels {
					for &pixel, row_index in column {
						if pixel {
							if rl.CheckCollisionPointRec(
								{
									shield.position.x + f32(column_index),
									shield.position.y + f32(row_index),
								},
								{alien.x, alien.y - f32(offset), alien.z, alien.z + f32(offset)},
							) {
								pixel = false
							}
						}
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
			game.alien_stats[game.last_alien_moved_y].y + ALIEN_SIZE + ALIENS_SPACING

		alien := game.alien_stats[game.last_alien_moved_y]
		alien_over_shield(game, alien, ALIENS_SPACING)
	}
	game.last_alien_moved_y -= 1
}

delete_bullets :: proc(game: ^Game) {
	if len(game.alien_bullets) > 0 {
		remove_range(&game.alien_bullets, 0, len(game.alien_bullets))
	}
	if len(game.player_bullets) > 0 {
		unordered_remove(&game.player_bullets, 0)
	}
}

restart :: proc(game: ^Game, difficulty_to_use: f32) {
	delete_bullets(game)
	game.player_pos_x = f32(SCREEN_GRID_SIZE - PLAYER_SIZE) * 0.5
	game.alien_direction = 1
	place_aliens(game, difficulty_to_use)
	for &shield, i in game.shields {
		shield = create_shield(
			2 * f32(i + 1) * SCREEN_GRID_SIZE / 10 - SHIELD_WIDTH / 2,
			SHIELD_Y_POS,
		)
	}
}

init_game :: proc() -> Game {
	game: Game

	// Initialize dynamic arrays
	game.player_bullets = make([dynamic]rl.Vector2)
	game.alien_bullets = make([dynamic]rl.Vector2)

	// Set initial values
	game.player_pos_x = f32(SCREEN_GRID_SIZE - PLAYER_SIZE) * 0.5
	game.lifes_available = 3
	game.difficulty = 1
	game.alien_direction = 1

	// Initialize the game state
	restart(&game, game.difficulty)

	return game
}

damage_shield :: proc(shield: ^Shield, x, y: int) {
	shield.pixels[x][y] = false
	if x > 0 {
		shield.pixels[x - 1][y] = false
		if y < SHIELD_HEIGHT - 1 {
			shield.pixels[x - 1][y + 1] = false
		}
	}
	if x - 1 > 0 {
		shield.pixels[x - 2][y] = false
		if y < SHIELD_HEIGHT - 1 {
			shield.pixels[x - 2][y + 1] = false
		}
	}
	if x < SHIELD_WIDTH - 1 {
		shield.pixels[x + 1][y] = false
		if y < SHIELD_HEIGHT - 1 {
			shield.pixels[x + 1][y + 1] = false
		}
	}
	if x < SHIELD_WIDTH - 2 {
		shield.pixels[x + 2][y] = false
		if y < SHIELD_HEIGHT - 1 {
			shield.pixels[x + 2][y + 1] = false
		}
	}
	if y < SHIELD_HEIGHT - 1 do shield.pixels[x][y + 1] = false
	if y < SHIELD_HEIGHT - 2 do shield.pixels[x][y + 2] = false
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
	}

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

		rl.SetShaderValue(crt_shader, i_time_loc, &time_elapsed, .FLOAT)

		// update state
		if !game.game_over {
			game.accumulated_time += rl.GetFrameTime()

			player_move_velocity: f32
			if rl.IsKeyDown(.LEFT) {
				player_move_velocity -= PLAYER_SPEED
			}
			if rl.IsKeyDown(.RIGHT) {
				player_move_velocity += PLAYER_SPEED
			}

			if rl.IsKeyPressed(.SPACE) {
				if len(game.player_bullets) < 1 {
					append(
						&game.player_bullets,
						rl.Vector2 {
							game.player_pos_x + (PLAYER_SIZE - BULLET_SIZE.x) * 0.5,
							PLAYER_POS_Y - BULLET_SIZE.y,
						},
					)
				}
			}

			// update
			for game.accumulated_time >= dt {
				game.player_pos_x += player_move_velocity * dt
				game.player_pos_x = clamp(game.player_pos_x, 0, SCREEN_GRID_SIZE - PLAYER_SIZE)

				for &bullet, index in game.player_bullets {
					bullet.y -= BULLET_SPEED * dt
					if bullet.y < -BULLET_SIZE.y {
						unordered_remove(&game.player_bullets, index)
					}
				}

				for &bullet, index in game.alien_bullets {
					bullet.y += ALIEN_BULLET_SPEED * dt
					if bullet.y > SCREEN_GRID_SIZE {
						unordered_remove(&game.alien_bullets, index)
					}
				}

				move_alien_horizontally(&game)

				if game.last_alien_moved_y >= 0 {
					move_alien_vertically(&game)
				}

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
							append(
								&game.alien_bullets,
								rl.Vector2 {
									alien_to_fire.x + alien_to_fire.z / 2,
									alien_to_fire.y + alien_to_fire.z,
								},
							)
							random_time := rand.float32()
							game.accumulated_time2 = random_time + 0.2
						}
					}
				}

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

				bullets_loop: for bullet, bullet_index in game.player_bullets {
					bullet_rect := rl.Rectangle{bullet.x, bullet.y, BULLET_SIZE.x, BULLET_SIZE.y}
					for &shield in game.shields {
						for y in 0 ..< SHIELD_HEIGHT {
							had_collision: bool
							for x in 0 ..< SHIELD_WIDTH {
								if shield.pixels[x][y] {
									if rl.CheckCollisionPointRec(
										{shield.position.x + f32(x), shield.position.y + f32(y)},
										bullet_rect,
									) {
										damage_shield(&shield, x, y)
										had_collision = true
									}
								}
							}
							if had_collision {
								unordered_remove(&game.player_bullets, bullet_index)
								break bullets_loop
							}
						}
					}

					for alien, alien_index in game.alien_stats {
						alien_stats_rect := rl.Rectangle{alien.x, alien.y, alien.z, alien.z}

						if rl.CheckCollisionRecs(alien_stats_rect, bullet_rect) &&
						   game.alien_alive[alien_index] {
							game.alien_alive[alien_index] = false
							unordered_remove(&game.player_bullets, bullet_index)
							game.num_aliens_alive -= 1
							game.score += alien.w
							if game.num_aliens_alive == 0 {
								game.difficulty = f32(int(1 + game.difficulty) % 11)
								restart(&game, game.difficulty)
								break bullets_loop
							}
						}
					}
				}

				alien_bullet_loop: for bullet, index in game.alien_bullets {
					alien_bullet_rect := rl.Rectangle {
						bullet.x,
						bullet.y,
						BULLET_SIZE.x,
						BULLET_SIZE.y,
					}
					if len(game.player_bullets) == 1 {
						if rl.CheckCollisionRecs(
							{
								game.player_bullets[0].x,
								game.player_bullets[0].y,
								BULLET_SIZE.x,
								BULLET_SIZE.y,
							},
							alien_bullet_rect,
						) {
							unordered_remove(&game.alien_bullets, index)
							unordered_remove(&game.player_bullets, 0)
							break alien_bullet_loop
						}
					}
					for &shield in game.shields {
						for y in 0 ..< SHIELD_HEIGHT {
							had_collision: bool
							for x in 0 ..< SHIELD_WIDTH {
								if shield.pixels[x][y] {
									if rl.CheckCollisionPointRec(
										{shield.position.x + f32(x), shield.position.y + f32(y)},
										alien_bullet_rect,
									) {
										damage_shield(&shield, x, y)
										had_collision = true
									}
								}
							}
							if had_collision {
								unordered_remove(&game.alien_bullets, index)
								break alien_bullet_loop
							}
						}
					}
					if rl.CheckCollisionRecs(
						{game.player_pos_x, PLAYER_POS_Y, PLAYER_SIZE, PLAYER_SIZE},
						alien_bullet_rect,
					) {
						game.lifes_available -= 1
						unordered_remove(&game.alien_bullets, index)
					}
				}

				if game.lifes_available < 1 {
					game.game_over = true
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

			player := rl.Rectangle{game.player_pos_x, PLAYER_POS_Y, PLAYER_SIZE, PLAYER_SIZE}
			rl.DrawRectangleRec(player, rl.MAGENTA)

			for bullet in game.player_bullets {
				rl.DrawRectangleV({bullet.x, bullet.y}, BULLET_SIZE, rl.YELLOW)
			}

			for bullet in game.alien_bullets {
				rl.DrawRectangleV({bullet.x, bullet.y}, BULLET_SIZE, rl.GREEN)
			}

			for alien_number in 0 ..< ALIENS_NUM_X * ALIENS_NUM_Y {
				if game.alien_alive[alien_number] {
					position_rect := rl.Rectangle {
						game.alien_stats[alien_number].x,
						game.alien_stats[alien_number].y,
						game.alien_stats[alien_number].z,
						game.alien_stats[alien_number].z,
					}
					rl.DrawRectangleRec(position_rect, rl.PINK)
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

		rl.ClearBackground(rl.DARKPURPLE)

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
