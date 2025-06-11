package audio

import "core:math"


// attack decay envelope

ADEnv :: struct {
	sample_rate:    f32,
	value:          f32,
	attack:         f32,
	decay:          f32,
	attack_samples: f32,
	decay_samples:  f32,
	time_elapsed:   f32,
}

ADEnv_create :: proc(sample_rate: f32, attack: f32, decay: f32) -> ADEnv {
	return ADEnv {
		sample_rate = sample_rate,
		value = 0.0,
		attack = attack,
		decay = decay,
		attack_samples = attack * sample_rate,
		decay_samples = decay * sample_rate,
		time_elapsed = (attack + decay) * sample_rate,
	}
}

ADEnv_trigger :: proc(env: ^ADEnv) {
	if (env.value != 0) {
		env.time_elapsed = env.value * env.attack_samples
	} else {
		env.time_elapsed = 0.0
	}
}

ADEnv_nextValue :: proc(env: ^ADEnv, curve: f32 = 3) -> f32 {
	if (env.time_elapsed >= env.attack_samples + env.decay_samples) {
		env.value = 0
		return 0
	}
	if (env.time_elapsed < env.attack_samples) {
		if (env.attack_samples == 0) {
			env.value = 1
		} else {
			env.value = env.time_elapsed / env.attack_samples
		}
	} else if (env.time_elapsed < (env.attack_samples + env.decay_samples)) {
		if (env.decay == 0) {
			env.value = 0
		} else {
			env.value = 1 - ((env.time_elapsed - env.attack_samples) / env.decay_samples)
		}
	}

	env.time_elapsed += 1
	env.value = math.clamp(env.value, 0, 1)

	return math.pow_f32(env.value, curve)
}
