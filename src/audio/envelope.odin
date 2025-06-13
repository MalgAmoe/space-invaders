package audio

import "core:math"


// attack hold decay envelope

AHDEnv :: struct {
	sample_rate:    f32,
	value:          f32,
	attack:         f32,
	hold:           f32,
	decay:          f32,
	attack_samples: f32,
	hold_samples:   f32,
	decay_samples:  f32,
	time_elapsed:   f32,
}

AHDEnv_create :: proc(sample_rate: f32, attack: f32, decay: f32, hold: f32 = 0) -> AHDEnv {
	return AHDEnv {
		sample_rate = sample_rate,
		value = 0.0,
		attack = attack,
		hold = hold,
		decay = decay,
		attack_samples = attack * sample_rate,
		hold_samples = hold * sample_rate,
		decay_samples = decay * sample_rate,
		time_elapsed = (attack + decay) * sample_rate,
	}
}

AHDEnv_trigger :: proc(env: ^AHDEnv) {
	if (env.value != 0) {
		env.time_elapsed = env.value * env.attack_samples
	} else {
		env.time_elapsed = 0.0
	}
}

AHDEnv_nextValue :: proc(env: ^AHDEnv, curve: f32 = 3) -> f32 {
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
	} else if (env.time_elapsed < (env.attack_samples + env.hold_samples)) {
		env.value = 1
	} else if (env.time_elapsed < (env.attack_samples + env.hold_samples + env.decay_samples)) {
		if (env.decay == 0) {
			env.value = 0
		} else {
			decay_start_time := env.attack_samples + env.hold_samples
			env.value = 1 - ((env.time_elapsed - decay_start_time) / env.decay_samples)
		}
	}

	env.time_elapsed += 1
	env.value = math.clamp(env.value, 0, 1)

	return math.pow_f32(env.value, curve)
}
