package audio

import "core:math"
import rl "vendor:raylib"

g_frequency: f32 = 440.0 // A4 note
g_phase: f32 = 0.0
g_volume: f32 = 0.3
started := false
muted := true

stream: rl.AudioStream

// Audio callback - generates sine wave
audio_callback :: proc "c" (buffer_data: rawptr, frames: u32) {
    // Cast buffer to f32 slice (assuming 32-bit float, stereo)
	sample_count := int(frames * 2) // stereo = 2 channels
	buffer := ([^]f32)(buffer_data)[:sample_count]
	if !muted {
		sample_rate: f32 = 44100.0
		phase_increment := g_frequency * 2.0 * math.PI / sample_rate

		// Generate samples
		for i := 0; i < int(frames); i += 1 {
			// Generate sine wave sample
			sample := math.sin(g_phase) * g_volume

			// Write to both channels (stereo)
			buffer[i * 2] = sample // left
			buffer[i * 2 + 1] = sample // right

			// Advance phase
			g_phase += phase_increment
			if g_phase > 2.0 * math.PI {
				g_phase -= 2.0 * math.PI
			}
		}
	} else {
		for i := 0; i < int(frames); i += 1 {
			buffer[i * 2] = 0
			buffer[i * 2 + 1] = 0
		}
	}
}

init :: proc() {
	rl.InitAudioDevice()

	// Create audio stream with callback
	stream = rl.LoadAudioStream(44100, 32, 2) // 44.1kHz, 32-bit float, stereo
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
