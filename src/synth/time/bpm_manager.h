#pragma once
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/ref_counted.hpp>

namespace godot {

class BPMEvent : public RefCounted {
	GDCLASS(BPMEvent, RefCounted)
public:
	enum Subdivision {
		WHOLE,
		HALF,
		QUARTER,
		EIGHTH,
		SIXTEENTH,
		//THIRTYSECOND,
		SIXTYFOURTH,
		WHOLE_TRIPLET,
		HALF_TRIPLET,
		QUARTER_TRIPLET,
		EIGHTH_TRIPLET,
		SIXTEENTH_TRIPLET,
		//THIRTYSECOND_TRIPLET,
		//SIXTYFOURTH_TRIPLET,
		SUBDIVISION_MAX
	};

private:
	Subdivision subdivision;
	double event_time;
	double delta_time;
	int beat_count;

protected:
	static void _bind_methods();

public:
	void set_subdivision(Subdivision p_subdivision);
	Subdivision get_subdivision() const;
	void set_event_time(double p_time);
	double get_event_time() const;
	void set_delta_time(double p_delta);
	double get_delta_time() const;
	void set_beat_count(int p_count);
	int get_beat_count() const;

	BPMEvent();
};

class BPMManager : public Node {
	GDCLASS(BPMManager, Node)

private:
	struct SubdivisionTracker {
		double interval;
		double last_trigger;
		int beat_count;
	};

	float bpm;
	bool active;
	double timeline;
	int subdivision_size;
	SubdivisionTracker subdivisions[BPMEvent::SUBDIVISION_MAX];

	void calculate_subdivisions();
	void process_subdivision(BPMEvent::Subdivision type, double delta);

protected:
	static void _bind_methods();

public:
	void start(float p_bpm);
	void stop();
	void set_bpm(float p_bpm);
	float get_bpm() const;

	void _process(double delta) override;

	BPMManager();
	~BPMManager();
};

} //namespace godot
VARIANT_ENUM_CAST(BPMEvent::Subdivision);