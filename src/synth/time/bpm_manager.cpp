// bpm_manager.cpp
#include "bpm_manager.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

// BPMEvent implementation
void BPMEvent::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_subdivision", "subdivision"), &BPMEvent::set_subdivision);
	ClassDB::bind_method(D_METHOD("get_subdivision"), &BPMEvent::get_subdivision);
	ClassDB::bind_method(D_METHOD("set_event_time", "time"), &BPMEvent::set_event_time);
	ClassDB::bind_method(D_METHOD("get_event_time"), &BPMEvent::get_event_time);
	ClassDB::bind_method(D_METHOD("set_delta_time", "delta"), &BPMEvent::set_delta_time);
	ClassDB::bind_method(D_METHOD("get_delta_time"), &BPMEvent::get_delta_time);
	ClassDB::bind_method(D_METHOD("set_beat_count", "count"), &BPMEvent::set_beat_count);
	ClassDB::bind_method(D_METHOD("get_beat_count"), &BPMEvent::get_beat_count);

	ADD_PROPERTY(PropertyInfo(Variant::INT, "subdivision"), "set_subdivision", "get_subdivision");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "event_time"), "set_event_time", "get_event_time");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "delta_time"), "set_delta_time", "get_delta_time");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "beat_count"), "set_beat_count", "get_beat_count");

	BIND_ENUM_CONSTANT(WHOLE);
	BIND_ENUM_CONSTANT(HALF);
	BIND_ENUM_CONSTANT(QUARTER);
	BIND_ENUM_CONSTANT(EIGHTH);
	BIND_ENUM_CONSTANT(SIXTEENTH);
	BIND_ENUM_CONSTANT(SIXTYFOURTH);
	BIND_ENUM_CONSTANT(WHOLE_TRIPLET);
	BIND_ENUM_CONSTANT(HALF_TRIPLET);
	BIND_ENUM_CONSTANT(QUARTER_TRIPLET);
	BIND_ENUM_CONSTANT(EIGHTH_TRIPLET);
	BIND_ENUM_CONSTANT(SIXTEENTH_TRIPLET);
	BIND_ENUM_CONSTANT(SUBDIVISION_MAX);
}

BPMEvent::BPMEvent() :
		subdivision(QUARTER), event_time(0), delta_time(0), beat_count(0) {}

// Setters/getters
void BPMEvent::set_subdivision(Subdivision p_subdivision) { subdivision = p_subdivision; }
BPMEvent::Subdivision BPMEvent::get_subdivision() const { return subdivision; }
void BPMEvent::set_event_time(double p_time) { event_time = p_time; }
double BPMEvent::get_event_time() const { return event_time; }
void BPMEvent::set_delta_time(double p_delta) { delta_time = p_delta; }
double BPMEvent::get_delta_time() const { return delta_time; }
void BPMEvent::set_beat_count(int p_count) { beat_count = p_count; }
int BPMEvent::get_beat_count() const { return beat_count; }

// BPMManager implementation
void BPMManager::_bind_methods() {
	ClassDB::bind_method(D_METHOD("start", "bpm"), &BPMManager::start);
	ClassDB::bind_method(D_METHOD("stop"), &BPMManager::stop);
	ClassDB::bind_method(D_METHOD("set_bpm", "bpm"), &BPMManager::set_bpm);
	ClassDB::bind_method(D_METHOD("get_bpm"), &BPMManager::get_bpm);

	ADD_SIGNAL(MethodInfo("bpm_event_trigger",
			PropertyInfo(Variant::OBJECT, "event", PROPERTY_HINT_RESOURCE_TYPE, "BPMEvent")));

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "bpm"), "set_bpm", "get_bpm");
}

BPMManager::BPMManager() :
		bpm(0), active(false), timeline(0) {
	memset(subdivisions, 0, sizeof(subdivisions));
}

BPMManager::~BPMManager() {}

void BPMManager::calculate_subdivisions() {
	const double beat = 60.0 / bpm;

	subdivisions[BPMEvent::WHOLE] = { beat * 4, 0, 0 };
	subdivisions[BPMEvent::HALF] = { beat * 2, 0, 0 };
	subdivisions[BPMEvent::QUARTER] = { beat, 0, 0 };
	subdivisions[BPMEvent::EIGHTH] = { beat / 2, 0, 0 };
	subdivisions[BPMEvent::SIXTEENTH] = { beat / 4, 0, 0 };
	subdivisions[BPMEvent::SIXTYFOURTH] = { beat / 16, 0, 0 };
	subdivisions[BPMEvent::WHOLE_TRIPLET] = { beat * 8 / 3, 0, 0 };
	subdivisions[BPMEvent::HALF_TRIPLET] = { beat * 4 / 3, 0, 0 };
	subdivisions[BPMEvent::QUARTER_TRIPLET] = { beat * (2.0 / 3.0), 0, 0 };
	subdivisions[BPMEvent::EIGHTH_TRIPLET] = { beat / 3, 0, 0 };
	subdivisions[BPMEvent::SIXTEENTH_TRIPLET] = { beat / 6, 0, 0 };
}

void BPMManager::start(float p_bpm) {
	if (p_bpm <= 0) {
		UtilityFunctions::printerr("Invalid BPM: ", p_bpm);
		return;
	}

	bpm = p_bpm;
	active = true;
	timeline = 0;
	calculate_subdivisions();
}

void BPMManager::stop() {
	active = false;
	timeline = 0;
}

void BPMManager::set_bpm(float p_bpm) {
	if (p_bpm > 0 && bpm != p_bpm) {
		bpm = p_bpm;
		calculate_subdivisions();
	}
}

float BPMManager::get_bpm() const { return bpm; }

void BPMManager::_process(double delta) {
	if (!active)
		return;

	timeline += delta;

	for (int i = 0; i < BPMEvent::SUBDIVISION_MAX; i++) {
		SubdivisionTracker &tracker = subdivisions[i];

		while (timeline >= tracker.last_trigger + tracker.interval) {
			Ref<BPMEvent> event;
			event.instantiate();

			event->set_subdivision(static_cast<BPMEvent::Subdivision>(i));
			event->set_event_time(tracker.last_trigger + tracker.interval);
			event->set_delta_time(tracker.interval);
			event->set_beat_count(++tracker.beat_count);

			emit_signal("bpm_event_trigger", event);

			tracker.last_trigger += tracker.interval;
		}
	}
}