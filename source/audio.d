module audio;

import w4 = wasm4;

// Audio channel constants
enum Channel : ubyte {
    Pulse1 = 0,
    Pulse2 = 1,
    Triangle = 2,
    Noise = 3
}

// Duty cycles for pulse channels
enum DutyCycle : ubyte {
    Duty12_5 = 0, // 12.5%
    Duty25   = 1, // 25%
    Duty50   = 2, // 50%
    Duty75   = 3  // 75%
}

// Drum types for noise channel
enum DrumType : ubyte {
    None    = 0,
    Kick    = 1,
    Snare   = 2,
    HiHatCl = 3,
    HiHatOp = 4,
    Crash   = 5,
    Zap     = 6
}

struct SynthParams {
    ubyte dutyCycle;   // 0: 12.5%, 1: 25%, 2: 50%, 3: 75%
    ubyte attack;      // frames
    ubyte decay;       // frames
    ubyte sustain;     // frames
    ubyte release;     // frames
    ubyte sustainVol;  // 0..100
    ubyte peakVol;     // 0..100
    ubyte pan;         // 0: center, 1: left, 2: right
    bool muted;        // channel mute flag
}

// Pack ADSR envelope into duration uint
// Bits 0..7: sustain, Bits 8..15: release, Bits 16..23: decay, Bits 24..31: attack
uint packDuration(ubyte attack, ubyte decay, ubyte sustain, ubyte release) @nogc nothrow {
    return (cast(uint)attack << 24) |
           (cast(uint)decay << 16) |
           (cast(uint)release << 8) |
           cast(uint)sustain;
}

// Pack volume levels into volume uint
// Bits 0..7: sustainVolume, Bits 8..15: peakVolume
uint packVolume(ubyte sustainVol, ubyte peakVol) @nogc nothrow {
    return (cast(uint)peakVol << 8) | cast(uint)sustainVol;
}

// Pack tone flags
uint packFlags(ubyte channel, ubyte mode, ubyte pan, bool noteMode) @nogc nothrow {
    uint flags = channel & 0x3;
    flags |= (mode & 0x3) << 2;
    flags |= (pan & 0x3) << 4;
    if (noteMode) flags |= w4.toneNoteMode;
    return flags;
}

// Play a melodic note on Pulse1, Pulse2, or Triangle
void playMelodicNote(ubyte channel, ubyte midiNote, ref const(SynthParams) synth, ubyte velocity = 100) @nogc nothrow {
    if (synth.muted || midiNote == 0) return;

    ubyte peak = cast(ubyte)((cast(uint)synth.peakVol * velocity) / 100);
    ubyte sus = cast(ubyte)((cast(uint)synth.sustainVol * velocity) / 100);
    uint vol = packVolume(sus, peak);
    uint dur = packDuration(synth.attack, synth.decay, synth.sustain, synth.release);

    ubyte mode = (channel == Channel.Pulse1 || channel == Channel.Pulse2) ? synth.dutyCycle : 0;
    uint flags = packFlags(channel, mode, synth.pan, true);

    w4.tone(midiNote, dur, vol, flags);
}

enum DRUM_COUNT = 6;

// Default parameters for each of the 6 drum presets
void initDefaultDrums(ref SynthParams[DRUM_COUNT] drums) @nogc nothrow {
    // 0: Kick (7-bit low pitch drop)
    drums[0].attack = 0;
    drums[0].decay = 4;
    drums[0].sustain = 1;
    drums[0].release = 3;
    drums[0].sustainVol = 0;
    drums[0].peakVol = 100;
    drums[0].pan = 0;
    drums[0].muted = false;

    // 1: Snare (15-bit white noise snap)
    drums[1].attack = 0;
    drums[1].decay = 3;
    drums[1].sustain = 2;
    drums[1].release = 8;
    drums[1].sustainVol = 30;
    drums[1].peakVol = 100;
    drums[1].pan = 0;
    drums[1].muted = false;

    // 2: Closed Hi-Hat (Tight 15-bit click)
    drums[2].attack = 0;
    drums[2].decay = 1;
    drums[2].sustain = 0;
    drums[2].release = 2;
    drums[2].sustainVol = 0;
    drums[2].peakVol = 70;
    drums[2].pan = 0;
    drums[2].muted = false;

    // 3: Open Hi-Hat (Sizzling 15-bit decay)
    drums[3].attack = 0;
    drums[3].decay = 4;
    drums[3].sustain = 2;
    drums[3].release = 10;
    drums[3].sustainVol = 25;
    drums[3].peakVol = 85;
    drums[3].pan = 0;
    drums[3].muted = false;

    // 4: Crash (Shimmering long cymbal)
    drums[4].attack = 1;
    drums[4].decay = 8;
    drums[4].sustain = 4;
    drums[4].release = 24;
    drums[4].sustainVol = 50;
    drums[4].peakVol = 100;
    drums[4].pan = 0;
    drums[4].muted = false;

    // 5: Zap (Arcade laser slide)
    drums[5].attack = 0;
    drums[5].decay = 5;
    drums[5].sustain = 1;
    drums[5].release = 4;
    drums[5].sustainVol = 0;
    drums[5].peakVol = 100;
    drums[5].pan = 0;
    drums[5].muted = false;
}

