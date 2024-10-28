//Booting a server
s.boot;

// Some visualizers
(
s.meter;
s.plotTree;
s.scope;
FreqScope.new;
)
//Look into multichannel expansion
//Splay spreads them out on a stereo field


//Test buffer
 //var bufferPath = thisProcess.nowExecutingPath.dirname +/+ "VoiceAud.wav";
//Chnage path here to where the sound is located

b = Buffer.readChannel(s,"/Users/noelalben/github/granSynthSupe/VoiceAud.wav" , channels:[0]);
b.play;

//Write the granulator function

// Impulse and dust UGens

(
{
	var sig;
	sig = GrainBuf.ar(
		2,
		//Impulse UGen produces 10 grains per second at equal intervals, like a mettronome (It's a trigger)
		//Dust makes it random
		Dust.ar(100),
		0.3,
		b,
		MouseX.kr(0.5,2.1), // This sets the playback rate
		//Making the grain pointer move faster or slower. (how quickly we keep changing the position where the grain starts
		(
			Phasor.ar(0, MouseY.kr(0.1,2,1)*BufRateScale.ir(b), 0, BufSamples.ir(b)-1) + LFNoise1.ar(100).bipolar(0.001*SampleRate.ir)

		)/ BufSamples.ir(b), // Grain buff expects this to be between zero and 1 (Dividing it by the total number of samples)
		2,
		LFNoise1.kr(40).range(-1,1),
		-1,
		512



	);

}.play;
)

//Can make this a synthdef

ß