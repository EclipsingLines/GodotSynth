#include "synth_offline_mixer.h"
#include "audio_stream_generator_engine.h"
#include "engine_factory.h"
#include "synth_configuration.h"
#include "synth_voice.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <algorithm>

namespace godot {

void SynthOfflineMixer::_bind_methods() {
	ClassDB::bind_method(D_METHOD("init", "sample_rate"), &SynthOfflineMixer::init);
	ClassDB::bind_method(D_METHOD("add_track", "config", "polyphony"), &SynthOfflineMixer::add_track, DEFVAL(16));
	ClassDB::bind_method(D_METHOD("schedule_note", "track", "note", "velocity", "on_frame", "off_frame", "controls"), &SynthOfflineMixer::schedule_note, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("schedule_parameter", "track", "name", "value", "frame"), &SynthOfflineMixer::schedule_parameter);
	ClassDB::bind_method(D_METHOD("render", "frames"), &SynthOfflineMixer::render);
	ClassDB::bind_method(D_METHOD("get_mixed_frames"), &SynthOfflineMixer::get_mixed_frames);
	ClassDB::bind_method(D_METHOD("get_track_count"), &SynthOfflineMixer::get_track_count);
	ClassDB::bind_method(D_METHOD("get_late_event_count"), &SynthOfflineMixer::get_late_event_count);
}

bool SynthOfflineMixer::init(int p_sample_rate) {
	ERR_FAIL_COND_V_MSG(p_sample_rate < 8000 || p_sample_rate > 192000, false, "SynthOfflineMixer: sample_rate must be between 8000 and 192000.");

	tracks.clear();
	mixed_frames = 0;
	next_voice_id = 1;
	sample_rate = p_sample_rate;
	return true;
}

int SynthOfflineMixer::add_track(const Ref<SynthConfiguration> &p_config, int p_polyphony) {
	ERR_FAIL_COND_V_MSG(sample_rate <= 0, -1, "SynthOfflineMixer: init() must be called before add_track().");
	ERR_FAIL_COND_V_MSG(p_config.is_null(), -1, "SynthOfflineMixer: config is null.");
	ERR_FAIL_COND_V_MSG(mixed_frames != 0, -1, "SynthOfflineMixer: tracks cannot be added after rendering has started.");

	const int polyphony = Math::clamp(p_polyphony, 1, 32);

	Track track;
	track.config = p_config;
	track.playback.instantiate();
	track.playback->set_sample_rate((float)sample_rate);

	for (int i = 0; i < polyphony; i++) {
		Ref<AudioStreamGeneratorEngine> engine = EngineFactory::create_engine_from_config(p_config);
		if (engine.is_null()) {
			ERR_FAIL_V_MSG(-1, "SynthOfflineMixer: the configuration produced no engine.");
		}
		engine->set_sample_rate((float)sample_rate);

		Ref<SynthVoice> voice;
		voice.instantiate();
		voice->set_engine(engine);
		track.voices.push_back(voice);
		track.busy_until.push_back(0);
	}

	track.playback->set_master_effect_chain(p_config->get_master_effect_chain());
	tracks.push_back(track);
	return (int)tracks.size() - 1;
}

bool SynthOfflineMixer::schedule_note(int p_track, float p_note, float p_velocity, int64_t p_on_frame, int64_t p_off_frame, const Dictionary &p_controls) {
	ERR_FAIL_INDEX_V_MSG(p_track, (int)tracks.size(), false, "SynthOfflineMixer: invalid track index.");
	ERR_FAIL_COND_V_MSG(p_on_frame < 0, false, "SynthOfflineMixer: on_frame must be >= 0.");
	ERR_FAIL_COND_V_MSG(p_off_frame >= 0 && p_off_frame < p_on_frame, false, "SynthOfflineMixer: off_frame is before on_frame.");

	Track &track = tracks[p_track];

	// Release allowance: a voice is only free once its last note has had time to release.
	const int64_t guard = sample_rate / 2;
	int voice_index = -1;
	for (int i = 0; i < (int)track.voices.size(); i++) {
		if (track.busy_until[i] <= p_on_frame - guard) {
			voice_index = i;
			break;
		}
	}
	if (voice_index < 0) {
		// All voices are busy: steal the one free earliest (lowest index on ties).
		voice_index = 0;
		for (int i = 1; i < (int)track.voices.size(); i++) {
			if (track.busy_until[i] < track.busy_until[voice_index]) {
				voice_index = i;
			}
		}
	}
	track.busy_until[voice_index] = p_off_frame >= 0 ? p_off_frame : INT64_MAX;

	const Ref<SynthVoice> &voice = track.voices[voice_index];
	Ref<SynthNoteContext> context;
	context.instantiate();
	context->set_voice_id(next_voice_id++);

	SynthNoteEvent event;
	event.type = SynthNoteEvent::START_VOICE;
	event.frame = p_on_frame;
	event.voice = voice;
	event.context = context;
	track.queue.push_back(event);

	Array keys = p_controls.keys();
	for (int i = 0; i < keys.size(); i++) {
		const Variant key = keys[i];
		if (key.get_type() != Variant::STRING && key.get_type() != Variant::STRING_NAME) {
			UtilityFunctions::push_warning("SynthOfflineMixer: control names must be strings.");
			continue;
		}
		const Variant value = p_controls[key];
		const Variant::Type type = value.get_type();
		if (type != Variant::INT && type != Variant::FLOAT) {
			UtilityFunctions::push_warning("SynthOfflineMixer: control values must be int or float.");
			continue;
		}

		const String name = key;
		Ref<ModulatedParameter> parameter = voice->get_engine()->get_parameter(name);
		if (parameter.is_null()) {
			UtilityFunctions::push_warning("SynthOfflineMixer: unknown control '" + name + "'");
			continue;
		}

		SynthNoteEvent parameter_event;
		parameter_event.type = SynthNoteEvent::SET_PARAMETER;
		parameter_event.frame = p_on_frame;
		parameter_event.parameter = parameter;
		parameter_event.value = (float)value;
		track.queue.push_back(parameter_event);
	}

	SynthNoteEvent note_on;
	note_on.type = SynthNoteEvent::NOTE_ON;
	note_on.frame = p_on_frame;
	note_on.context = context;
	note_on.note = p_note;
	note_on.velocity = p_velocity;
	track.queue.push_back(note_on);

	if (p_off_frame >= 0) {
		SynthNoteEvent note_off;
		note_off.type = SynthNoteEvent::NOTE_OFF;
		note_off.frame = p_off_frame;
		note_off.context = context;
		track.queue.push_back(note_off);
	}

	return true;
}

bool SynthOfflineMixer::schedule_parameter(int p_track, const String &p_name, float p_value, int64_t p_frame) {
	ERR_FAIL_INDEX_V_MSG(p_track, (int)tracks.size(), false, "SynthOfflineMixer: invalid track index.");
	ERR_FAIL_COND_V_MSG(p_frame < 0, false, "SynthOfflineMixer: frame must be >= 0.");

	Track &track = tracks[p_track];
	bool found = false;
	for (int i = 0; i < (int)track.voices.size(); i++) {
		const Ref<SynthVoice> &voice = track.voices[i];
		if (voice.is_null() || voice->get_engine().is_null()) {
			continue;
		}

		Ref<ModulatedParameter> parameter = voice->get_engine()->get_parameter(p_name);
		if (parameter.is_null()) {
			continue;
		}

		SynthNoteEvent event;
		event.type = SynthNoteEvent::SET_PARAMETER;
		event.frame = p_frame;
		event.parameter = parameter;
		event.value = p_value;
		track.queue.push_back(event);
		found = true;
	}

	if (!found) {
		UtilityFunctions::push_warning("SynthOfflineMixer: unknown parameter '" + p_name + "'");
	}
	return found;
}

void SynthOfflineMixer::push_due_events(Track &r_track, int64_t p_until_frame) {
	while (r_track.queue_head < r_track.queue.size() && r_track.queue[r_track.queue_head].frame < p_until_frame) {
		if (!r_track.playback->push_event(r_track.queue[r_track.queue_head])) {
			break;
		}
		r_track.queue_head++;
	}
}

PackedVector2Array SynthOfflineMixer::render(int p_frames) {
	PackedVector2Array output;
	ERR_FAIL_COND_V_MSG(sample_rate <= 0, output, "SynthOfflineMixer: init() must be called before render().");
	ERR_FAIL_COND_V_MSG(p_frames < 0 || p_frames > (1 << 26), output, "SynthOfflineMixer: invalid frame count.");
	ERR_FAIL_COND_V_MSG(tracks.empty(), output, "SynthOfflineMixer: no tracks to render.");
	if (p_frames == 0) {
		return output;
	}

	for (Track &track : tracks) {
		if (track.queue_head > 0) {
			track.queue.erase(track.queue.begin(), track.queue.begin() + track.queue_head);
			track.queue_head = 0;
		}
		// Stable, so events at the same frame keep their push order
		// (START_VOICE before NOTE_ON before NOTE_OFF).
		std::stable_sort(track.queue.begin(), track.queue.end(), [](const SynthNoteEvent &a, const SynthNoteEvent &b) {
			return a.frame < b.frame;
		});
	}

	output.resize(p_frames);
	Vector2 *dst = output.ptrw();
	for (int i = 0; i < p_frames; i++) {
		dst[i] = Vector2();
	}

	int done = 0;
	while (done < p_frames) {
		const int64_t position = mixed_frames + done;
		const int slice = MIN(SynthAudioStreamPlayback::MIX_CHUNK - (int)(position % SynthAudioStreamPlayback::MIX_CHUNK), p_frames - done);
		const int64_t slice_end = position + slice;

		for (Track &track : tracks) {
			push_due_events(track, slice_end);
			PackedVector2Array part = track.playback->render_offline(slice);
			const int count = MIN(slice, (int)part.size());
			for (int i = 0; i < count; i++) {
				dst[done + i] += part[i];
			}
		}
		done += slice;
	}

	mixed_frames += p_frames;
	return output;
}

int64_t SynthOfflineMixer::get_mixed_frames() const {
	return mixed_frames;
}

int SynthOfflineMixer::get_track_count() const {
	return (int)tracks.size();
}

int64_t SynthOfflineMixer::get_late_event_count() const {
	int64_t late = 0;
	for (const Track &track : tracks) {
		if (track.playback.is_valid()) {
			late += track.playback->get_late_event_count();
		}
	}
	return late;
}

} // namespace godot
