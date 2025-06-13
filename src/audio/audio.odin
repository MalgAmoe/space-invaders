package audio

import "base:runtime"

import rl "vendor:raylib"

// samplerate could be read from audioContext
// for simplicicty we use miniaudio auto conversion
SAMPLE_RATE :: 44100

started := false
muted := true

stream: rl.AudioStream

counter: f32 = TRIGGER_TIME
bass := Bass_create()

alien_explosion_triggered := false
alien_explosion := Alien_Explosion_create()

ufo_is_present := false
ufo_present := UFO_Present_create()

ufo_killed_triggered := false
ufo_killed := UFO_Killed_create()

player_killed_triggered := false
player_killed := Player_Killed_create()

player_shot_triggered := false
player_shot := Player_Shot_create()


audio_callback :: proc "c" (buffer_data: rawptr, frames: u32) {
	context = runtime.default_context()
	// Cast buffer to f32 slice (assuming 32-bit float, stereo)
	sample_count := int(frames * 2) // stereo = 2 channels
	buffer := ([^]f32)(buffer_data)[:sample_count]

	// if !muted {
		for i := 0; i < int(frames); i += 1 {
			counter += 1
			if counter >= bass.retrigger_time {
				counter = 0
				Bass_trigger_note(&bass)
			}
			if alien_explosion_triggered {
				alien_explosion_triggered = false
				Alien_explosion_trigger(&alien_explosion)
				Player_Shot_stop(&player_shot)
			}
			ufo_present_sample := ufo_is_present ? UFO_Present_next(&ufo_present) : 0

			if ufo_killed_triggered {
				ufo_killed_triggered = false
				UFO_Killed_trigger(&ufo_killed)
				Player_Shot_stop(&player_shot)
			}
			if player_killed_triggered {
				player_killed_triggered = false
				Player_Killed_trigger(&player_killed)
			}
			if player_shot_triggered {
				player_shot_triggered = false
				Player_Shot_trigger(&player_shot)
			}


			if !muted {
				sample: f32 = distortion(
					0.35 * Bass_next(&bass) +
					0.2 * Alien_Explosion_next(&alien_explosion) +
					0.25 * ufo_present_sample +
					0.25 * UFO_Killed_next(&ufo_killed) +
					0.3 * Player_Killed_next(&player_killed) +
					0.08 * Player_Shot_next(&player_shot),
					0.6,
				)
	
				// Write to both channels (stereo)
				buffer[i * 2] = sample
				buffer[i * 2 + 1] = sample
			} else {

				// for i := 0; i < int(frames); i += 1 {
					sample: f32 = distortion(0.3 * Player_Killed_next(&player_killed))
					buffer[i * 2] = sample
					buffer[i * 2 + 1] = sample
				// }
			}
		}
// 	} else {
// 	}
}

init :: proc() {
	rl.InitAudioDevice()

	// Create audio stream with callback
	stream = rl.LoadAudioStream(SAMPLE_RATE, 32, 2) // 44.1kHz, 32-bit float, stereo
	rl.SetAudioStreamCallback(stream, audio_callback)
}

start :: proc() {
	started = true
	rl.PlayAudioStream(stream)
}

stop_audio :: proc() {
	started = false
	rl.StopAudioStream(stream)
}

close :: proc() {
	rl.CloseAudioDevice()
}