// Play a drum hit on the noise channel using its specific SynthParams
void playDrum(ubyte drumType, ref const(SynthParams) synth, ubyte velocity = 100) @nogc nothrow {
    if (synth.muted || drumType == DrumType.None) return;

    uint baseVol = (cast(uint)synth.peakVol * velocity) / 100;
    if (baseVol > 100) baseVol = 100;

    uint dur = packDuration(synth.attack, synth.decay, synth.sustain, synth.release);
    uint susVol = (cast(uint)synth.sustainVol * baseVol) / 100;
    uint vol = packVolume(cast(ubyte)susVol, cast(ubyte)baseVol);

    switch (drumType) {
        case DrumType.Kick: {
            // Classic Game Boy kick: punchy downward frequency slide with 7-bit noise buzz
            uint freq = (35 << 16) | 160;
            uint flags = packFlags(w4.toneNoise, 1, synth.pan, false); // 7-bit metallic mode
            w4.tone(freq, dur, vol, flags);
            break;
        }

        case DrumType.Snare: {
            // Snappy Game Boy snare: 15-bit noise burst
            uint freq = 1400;
            uint flags = packFlags(w4.toneNoise, 0, synth.pan, false); // 15-bit white noise
            w4.tone(freq, dur, vol, flags);
            break;
        }

        case DrumType.HiHatCl: {
            // Short closed hi-hat: high pitch 15-bit noise
            uint freq = 4800;
            uint flags = packFlags(w4.toneNoise, 0, synth.pan, false);
            w4.tone(freq, dur, vol, flags);
            break;
        }

        case DrumType.HiHatOp: {
            // Open hi-hat: sizzling 15-bit noise with longer fade
            uint freq = 4200;
            uint flags = packFlags(w4.toneNoise, 0, synth.pan, false);
            w4.tone(freq, dur, vol, flags);
            break;
        }

        case DrumType.Crash: {
            // Shimmering cymbal crash
            uint freq = 2400;
            uint flags = packFlags(w4.toneNoise, 0, synth.pan, false);
            w4.tone(freq, dur, vol, flags);
            break;
        }

        case DrumType.Zap: {
            // Retro arcade laser/zap: rapid frequency drop in 7-bit mode
            uint freq = (70 << 16) | 950;
            uint flags = packFlags(w4.toneNoise, 1, synth.pan, false);
            w4.tone(freq, dur, vol, flags);
            break;
        }

        default:
            break;
    }
}

// Convert MIDI note number to 3-char note name (e.g. 60 -> "C-4", 61 -> "C#4")
void noteToString(ubyte note, char* outBuf) @nogc nothrow {
    if (note == 0) {
        outBuf[0] = '-';
        outBuf[1] = '-';
        outBuf[2] = '-';
        outBuf[3] = '\0';
        return;
    }

    static immutable char[2][12] noteNames = [
        ['C', '-'], ['C', '#'], ['D', '-'], ['D', '#'],
        ['E', '-'], ['F', '-'], ['F', '#'], ['G', '-'],
        ['G', '#'], ['A', '-'], ['A', '#'], ['B', '-']
    ];

    ubyte semitone = note % 12;
    int octave = (cast(int)note / 12) - 1;
    if (octave < 0) octave = 0;
    if (octave > 9) octave = 9;

    outBuf[0] = noteNames[semitone][0];
    outBuf[1] = noteNames[semitone][1];
    outBuf[2] = cast(char)('0' + octave);
    outBuf[3] = '\0';
}

// Convert drum type to 3-char name
void drumToString(ubyte drum, char* outBuf) @nogc nothrow {
    switch (drum) {
        case DrumType.Kick:
            outBuf[0] = 'K'; outBuf[1] = 'C'; outBuf[2] = 'K'; outBuf[3] = '\0';
            break;
        case DrumType.Snare:
            outBuf[0] = 'S'; outBuf[1] = 'N'; outBuf[2] = 'R'; outBuf[3] = '\0';
            break;
        case DrumType.HiHatCl:
            outBuf[0] = 'H'; outBuf[1] = 'A'; outBuf[2] = 'T'; outBuf[3] = '\0';
            break;
        case DrumType.HiHatOp:
            outBuf[0] = 'O'; outBuf[1] = 'P'; outBuf[2] = 'H'; outBuf[3] = '\0';
            break;
        case DrumType.Crash:
            outBuf[0] = 'C'; outBuf[1] = 'R'; outBuf[2] = 'S'; outBuf[3] = '\0';
            break;
        case DrumType.Zap:
            outBuf[0] = 'Z'; outBuf[1] = 'A'; outBuf[2] = 'P'; outBuf[3] = '\0';
            break;
        default:
            outBuf[0] = '-'; outBuf[1] = '-'; outBuf[2] = '-'; outBuf[3] = '\0';
            break;
    }
}
