package invaders

import "core:fmt"
import rl "vendor:raylib"

SCREEN_SIZE :: 800
SCREEN_GRID_SIZE :: 320
PLAYER_SIZE :: 10
PLAYER_POS_Y :: 280
PLAYER_SPEED :: 200

player_pos_x: f32

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(SCREEN_SIZE, SCREEN_SIZE, "Space Invaders")
	defer rl.CloseWindow()

	rl.SetTargetFPS(200)

	// setup starting state
	player_pos_x = f32(SCREEN_GRID_SIZE - PLAYER_SIZE) * 0.5

	for !rl.WindowShouldClose() {
		// setup basic
		rl.BeginDrawing()
		defer rl.EndDrawing()

		camera := rl.Camera2D {
			zoom = f32(SCREEN_SIZE) / SCREEN_GRID_SIZE,
		}
		rl.BeginMode2D(camera)
		defer rl.EndMode2D()

		// setup vars
		dt := rl.GetFrameTime()

		// update
		player_move_velocity: f32
		if rl.IsKeyDown(.LEFT) {
			player_move_velocity -= PLAYER_SPEED
		}
		if rl.IsKeyDown(.RIGHT) {
			player_move_velocity += PLAYER_SPEED
		}

		player_pos_x += player_move_velocity * dt
		player_pos_x = clamp(player_pos_x, 0, SCREEN_GRID_SIZE - PLAYER_SIZE)
		player := rl.Rectangle{player_pos_x, PLAYER_POS_Y, PLAYER_SIZE, PLAYER_SIZE}

		// draw
		rl.DrawRectangleRec(player, rl.MAGENTA)

		rl.ClearBackground(rl.DARKPURPLE)
	}

}
