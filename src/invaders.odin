package invaders

import "core:c"
import rl "vendor:raylib"

import "audio"

// CONSTANTS
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

// GLOBALS
run: bool
screen_size: i32 = 800
game: Game
sprites: AlienSprites

init :: proc() {
	run = true

	// set falgs and init the window
	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE})
	rl.InitWindow(screen_size, screen_size, "Space Invaders")

	rl.SetTargetFPS(200)

	// Initialize the game state
	game = init_game()

	// Load sprites
	sprites = init_alien_sprites("assets/alien-sprites.png")
}


update :: proc() {
	// calculate the variable to handle timing
	// dt value is kinda trial and error to mimic speed of aliens depending on number of aliens
	dt := f32(game.num_aliens_alive) / (game.difficulty * 500 + 4000)
	time_elapsed := rl.GetTime()
	frame_time := rl.GetFrameTime()

	// update all the values of the game
	update_game(&game, dt, frame_time)

	// draw every changes in the game
	rl.BeginDrawing()
	defer rl.EndDrawing()
	camera := rl.Camera2D {
		zoom = f32(screen_size) / SCREEN_GRID_SIZE,
	}
	rl.BeginMode2D(camera)
	defer rl.EndMode2D()
	draw(&game, sprites, time_elapsed)

	free_all(context.temp_allocator)
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable game.
parent_window_size_changed :: proc(w, h: int) {
	screen_size = i32(min(w, h))
	rl.SetWindowSize(c.int(screen_size), c.int(screen_size))
}

shutdown :: proc() {
	rl.UnloadTexture(sprites.texture)
	delete(game.player_bullets)
	delete(game.alien_bullets)
	delete(game.explosions)
	audio.close()
	rl.CloseWindow()
}

should_run :: proc() -> bool {
	when ODIN_OS != .JS {
		// Never run this proc in browser. It contains a 16 ms sleep on web!
		if rl.WindowShouldClose() {
			run = false
		}
	}

	return run
}
