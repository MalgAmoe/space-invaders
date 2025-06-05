package invaders

import "core:fmt"

import rl "vendor:raylib"

draw :: proc(game: ^Game, sprites: AlienSprites, time_elapsed: f64) {
	rl.ClearBackground(
		rl.Color(
			{u8((game.difficulty) * 13), u8((game.difficulty) * 8), u8((game.difficulty) * 21), 1},
		),
	)

	switch game.state {
	case .Idle:
		// see last score since game active
		score_text := fmt.ctprint(game.score)
		rl.DrawText(score_text, 5, 5, 10, rl.WHITE)

		start_text := fmt.ctprint("PRESS SPACE TO START")
		start_font_size: i32 = 10
		start_text_width := rl.MeasureText(start_text, start_font_size)
		start_color := rl.Color{255, 255, 255, u8(time_elapsed * 1000)}
		rl.DrawText(
			start_text,
			SCREEN_GRID_SIZE / 2 - start_text_width / 2,
			SCREEN_GRID_SIZE / 2 - start_font_size / 2,
			start_font_size,
			start_color,
		)

		// player
		rl.DrawTextureRec(
			sprites.texture,
			sprites.player_ship,
			{game.player_pos_x - 5, PLAYER_POS_Y - 5},
			rl.WHITE,
		)

		// shield
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

		// draw aliens
		for alien_number in 0 ..< ALIENS_NUM_X * ALIENS_NUM_Y {
			if game.alien_alive[alien_number] {
				alien_stat := game.alien_stats[alien_number]
				row := int(alien_number / ALIENS_NUM_X)

				movement := int(time_elapsed * 2) % 2

				frame_rect: rl.Rectangle
				if row == 0 {
					// Small alien (top row)
					frame_rect = sprites.small_frames[movement]
				} else if row < 3 {
					// Medium alien (middle rows)
					frame_rect = sprites.medium_frames[movement]
				} else {
					// Large alien (bottom rows)
					frame_rect = sprites.large_frames[movement]
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
	case .Playing:
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

		if (game.ufo.active) {
			dest_rec := rl.Rectangle {
				x      = game.ufo.position.x,
				y      = game.ufo.position.y,
				width  = UFO_SIZE,
				height = UFO_SIZE / 2,
			}
			rl.DrawTexturePro(sprites.texture, sprites.ufo, dest_rec, {0, 0}, 0.0, rl.WHITE)
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
	case .Game_Over:
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

		if game.ufo_time > 5 {
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
	}
}
