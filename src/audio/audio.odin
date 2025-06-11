package audio

import "base:runtime"

import rl "vendor:raylib"

// samplerate could be read from audioContext
// for simplicicty we use miniaudio auto conversion
SAMPLE_RATE :: 44100

counter: f32 = 1
started := false
muted := true

stream: rl.AudioStream

bass := Bass_create()

audio_callback :: proc "c" (buffer_data: rawptr, frames: u32) {
	context = runtime.default_context()
	// Cast buffer to f32 slice (assuming 32-bit float, stereo)
	sample_count := int(frames * 2) // stereo = 2 channels
	buffer := ([^]f32)(buffer_data)[:sample_count]

	if !muted {
		for i := 0; i < int(frames); i += 1 {
			counter += 0.00003
			if counter >= 1 {
				counter = 0
				Bass_trigger_note(&bass)
			}
			sample: f32 = 0.2 * Bass_next_sample(&bass)

			// Write to both channels (stereo)
			buffer[i * 2] = sample
			buffer[i * 2 + 1] = sample
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
