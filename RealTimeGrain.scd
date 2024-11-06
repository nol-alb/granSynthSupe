ServerOptions.devices; //See available devices

s.options.device = "Focusrite Usb Audio"; //change to your device, can use s.options.in/outdevices if in/out are not the same

(
s.boot;
s.meter;
s.plotTree;
)

// x = {SoundIn.ar(0!2)}.play; // test audio in out


b = Buffer.alloc(s, s.sampleRate * 5, 1); //allocate 5 second buffer. This is what is where recorded audio is stored

(
~micBus = Bus.audio(s,1); // Routing busses
~ptrBus = Bus.audio(s,1);
)

(
SynthDef.new(\mic, {         // Receives audio from the input bus
	arg in =0, out=0, amp=1; // change in/out to the correct channels for your hardware
	var sig;
	sig = SoundIn.ar(in) * amp;
	Out.ar(out, sig);
}).add;


SynthDef.new(\ptr, {        // Ptr is used as an index for record into the buffer
	arg out=0, buf=0;
	var sig;
	sig = Phasor.ar(0,BufRateScale.kr(buf), 0, BufFrames.kr(buf));
	Out.ar(out,sig);
}).add;


SynthDef.new(\rec, {       // Records audio into the buffer. Ptr resets at end of the buffer, causing input audio to record over the beginning of the buffer
	arg ptrIn=0, micIn=0, buf=0;
	var ptr, sig;
	ptr = In.ar(ptrIn, 1);
	sig = In.ar(micIn, 1);
	BufWr.ar(sig, buf, ptr);
}).add;

SynthDef.new(\gran, {     // This is what does the actual synthesis by reading audio from the buffer
	arg amp=0.5, out=0, atk=1, rel=1, // default values
	buf=0, gate=1, sync=1, dens=40,
	baseDur=0.05, durRand=1,
	rate=1, rateRand=1,
	pan=0, panRand=0,
	grainEnv=(-1), ptrBus=0, ptrSampleDelay = 20000, ptrRandSamples = 5000,
	minPtrDelay=1000;

	var sig, env, densCtrl, durCtrl, rateCtrl, panCtrl, ptr, ptrRand, totalDelay, maxGrainDur;

	env = EnvGen.kr(Env.asr(atk,1,rel), gate, doneAction:2);
	densCtrl = Select.ar(sync, [Dust.ar(dens), Impulse.ar(dens)]);
	durCtrl = baseDur * LFNoise1.ar(100).exprange(1/durRand,durRand);
	rateCtrl = rate * LFNoise1.ar(100).exprange(1/rateRand,rateRand);
	panCtrl = pan + LFNoise1.kr(100).bipolar(panRand);

	ptrRand = LFNoise1.ar(100).bipolar(ptrRandSamples);
	totalDelay = max(ptrSampleDelay-ptrRandSamples, minPtrDelay);

	ptr = In.ar(ptrBus, 1);
	ptr = ptr-totalDelay;
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
	Out.ar(out,sig);
}).add;
)



(
~micGrp = Group.new;
~ptrGrp = Group.after(~micGrp);
~recGrp = Group.after(~ptrGrp);
~granGrp = Group.after(~recGrp);
)


(
Synth(\mic, [\in, 0, \out, ~micBus], ~micGrp);
Synth(\ptr, [\buf, b, \out, ~ptrBus], ~ptrGrp);
Synth(\rec, [\ptrIn, ~ptrBus, \micIn, ~micBus, \buf, b], ~recGrp);
)

b.plot; // buffer debugging. At this point in script, audio is being recorded constantly into the buffer. Use these commands to see and hear the recorded audio.
b.play;

(  // Starts gran
b.zero;
~g = Synth(\gran, [
	\amp, 0.5, // volume
	\buf, b,   // which buffer to read from
	\out, 0,   // out channel
	\atk, 1,   // attack of envelope for each grain
	\rel, 1,   // release of envelope for each grain
	\gate, 1,  // 1 to hear audio input, 0 to not hear audio input
	\sync, 1,  // 1 for quantized samples, 0 for random samples
	\dens, 40, // how many samples
	\baseDur, 0.05, // size of each grain
	\durRand, 1,    // 1 for no randomization
	\rate, 1,       // grain playback rate
	\rateRand, 1,   // 1 for no randomization
	\pan, 0,        // left right pan
    \panRand, 0,    // randomize panning
	\grainEnv, -1,  // -1 to use built in Hanning window
	\ptrBus, ~ptrBus,
	\ptrSampleDelay, s.sampleRate/3, // How far behind record do we read from
	\ptrRandSamples, s.sampleRate/6, // read from ptr randomization
	\minPtrDelay, 1000,
], ~granGrp);
)




s.defaultGroup.deepFree;  //Free nodes but keep groups





Server.killAll;

