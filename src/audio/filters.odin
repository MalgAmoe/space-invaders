package audio

import "core:math"

Fiter_Type :: enum {
	Lowpass,
	Highpass,
}

Filter :: struct {
	type:       Fiter_Type,
	a0, a1, a2: f32,
	b1, b2:     f32,
	x, y:       [2]f32,
}

Filter_next_value :: proc(lp: ^Filter, input: f32) -> f32 {
	output := lp.a0 * input + lp.a1 * lp.x[0] + lp.a2 * lp.x[1] - lp.b1 * lp.y[0] - lp.b2 * lp.y[1]
	lp.x[1] = lp.x[0]
	lp.x[0] = input
	lp.y[1] = lp.y[0]
	lp.y[0] = output

	return output
}

Filter_create :: proc(filter_type: Fiter_Type, cutoff_freq: f32, Q: f32 = 0.707) -> Filter {
    filter := Filter{ type = filter_type}

    switch filter_type {
        case .Lowpass:
            Lowpass_update(&filter, cutoff_freq, Q)
        case .Highpass:
            Highpass_update(&filter, cutoff_freq, Q)
    }

	return filter
}

Lowpass_update :: proc(lp: ^Filter, cutoff_freq: f32, Q: f32 = 0.707) {
	w0 := 2 * math.PI * cutoff_freq / f32(SAMPLE_RATE)
	cosW0 := math.cos(w0)
	sinW0 := math.sin(w0)
	alpha := sinW0 / (2 * Q)

	b0 := 1 + alpha
	lp.a0 = ((1 - cosW0) / 2) / b0
	lp.a1 = (1 - cosW0) / b0
	lp.a2 = lp.a0
	lp.b1 = (-2 * cosW0) / b0
	lp.b2 = (1 - alpha) / b0
}

Highpass_update :: proc(lp: ^Filter, cutoff_freq: f32, Q: f32 = 0.707) {
	w0 := 2 * math.PI * cutoff_freq / f32(SAMPLE_RATE)
	cosW0 := math.cos(w0)
	sinW0 := math.sin(w0)
	alpha := sinW0 / (2 * Q)

	b0 := 1 + alpha
	lp.a0 = ((1 + cosW0) / 2) / b0
	lp.a1 = -(1 + cosW0) / b0
	lp.a2 = lp.a0
	lp.b1 = (-2 * cosW0) / b0
	lp.b2 = (1 - alpha) / b0
}
