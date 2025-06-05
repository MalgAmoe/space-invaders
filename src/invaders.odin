package invaders

import rl "vendor:raylib"


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
UFO_SIZE :: 12
UFO_SPEED :: 1

SHIELD_Y_POS :: 250
SHIELD_HEIGHT :: 20
SHIELD_WIDTH :: 29
SHIELD_IMPACT_RADIUS :: 4

// Animation constants
ANIMATION_SPEED :: 0.5 // seconds per frame
EXPLOSION_FRAMES :: 3
EXPLOSION_DURATION :: 0.25 // seconds

// screen size not constant to handle resize
screen_size: i32 = 800

main :: proc() {
	// set falgs and init the window
	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE})
	rl.InitWindow(screen_size, screen_size, "Space Invaders")
	defer rl.CloseWindow()

	rl.SetTargetFPS(200)
	size := screen_size

	// Initialize the game state
	game := init_game()
	defer {
		delete(game.player_bullets) // Clean up dynamic arrays
		delete(game.alien_bullets)
		delete(game.explosions)
	}

	// Load sprites
	sprites := init_alien_sprites("sprites/alien-sprites.png")
	defer rl.UnloadTexture(sprites.texture)

	// Setup the shader and set variables to pass to the shader
	target_texture, crt_shader, i_time_loc := setup_shader()

	for !rl.WindowShouldClose() {
		if rl.IsWindowResized() {
			width := rl.GetScreenWidth()
			height := rl.GetScreenHeight()

			size = min(width, height)
			rl.SetWindowSize(size, size)
		}

		// calculate the variable to handle timing
		// dt value is kinda trial and error to mimic speed of aliens depending on number of aliens
		dt := f32(game.num_aliens_alive) / (game.difficulty * 500 + 4000)
		time_elapsed := rl.GetTime()
		frame_time := rl.GetFrameTime()

		// Pass variables to the shader
		rl.SetShaderValue(crt_shader, i_time_loc, &time_elapsed, .FLOAT)

		// update all the values of the game
		update(&game, dt, frame_time)

		// draw every changes in the game
		rl.BeginDrawing()
		defer rl.EndDrawing()
		camera := rl.Camera2D {
			zoom = f32(size) / SCREEN_GRID_SIZE,
		}
		rl.BeginMode2D(camera)
		defer rl.EndMode2D()
		draw(&game, sprites, time_elapsed)
		draw_shader(target_texture, crt_shader)
	}
}
