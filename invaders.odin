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

player_pos_x: f32
player_bullets: [dynamic]rl.Vector2

time: f32
accumulated_time: f32
accumulated_time2: f32
game_over: bool
difficulty: f32
score: f32
lifes_available: int

alien_direction: int
num_aliens_alive: int
alien_alive: [ALIENS_NUM_X * ALIENS_NUM_Y]bool
alien_stats: [ALIENS_NUM_X * ALIENS_NUM_Y]rl.Vector4
last_alien_moved_x: int
last_alien_moved_y: int
alien_bullets: [dynamic]rl.Vector2

place_aliens :: proc(difficulty_to_use: f32) {
	start_y := (SCREEN_GRID_SIZE - ALIENS_BLOCK_HEIGHT) * 0.3 + difficulty_to_use * 10

	for alien in 0 ..< ALIENS_NUM_X * ALIENS_NUM_Y {
		alien_alive[alien] = true
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

		alien_stats[alien] = {x, y, width, points}
	}
	num_aliens_alive = ALIENS_NUM_X * ALIENS_NUM_Y
	last_alien_moved_x = num_aliens_alive - 1
	last_alien_moved_y = -1
}

move_alien_horizontally :: proc() {
	if alien_alive[last_alien_moved_x] {
		alien_stats[last_alien_moved_x].x =
			f32(alien_direction * 2) + alien_stats[last_alien_moved_x].x
	}
	last_alien_moved_x = last_alien_moved_x > 0 ? last_alien_moved_x - 1 : len(alien_stats) - 1
}

move_alien_vertically :: proc() {
	if alien_alive[last_alien_moved_y] {
		alien_stats[last_alien_moved_y].y =
			alien_stats[last_alien_moved_y].y + ALIEN_SIZE + ALIENS_SPACING
	}
	last_alien_moved_y -= 1
}

delete_bullets :: proc() {
	if len(alien_bullets) > 0 {
		remove_range(&alien_bullets, 0, len(alien_bullets))
	}
	if len(player_bullets) > 0 {
		unordered_remove(&player_bullets, 0)
	}
}

