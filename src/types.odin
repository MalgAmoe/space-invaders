package invaders

import rl "vendor:raylib"

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
	ufo:                   Ufo,

	// Shield variables
	shields:               [4]Shield,

	// Explosion variables
	explosions:            [dynamic]Explosion,

	// Game state variables
	state:            Game_State,
	ufo_time:              f32,
	accumulated_time:      f32,
	accumulated_time2:     f32,
	difficulty:            f32,
	score:                 f32,
	round_total_shots:     u8,
}

Game_State :: enum {
	Idle,
	Playing,
	Game_Over,
}

Ufo :: struct {
	position:        rl.Vector2,
	direction_right: bool,
	active:          bool,
}

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

AlienSprites :: struct {
	texture:          rl.Texture2D,
	small_frames:     [2]rl.Rectangle,
	medium_frames:    [2]rl.Rectangle,
	large_frames:     [2]rl.Rectangle,
	explosion_frames: [3]rl.Rectangle,
	player_ship:      rl.Rectangle,
	ufo:              rl.Rectangle,
}

// original table to calculate points of the ufo
// it had 50 as the 16th element but it was skipped, so it's not there here
ufo_points: [15]f32 = {100, 50, 50, 100, 150, 100, 100, 50, 300, 100, 100, 100, 50, 150, 100}
