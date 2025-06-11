package audio

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
		lp = Filter_create(.Lowpass, 400),
		notes = {61.73541, 55, 48.99943, 46.24930},
		env = ADEnv_create(SAMPLE_RATE, 0, 0.113),
		sine_osc = Sine_Osc_create(61.73541),
		retrigger_time = 1,
	}
}

Bass_next_sample :: proc(b: ^Bass) -> f32 {
	env := ADEnv_nextValue(&b.env)
	if env == 0 do return 0
	distorted_sine := digital_clipper(Sine_Osc_next_linear(&b.sine_osc), 8)
	noise := White_noise_next()
	s := digital_clipper((0.9 * distorted_sine + 0.1 * noise) * env, 7)
	return Filter_next_value(&b.lp, s)
}

Bass_trigger_note :: proc(b: ^Bass) {
	ADEnv_trigger(&b.env)
	b.sine_osc.freq = b.notes[b.next_note]
	b.next_note = (b.next_note + 1) % 4
}
