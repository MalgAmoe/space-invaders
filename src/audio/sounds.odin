package audio

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

Bass :: struct {
	sine_osc:       Sine_Osc,
	env:            ADEnv,
	lp:             Filter,
	notes:          [4]f32,
	next_note:      int,
	retrigger_time: f32,
}

Bass_create :: proc() -> Bass {
	return Bass {
		lp = Filter_create(.Lowpass, 900),
		notes = {61.73541, 55, 48.99943, 46.24930}, // C, B, A, G#
		env = ADEnv_create(SAMPLE_RATE, 0, 0.113),
		sine_osc = Sine_Osc_create(61.73541),
		retrigger_time = TRIGGER_TIME,
	}
}

// we take a sine wave, clip it(make it kinda square, add some harmonics)
// filter the high frequencies
// env is the gate for when the sounds start and how long it sounds
Bass_next_sample :: proc(b: ^Bass) -> f32 {
	env := ADEnv_nextValue(&b.env)
	if env == 0 do return 0
	distorted_sine := digital_clipper(Sine_Osc_next_linear(&b.sine_osc), 20)
	return Filter_next_value(&b.lp, distorted_sine * env)
}

Bass_trigger_note :: proc(b: ^Bass) {
	ADEnv_trigger(&b.env)
	b.sine_osc.freq = b.notes[b.next_note]
	b.next_note = (b.next_note + 1) % 4
}
