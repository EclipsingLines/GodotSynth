// // C++ (GDExtension) - Core Sequencer
// #include <godot_cpp/classes/ref_counted.hpp>
// #include ""
// namespace godot {

// class Sequencer : public RefCounted {

//     GDCLASS(Sequencer, RefCounted);

//     std::vector<NoteEvent> timeline;

// public:
// 	void add_note(double time, const MusicNote &note);
// 	void process(double current_time); // Sends MIDI/audio events
// };
// } //namespace godot