restart :: proc(difficulty_to_use: f32) {
	delete_bullets()
	player_pos_x = f32(SCREEN_GRID_SIZE - PLAYER_SIZE) * 0.5
	alien_direction = 1
	place_aliens(difficulty_to_use)
}

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(SCREEN_SIZE, SCREEN_SIZE, "Space Invaders")
	defer rl.CloseWindow()

	rl.SetTargetFPS(200)

	// setup starting state
	player_pos_x = f32(SCREEN_GRID_SIZE - PLAYER_SIZE) * 0.5

	difficulty = 1
	lifes_available = 3

	restart(difficulty)

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
		dt := f32(num_aliens_alive) / (difficulty * 500 + 4000)
		time_elapsed := rl.GetTime()

		rl.SetShaderValue(crt_shader, i_time_loc, &time_elapsed, .FLOAT)

		// update state
		if !game_over {
			accumulated_time += rl.GetFrameTime()

			player_move_velocity: f32
			if rl.IsKeyDown(.LEFT) {
				player_move_velocity -= PLAYER_SPEED
			}
			if rl.IsKeyDown(.RIGHT) {
				player_move_velocity += PLAYER_SPEED
			}

			if rl.IsKeyPressed(.SPACE) {
				if len(player_bullets) < 1 {
					append(
						&player_bullets,
						rl.Vector2 {
							player_pos_x + (PLAYER_SIZE - BULLET_SIZE.x) * 0.5,
							PLAYER_POS_Y - BULLET_SIZE.y,
						},
					)
				}
			}

			// update
			for accumulated_time >= dt {
				player_pos_x += player_move_velocity * dt
				player_pos_x = clamp(player_pos_x, 0, SCREEN_GRID_SIZE - PLAYER_SIZE)

				for &bullet, index in player_bullets {
					bullet.y -= BULLET_SPEED * dt
					if bullet.y < -BULLET_SIZE.y {
						unordered_remove(&player_bullets, index)
					}
				}

				for &bullet, index in alien_bullets {
					bullet.y += ALIEN_BULLET_SPEED * dt
					if bullet.y > SCREEN_GRID_SIZE {
						unordered_remove(&alien_bullets, index)
					}
				}


				move_alien_horizontally()

				if last_alien_moved_y >= 0 {
					move_alien_vertically()
				}

				if accumulated_time2 > 0 {
					accumulated_time2 -= dt
				} else {
					if len(alien_bullets) < 3 {
						random_alien_to_count := rand.int_max(num_aliens_alive + 1)
						alien_to_fire: rl.Vector4
						alien_index: int
						for is_alive, index in alien_alive {
							if is_alive do random_alien_to_count -= 1
							if random_alien_to_count == 0 {
								alien_index = index
								break
							}
						}

						is_alive := alien_alive[alien_index]
						if is_alive {
							alien_to_fire = alien_stats[alien_index]
							append(
								&alien_bullets,
								rl.Vector2 {
									alien_to_fire.x + alien_to_fire.z / 2,
									alien_to_fire.y + alien_to_fire.z,
								},
							)
							random_time := rand.float32()
							accumulated_time2 = random_time + 0.2
						}
					}
				}

				if last_alien_moved_x == len(alien_stats) - 1 {
					for alien, index in alien_stats {
						if alien_alive[index] {
							if alien.x < 10 || alien.x > SCREEN_GRID_SIZE - ALIEN_SIZE - 10 {
								alien_direction *= -1
								last_alien_moved_y = len(alien_stats) - 1
								break
							}
						}
						if alien.y > PLAYER_POS_Y {
							game_over = true
						}
					}
				}

				bullets_loop: for bullet, bullet_index in player_bullets {
					for alien, alien_index in alien_stats {
						alien_stats_rect := rl.Rectangle {
							alien_stats[alien_index].x,
							alien_stats[alien_index].y,
							alien_stats[alien_index].z,
							alien_stats[alien_index].z,
						}


						if rl.CheckCollisionRecs(
							   alien_stats_rect,
							   {bullet.x, bullet.y, BULLET_SIZE.x, BULLET_SIZE.y},
						   ) &&
						   alien_alive[alien_index] {
							alien_alive[alien_index] = false
							unordered_remove(&player_bullets, bullet_index)
							num_aliens_alive -= 1
							score += alien_stats[alien_index].w
							if num_aliens_alive == 0 {
								difficulty = f32(int(1 + difficulty) % 11)
								restart(difficulty)
								break bullets_loop
							}
						}
					}
				}

				for bullet, index in alien_bullets {
					if len(player_bullets) == 1 {
						if rl.CheckCollisionRecs(
							{
								player_bullets[0].x,
								player_bullets[0].y,
								BULLET_SIZE.x,
								BULLET_SIZE.y,
							},
							{bullet.x, bullet.y, BULLET_SIZE.x, BULLET_SIZE.y},
						) {
							unordered_remove(&alien_bullets, index)
							unordered_remove(&player_bullets, 0)
						}
					}
					if rl.CheckCollisionRecs(
						{player_pos_x, PLAYER_POS_Y, PLAYER_SIZE, PLAYER_SIZE},
						{bullet.x, bullet.y, BULLET_SIZE.x, BULLET_SIZE.y},
					) {
						lifes_available -= 1
						unordered_remove(&alien_bullets, index)
					}
				}

				if lifes_available < 1 {
					game_over = true
				}

				accumulated_time -= dt
			}

		} else {
			if rl.IsKeyPressed(.SPACE) {
				game_over = false
				difficulty = 1
				lifes_available = 3
				score = 0

				restart(difficulty)
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

		if !game_over {
			score_text := fmt.ctprint(score)
			rl.DrawText(score_text, 5, 5, 10, rl.WHITE)

			lifes_text := fmt.ctprintf("Lifes available: %v", lifes_available)
			lifes_text_size := rl.MeasureText(lifes_text, 10)
			rl.DrawText(lifes_text, SCREEN_GRID_SIZE - lifes_text_size - 5, 5, 10, rl.WHITE)

			player := rl.Rectangle{player_pos_x, PLAYER_POS_Y, PLAYER_SIZE, PLAYER_SIZE}
			rl.DrawRectangleRec(player, rl.MAGENTA)

			for bullet in player_bullets {
				rl.DrawRectangleV({bullet.x, bullet.y}, BULLET_SIZE, rl.YELLOW)
			}

			for bullet in alien_bullets {
				rl.DrawRectangleV({bullet.x, bullet.y}, BULLET_SIZE, rl.GREEN)
			}

			for alien_number in 0 ..< ALIENS_NUM_X * ALIENS_NUM_Y {
				if alien_alive[alien_number] {
					position_rect := rl.Rectangle {
						alien_stats[alien_number].x,
						alien_stats[alien_number].y,
						alien_stats[alien_number].z,
						alien_stats[alien_number].z,
					}
					rl.DrawRectangleRec(position_rect, rl.PINK)
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

			score_over_text := fmt.ctprintf("Score: %v", score)
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
