ServerOptions.devices;
s.options.device = "Focusrite Usb Audio"; // change to your device

(
s.boot;
s.meter;
s.plotTree;
)

// Allocate a 5-second buffer for recording audio
b = Buffer.alloc(s, s.sampleRate * 5, 1);

(
~micBus = Bus.audio(s, 1); // Routing busses
~ptrBus = Bus.audio(s, 1);
)

// Synth Definitions
(
SynthDef.new(\mic, {         // Receives audio from the input bus
	arg in = 0, out = 0, amp = 1;
	var sig;
	sig = SoundIn.ar(in) * amp;
	Out.ar(out, sig);
}).add;

SynthDef.new(\ptr, {         // Pointer for indexing the recording buffer
	arg out = 0, buf = 0;
	var sig;
	sig = Phasor.ar(0, BufRateScale.kr(buf), 0, BufFrames.kr(buf));
	Out.ar(out, sig);
}).add;

SynthDef.new(\rec, {         // Records audio into the buffer
	arg ptrIn = 0, micIn = 0, buf = 0;
	var ptr, sig;
	ptr = In.ar(ptrIn, 1);
	sig = In.ar(micIn, 1);
	BufWr.ar(sig, buf, ptr);
}).add;

// Random Pitch Shifting
SynthDef.new(\gran, {
	arg amp = 0.5, out = 0, atk = 1, rel = 1, buf = 0, gate = 1, sync = 1, dens = 40,
	baseDur = 0.05, durRand = 1, rate = 1, rateRand = 1, pan = 0, panRand = 0,
	pitchShiftRange = 0.2, // Range for random pitch shifting
	grainEnv = (-1), ptrBus = 0, ptrSampleDelay = 20000, ptrRandSamples = 5000, minPtrDelay = 1000;

	var sig, env, densCtrl, durCtrl, rateCtrl, panCtrl, ptr, ptrRand, totalDelay, maxGrainDur, pitchShift;

	env = EnvGen.kr(Env.asr(atk, 1, rel), gate, doneAction: 2);
	densCtrl = Select.ar(sync, [Dust.ar(dens), Impulse.ar(dens)]);
	durCtrl = baseDur * LFNoise1.ar(100).exprange(1 / durRand, durRand);
	rateCtrl = rate * LFNoise1.ar(100).exprange(1 / rateRand, rateRand);
	panCtrl = pan + LFNoise1.kr(100).bipolar(panRand);

	// Random pitch shifting
	pitchShift = LFNoise1.ar(100).bipolar(pitchShiftRange) + 1; // Randomize rate within the specified range
	rateCtrl = rateCtrl * pitchShift;

	ptrRand = LFNoise1.ar(100).bipolar(ptrRandSamples);
	totalDelay = max(ptrSampleDelay - ptrRandSamples, minPtrDelay);

	ptr = In.ar(ptrBus, 1);
	ptr = ptr - totalDelay;
	ptr = ptr / BufFrames.kr(buf);

	maxGrainDur = (totalDelay / rateCtrl) / SampleRate.ir;
	durCtrl = min(durCtrl, maxGrainDur);

	sig = GrainBuf.ar(
		2,
		densCtrl,
		durCtrl,
		buf,
		rateCtrl,
		ptr,
		2,
		panCtrl,
		grainEnv
	);

	sig = sig * env * amp;
	Out.ar(out, sig);
}).add;
)

// Create groups to organize the synths
(
~micGrp = Group.new;
~ptrGrp = Group.after(~micGrp);
~recGrp = Group.after(~ptrGrp);
~granGrp = Group.after(~recGrp);
)

// Start the microphone, pointer, and recording synths
(
Synth(\mic, [\in, 0, \out, ~micBus], ~micGrp);
Synth(\ptr, [\buf, b, \out, ~ptrBus], ~ptrGrp);
Synth(\rec, [\ptrIn, ~ptrBus, \micIn, ~micBus, \buf, b], ~recGrp);
)

// Debugging: plot and play the buffer
b.plot;
b.play;

// Start the granular synthesis with random pitch shifting
(
b.zero;
~g = Synth(\gran, [
	\amp, 0.5,     // Volume
	\buf, b,       // Buffer to read from
	\out, 0,       // Output channel
	\atk, 1,       // Attack time for each grain
	\rel, 1,       // Release time for each grain
	\gate, 1,      // Gate to control audio input
	\sync, 1,      // 1 for quantized, 0 for random
	\dens, 40,     // Grain density
	\baseDur, 0.05,// Grain duration
	\durRand, 1,   // Duration randomness
	\rate, 1,      // Playback rate
	\rateRand, 1,  // Rate randomness
	\pan, 0,       // Stereo panning
	\panRand, 0,   // Pan randomness
	\pitchShiftRange, 0.2, // Amount of random pitch shifting
	\grainEnv, -1, // Grain envelope (Hanning window)
	\ptrBus, ~ptrBus,
	\ptrSampleDelay, s.sampleRate / 3, // Delay before reading from pointer
	\ptrRandSamples, s.sampleRate / 6, // Randomize pointer read position
	\minPtrDelay, 1000,  // Minimum pointer delay
], ~granGrp);
)

// Clean up and free nodes while keeping groups
s.defaultGroup.deepFree;

// Completely reset server state
Server.killAll;
