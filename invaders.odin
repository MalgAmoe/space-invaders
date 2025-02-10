package invaders

import "core:fmt"
import rl "vendor:raylib"

SCREEN_SIZE :: 800
SCREEN_GRID_SIZE :: 320
PLAYER_SIZE :: 10
PLAYER_POS_Y :: 280
PLAYER_SPEED :: 100

BULLET_SPEED :: 200
MAX_BULLET :: 20
BULLET_SIZE :: rl.Vector2{2, 4}

Bullet :: struct {
	position: rl.Vector2,
	active:   bool,
}

player_pos_x: f32
player_bullets: [MAX_BULLET]Bullet
player_bullet_index: int

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

		// check inputs
		player_move_velocity: f32
		if rl.IsKeyDown(.LEFT) {
			player_move_velocity -= PLAYER_SPEED
		}
		if rl.IsKeyDown(.RIGHT) {
			player_move_velocity += PLAYER_SPEED
		}

		if rl.IsKeyPressed(.SPACE) {
			player_bullet_index = (player_bullet_index + 1) % MAX_BULLET
			player_bullets[player_bullet_index] = {
				position = rl.Vector2 {
					player_pos_x + (PLAYER_SIZE - BULLET_SIZE.x) * 0.5,
					PLAYER_POS_Y - BULLET_SIZE.y,
				},
				active   = true,
			}
		}

		// update state

		for &bullet in player_bullets {
			bullet.position.y -= BULLET_SPEED * dt
			if bullet.position.y < -BULLET_SIZE.y {
				bullet.active = false
			}
		}

		player_pos_x += player_move_velocity * dt
		player_pos_x = clamp(player_pos_x, 0, SCREEN_GRID_SIZE - PLAYER_SIZE)
		player := rl.Rectangle{player_pos_x, PLAYER_POS_Y, PLAYER_SIZE, PLAYER_SIZE}

		// draw
		rl.DrawRectangleRec(player, rl.MAGENTA)

		for bullet in player_bullets {
			if bullet.active {
				rl.DrawRectangleV({bullet.position.x, bullet.position.y}, BULLET_SIZE, rl.YELLOW)
			}
		}

		rl.ClearBackground(rl.DARKPURPLE)
	}

}
