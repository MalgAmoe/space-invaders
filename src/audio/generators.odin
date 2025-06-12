package audio

import "core:math"
import "core:math/rand"


// ----- SIMPLE SINE WAVE -----

// sine table to use in the many oscillators

SINE_WAVETABLE_SIZE: int : 128

create_sine_wavetable :: proc() -> [SINE_WAVETABLE_SIZE]f32 {
	wavetable: [SINE_WAVETABLE_SIZE]f32
	for i in 0 ..< SINE_WAVETABLE_SIZE {
		phase := (f32(i) / f32(SINE_WAVETABLE_SIZE)) * 2 * math.PI
		wavetable[i] = math.sin(phase)
	}
	return wavetable
}

sine_wave := create_sine_wavetable()


// sine OSC

Sine_Osc :: struct {
	freq:     f32,
	sine_idx: f32,
	wave:     ^[SINE_WAVETABLE_SIZE]f32,
}

Sine_Osc_create :: proc(freq: f32 = 100) -> Sine_Osc {
	return {freq = freq, sine_idx = 0, wave = &sine_wave}
}

Sine_Osc_next_raw :: proc(osc: ^Sine_Osc, mod: f32 = 1) -> f32 {
	index_float := osc.sine_idx * f32(SINE_WAVETABLE_SIZE)
	index := int(index_float) % SINE_WAVETABLE_SIZE
	sample := osc.wave[index]

	incr := mod * osc.freq / f32(SAMPLE_RATE)
	osc.sine_idx += incr
	if (osc.sine_idx > 1) {
		osc.sine_idx -= 1
	}

	return sample
}

Sine_Osc_next_linear :: proc(osc: ^Sine_Osc, mod: f32 = 1) -> f32 {
	if (osc.sine_idx > 1) {
		osc.sine_idx -= 1
	}
	index_float := osc.sine_idx * f32(SINE_WAVETABLE_SIZE)
	if index_float < 0 do index_float += f32(SINE_WAVETABLE_SIZE)
	index := int(index_float) % SINE_WAVETABLE_SIZE
	if index < 0 do index = SINE_WAVETABLE_SIZE + index
	next_index := (index + 1) % SINE_WAVETABLE_SIZE
	fractional := index_float - f32(int(index_float))
	sample := osc.wave[index] * (1 - fractional) + osc.wave[next_index] * fractional

	incr := mod * osc.freq / f32(SAMPLE_RATE)
	osc.sine_idx += incr

	return sample
}

// white noise

White_noise_next :: proc() -> f32 {
	return rand.float32_range(-1, 1)
}

// pink noise
// using ecopnomy version from https://www.musicdsp.org/en/latest/Filters/76-pink-noise-filter.html
Pink_Noise :: struct {
	b: [3]f32,
}

Pink_noise_next :: proc(p: ^Pink_Noise) -> f32 {
	white := rand.float32_range(-1, 1)

	p.b[0] = 0.99765 * p.b[0] + white * 0.0990460
	p.b[1] = 0.96300 * p.b[1] + white * 0.2965164
	p.b[2] = 0.57000 * p.b[2] + white * 1.0526913

	return p.b[0] + p.b[1] + p.b[2] + white * 0.1848
}

// low frequency oscillator
// used to make some parameters change in time(like frequency)

LFO_Type :: enum {
	Triangle,
	Sawtooth,
}

LFO :: struct {
	frequency: f32,
	phase:     f32,
	waveform:  LFO_Type,
}

Lfo_create :: proc(type: LFO_Type, freq: f32) -> LFO {
	return LFO{waveform = type, frequency = freq}
}

Lfo_next :: proc(lfo: ^LFO) -> f32 {
	output: f32

	switch lfo.waveform {
	case .Triangle:
		if lfo.phase < 0.5 {
			output = 2.0 * lfo.phase
		} else {
			output = 2.0 - 2.0 * lfo.phase
		}
	case .Sawtooth:
		output = 1.0 - lfo.phase
	}

	phase_inc := lfo.frequency / SAMPLE_RATE
	lfo.phase = math.mod_f32(lfo.phase + phase_inc, 1.0)

	return output
}
