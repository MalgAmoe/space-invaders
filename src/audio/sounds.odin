package audio

import "core:fmt"
import "core:math"


// kinda timing of the bass loop
TRIGGER_OFFSET :: 3720
TRIGGER_TIME :: 630 * 55 + TRIGGER_OFFSET

triggers :: enum {
	Shot,
	Alien_Explosion,
	Ufo_Passing,
	Ufo_Explosion,
	Player_Killed,
}

// bass for the hypnotic loop
Bass :: struct {
	sine_osc:       Sine_Osc,
	env:            AHDEnv,
	lp:             Filter,
	notes:          [4]f32,
	next_note:      int,
	retrigger_time: f32,
}

Bass_create :: proc() -> Bass {
	return Bass {
		lp             = Filter_create(.Lowpass, 900),
		notes          = {61.73541, 55, 48.99943, 46.24930}, // C, B, A, G#
		env            = AHDEnv_create(SAMPLE_RATE, 0, 0.113),
		sine_osc       = Sine_Osc_create(61.73541),
		retrigger_time = TRIGGER_TIME,
	}
}

// we take a sine wave, clip it(make it kinda square, add some harmonics)
// filter the high frequencies
// env is the gate for when the sounds start and how long it sounds
Bass_next :: proc(b: ^Bass) -> f32 {
	env := AHDEnv_nextValue(&b.env)
	if env == 0 do return 0
	distorted_sine := digital_clipper(Sine_Osc_next_linear(&b.sine_osc), 20)
	return Filter_next_value(&b.lp, distorted_sine * env)
}

Bass_trigger_note :: proc(b: ^Bass) {
	AHDEnv_trigger(&b.env)
	b.sine_osc.freq = b.notes[b.next_note]
	b.next_note = (b.next_note + 1) % 4
}


// alien exploding

Alien_Explosion :: struct {
	sine: Sine_Osc,
	env:  AHDEnv,
	lfo:  LFO,
}

Alien_Explosion_create :: proc() -> Alien_Explosion {
	return Alien_Explosion {
		sine = Sine_Osc_create(100),
		env = AHDEnv_create(SAMPLE_RATE, 0, 0.45),
		lfo = Lfo_create(.Sawtooth, 10),
	}
}

// we use a clipped sine wave, and modulate the frequency
Alien_Explosion_next :: proc(explosion: ^Alien_Explosion) -> f32 {
	env := AHDEnv_nextValue(&explosion.env)
	if env == 0 do return 0

	lfo := Lfo_next(&explosion.lfo) * 20
	sine := digital_clipper(Sine_Osc_next_linear(&explosion.sine, lfo), 14)

	return env * sine
}

Alien_explosion_trigger :: proc(explosion: ^Alien_Explosion) {
	AHDEnv_trigger(&explosion.env)
	explosion.lfo.phase = 0
}


// UFO appearing

UFO_Present :: struct {
	sine: Sine_Osc,
	lfo:  Sine_Osc,
	lp:   Filter,
}

UFO_Present_create :: proc() -> UFO_Present {
	return UFO_Present {
		sine = Sine_Osc_create(4500),
		lfo = Sine_Osc_create(3.5),
		lp = Filter_create(.Lowpass, 8000),
	}
}

// we use a sine wave to modify the pitch of an oscillator,
// distortion and abs value of the lfo is to make this modulation
// the shape of boobs drawn by an 8 years old.
// then wave fold gives us a nastier sound with more harmonics
UFO_Present_next :: proc(ufo: ^UFO_Present) -> f32 {
	lfo := 1 + distortion(-1.15 * math.abs(Sine_Osc_next_linear(&ufo.lfo)))
	sine := Sine_Osc_next_linear(&ufo.sine, lfo)
	return distortion(Filter_next_value(&ufo.lp, wave_fold(sine)))
}
