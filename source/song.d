module song;

import w4 = wasm4;
import audio;

enum STEPS_PER_PAT = 16;
enum MAX_CHANNELS = 4;
enum MAX_PATTERNS = 4;
enum MAX_PLAYLIST = 8;

struct Step {
    ubyte note;    // 0 = rest. Pulse/Tri: MIDI note (e.g. 36..84). Noise: DrumType (1..6)
    ubyte volume;  // 0 = default (100%), or 1..100
}

struct Pattern {
    Step[MAX_CHANNELS][STEPS_PER_PAT] steps; // [stepIdx][channelIdx]
}

struct Song {
    uint magic;          // 0x51533457 ("W4SQ")
    ubyte versionNum;    // 2
    ubyte bpm;           // e.g. 132
    ubyte playlistLen;   // e.g. 4
    ubyte[MAX_PLAYLIST] playlist; // indices of patterns to play
    audio.SynthParams[MAX_CHANNELS] synths;
    audio.SynthParams[audio.DRUM_COUNT] drums; // Independent synth params per drum pad!
    Pattern[MAX_PATTERNS] patterns;
}

// Magic constant: "W4SQ"
enum SONG_MAGIC = 0x51533457;
enum SONG_VERSION = 2;

// Default synth parameters matching authentic Game Boy sound
void initDefaultSynths(ref audio.SynthParams[MAX_CHANNELS] synths) @nogc nothrow {
    // Pulse 1: Classic 50% square lead
    synths[audio.Channel.Pulse1].dutyCycle = audio.DutyCycle.Duty50;
    synths[audio.Channel.Pulse1].attack = 0;
    synths[audio.Channel.Pulse1].decay = 4;
    synths[audio.Channel.Pulse1].sustain = 8;
    synths[audio.Channel.Pulse1].release = 6;
    synths[audio.Channel.Pulse1].sustainVol = 80;
    synths[audio.Channel.Pulse1].peakVol = 100;
    synths[audio.Channel.Pulse1].pan = 0;
    synths[audio.Channel.Pulse1].muted = false;

    // Pulse 2: 25% pulse for crunchy counter-melody / arp
    synths[audio.Channel.Pulse2].dutyCycle = audio.DutyCycle.Duty25;
    synths[audio.Channel.Pulse2].attack = 0;
    synths[audio.Channel.Pulse2].decay = 3;
    synths[audio.Channel.Pulse2].sustain = 6;
    synths[audio.Channel.Pulse2].release = 5;
    synths[audio.Channel.Pulse2].sustainVol = 70;
    synths[audio.Channel.Pulse2].peakVol = 90;
    synths[audio.Channel.Pulse2].pan = 0;
    synths[audio.Channel.Pulse2].muted = false;

    // Triangle: Deep warm bass
    synths[audio.Channel.Triangle].dutyCycle = 0;
    synths[audio.Channel.Triangle].attack = 0;
    synths[audio.Channel.Triangle].decay = 2;
    synths[audio.Channel.Triangle].sustain = 10;
    synths[audio.Channel.Triangle].release = 4;
    synths[audio.Channel.Triangle].sustainVol = 95;
    synths[audio.Channel.Triangle].peakVol = 100;
    synths[audio.Channel.Triangle].pan = 0;
    synths[audio.Channel.Triangle].muted = false;

    // Noise: Percussion / Drums
    synths[audio.Channel.Noise].dutyCycle = 0;
    synths[audio.Channel.Noise].attack = 0;
    synths[audio.Channel.Noise].decay = 4;
    synths[audio.Channel.Noise].sustain = 2;
    synths[audio.Channel.Noise].release = 8;
    synths[audio.Channel.Noise].sustainVol = 50;
    synths[audio.Channel.Noise].peakVol = 100;
    synths[audio.Channel.Noise].pan = 0;
    synths[audio.Channel.Noise].muted = false;
}

// Clear all patterns in the song
void clearAllPatterns(ref Song song) @nogc nothrow {
    for (int p = 0; p < MAX_PATTERNS; ++p) {
        for (int s = 0; s < STEPS_PER_PAT; ++s) {
            for (int c = 0; c < MAX_CHANNELS; ++c) {
                song.patterns[p].steps[s][c].note = 0;
                song.patterns[p].steps[s][c].volume = 100;
            }
        }
    }
}

// Clear a single pattern
void clearPattern(ref Pattern pattern) @nogc nothrow {
    for (int s = 0; s < STEPS_PER_PAT; ++s) {
        for (int c = 0; c < MAX_CHANNELS; ++c) {
            pattern.steps[s][c].note = 0;
            pattern.steps[s][c].volume = 100;
        }
    }
}

// Initialize the Cool Demo Song (Epic Game Boy Chiptune)
void initDemoSong(ref Song song) @nogc nothrow {
    song.magic = SONG_MAGIC;
    song.versionNum = SONG_VERSION;
    song.bpm = 132;
    song.playlistLen = 4;
    song.playlist[0] = 0;
    song.playlist[1] = 1;
    song.playlist[2] = 2;
    song.playlist[3] = 3;
    song.playlist[4] = 0;
    song.playlist[5] = 0;
    song.playlist[6] = 0;
    song.playlist[7] = 0;

    initDefaultSynths(song.synths);
    audio.initDefaultDrums(song.drums);
    clearAllPatterns(song);

    // =========================================================================
    // PATTERN 0: Main Theme - The Hook
    // Key: C Minor (C, Eb, F, G, Bb)
    // =========================================================================
    // Pulse 1: Lead Melody
    song.patterns[0].steps[0][0].note = 72;  // C-5
    song.patterns[0].steps[2][0].note = 72;  // C-5
    song.patterns[0].steps[3][0].note = 75;  // Eb5
    song.patterns[0].steps[4][0].note = 77;  // F-5
    song.patterns[0].steps[6][0].note = 79;  // G-5
    song.patterns[0].steps[8][0].note = 79;  // G-5
    song.patterns[0].steps[10][0].note = 82; // Bb5
    song.patterns[0].steps[11][0].note = 79; // G-5
    song.patterns[0].steps[12][0].note = 77; // F-5
    song.patterns[0].steps[14][0].note = 75; // Eb5

    // Pulse 2: Syncopated 16th Arpeggios
    song.patterns[0].steps[0][1].note = 60;  // C-4
    song.patterns[0].steps[1][1].note = 63;  // Eb4
    song.patterns[0].steps[2][1].note = 67;  // G-4
    song.patterns[0].steps[3][1].note = 60;  // C-4
    song.patterns[0].steps[4][1].note = 65;  // F-4
    song.patterns[0].steps[5][1].note = 68;  // Ab4
    song.patterns[0].steps[6][1].note = 72;  // C-5
    song.patterns[0].steps[7][1].note = 65;  // F-4
    song.patterns[0].steps[8][1].note = 67;  // G-4
    song.patterns[0].steps[9][1].note = 70;  // Bb4
    song.patterns[0].steps[10][1].note = 74; // D-5
    song.patterns[0].steps[11][1].note = 67; // G-4
    song.patterns[0].steps[12][1].note = 63; // Eb4
    song.patterns[0].steps[13][1].note = 67; // G-4
    song.patterns[0].steps[14][1].note = 70; // Bb4
    song.patterns[0].steps[15][1].note = 67; // G-4

    // Triangle: Bouncy Octave Bass
    song.patterns[0].steps[0][2].note = 48;  // C-3
    song.patterns[0].steps[2][2].note = 36;  // C-2
    song.patterns[0].steps[4][2].note = 41;  // F-2
    song.patterns[0].steps[6][2].note = 53;  // F-3
    song.patterns[0].steps[8][2].note = 43;  // G-2
    song.patterns[0].steps[10][2].note = 55; // G-3
    song.patterns[0].steps[12][2].note = 39; // Eb2
    song.patterns[0].steps[14][2].note = 43; // G-2

    // Noise: Drums
    song.patterns[0].steps[0][3].note = audio.DrumType.Crash;
    song.patterns[0].steps[2][3].note = audio.DrumType.HiHatCl;
    song.patterns[0].steps[4][3].note = audio.DrumType.Snare;
    song.patterns[0].steps[6][3].note = audio.DrumType.HiHatCl;
    song.patterns[0].steps[8][3].note = audio.DrumType.Kick;
    song.patterns[0].steps[10][3].note = audio.DrumType.HiHatCl;
    song.patterns[0].steps[12][3].note = audio.DrumType.Snare;
    song.patterns[0].steps[14][3].note = audio.DrumType.HiHatOp;
    song.patterns[0].steps[15][3].note = audio.DrumType.HiHatCl;

    // =========================================================================
    // PATTERN 1: Uplifting Development
    // =========================================================================
    // Pulse 1: Climax Melody
    song.patterns[1].steps[0][0].note = 84;  // C-6
    song.patterns[1].steps[2][0].note = 82;  // Bb5
    song.patterns[1].steps[4][0].note = 79;  // G-5
    song.patterns[1].steps[6][0].note = 77;  // F-5
    song.patterns[1].steps[8][0].note = 79;  // G-5
    song.patterns[1].steps[9][0].note = 82;  // Bb5
    song.patterns[1].steps[10][0].note = 84; // C-6
    song.patterns[1].steps[12][0].note = 86; // D-6
    song.patterns[1].steps[14][0].note = 84; // C-6

    // Pulse 2: Harmonizing counter-line
    song.patterns[1].steps[0][1].note = 75;  // Eb5
    song.patterns[1].steps[2][1].note = 74;  // D-5
    song.patterns[1].steps[4][1].note = 72;  // C-5
    song.patterns[1].steps[6][1].note = 70;  // Bb4
    song.patterns[1].steps[8][1].note = 72;  // C-5
    song.patterns[1].steps[9][1].note = 75;  // Eb5
    song.patterns[1].steps[10][1].note = 77; // F-5
    song.patterns[1].steps[12][1].note = 79; // G-5
    song.patterns[1].steps[14][1].note = 75; // Eb5

    // Triangle: Walking Bass
    song.patterns[1].steps[0][2].note = 44;  // Ab2
    song.patterns[1].steps[2][2].note = 56;  // Ab3
    song.patterns[1].steps[4][2].note = 46;  // Bb2
    song.patterns[1].steps[6][2].note = 58;  // Bb3
    song.patterns[1].steps[8][2].note = 48;  // C-3
    song.patterns[1].steps[10][2].note = 51; // Eb3
    song.patterns[1].steps[12][2].note = 43; // G-2
    song.patterns[1].steps[14][2].note = 46; // Bb2

    // Noise: Driving Rock Beat
    song.patterns[1].steps[0][3].note = audio.DrumType.Kick;
    song.patterns[1].steps[2][3].note = audio.DrumType.HiHatCl;
    song.patterns[1].steps[4][3].note = audio.DrumType.Snare;
    song.patterns[1].steps[6][3].note = audio.DrumType.HiHatCl;
    song.patterns[1].steps[8][3].note = audio.DrumType.Kick;
    song.patterns[1].steps[10][3].note = audio.DrumType.Kick;
    song.patterns[1].steps[12][3].note = audio.DrumType.Snare;
    song.patterns[1].steps[14][3].note = audio.DrumType.Snare;
    song.patterns[1].steps[15][3].note = audio.DrumType.HiHatCl;

    // =========================================================================
    // PATTERN 2: Speed Run / Solo
    // =========================================================================
    // Pulse 1: 16th Note Run
    song.patterns[2].steps[0][0].note = 72;  // C-5
    song.patterns[2].steps[1][0].note = 75;  // Eb5
    song.patterns[2].steps[2][0].note = 79;  // G-5
    song.patterns[2].steps[3][0].note = 84;  // C-6
    song.patterns[2].steps[4][0].note = 79;  // G-5
    song.patterns[2].steps[5][0].note = 75;  // Eb5
    song.patterns[2].steps[6][0].note = 74;  // D-5
    song.patterns[2].steps[7][0].note = 77;  // F-5
    song.patterns[2].steps[8][0].note = 80;  // Ab5
    song.patterns[2].steps[9][0].note = 86;  // D-6
    song.patterns[2].steps[10][0].note = 80; // Ab5
    song.patterns[2].steps[11][0].note = 77; // F-5
    song.patterns[2].steps[12][0].note = 75; // Eb5
    song.patterns[2].steps[13][0].note = 79; // G-5
    song.patterns[2].steps[14][0].note = 82; // Bb5
    song.patterns[2].steps[15][0].note = 87; // Eb6

    // Pulse 2: Off-beat Stabs
    song.patterns[2].steps[2][1].note = 60;  // C-4
    song.patterns[2].steps[6][1].note = 62;  // D-4
    song.patterns[2].steps[10][1].note = 63; // Eb4
    song.patterns[2].steps[14][1].note = 67; // G-4

    // Triangle: Fast Pumping Bass
    song.patterns[2].steps[0][2].note = 36;  // C-2
    song.patterns[2].steps[1][2].note = 48;  // C-3
    song.patterns[2].steps[2][2].note = 36;  // C-2
    song.patterns[2].steps[3][2].note = 48;  // C-3
    song.patterns[2].steps[4][2].note = 38;  // D-2
    song.patterns[2].steps[5][2].note = 50;  // D-3
    song.patterns[2].steps[6][2].note = 38;  // D-2
    song.patterns[2].steps[7][2].note = 50;  // D-3
    song.patterns[2].steps[8][2].note = 39;  // Eb2
    song.patterns[2].steps[9][2].note = 51;  // Eb3
    song.patterns[2].steps[10][2].note = 39; // Eb2
    song.patterns[2].steps[11][2].note = 51; // Eb3
    song.patterns[2].steps[12][2].note = 43; // G-2
    song.patterns[2].steps[13][2].note = 55; // G-3
    song.patterns[2].steps[14][2].note = 43; // G-2
    song.patterns[2].steps[15][2].note = 55; // G-3

    // Noise: Fast Drum Beats + Zap
    song.patterns[2].steps[0][3].note = audio.DrumType.Kick;
    song.patterns[2].steps[2][3].note = audio.DrumType.Snare;
    song.patterns[2].steps[4][3].note = audio.DrumType.Kick;
    song.patterns[2].steps[6][3].note = audio.DrumType.Snare;
    song.patterns[2].steps[8][3].note = audio.DrumType.Kick;
    song.patterns[2].steps[10][3].note = audio.DrumType.Snare;
    song.patterns[2].steps[12][3].note = audio.DrumType.Kick;
    song.patterns[2].steps[14][3].note = audio.DrumType.Zap;
    song.patterns[2].steps[15][3].note = audio.DrumType.Crash;

    // =========================================================================
    // PATTERN 3: Breakdown & Crescendo Drop
    // =========================================================================
    // Pulse 1: Sustained Notes
    song.patterns[3].steps[0][0].note = 72;  // C-5
    song.patterns[3].steps[6][0].note = 74;  // D-5
    song.patterns[3].steps[8][0].note = 75;  // Eb5
    song.patterns[3].steps[12][0].note = 77; // F-5
    song.patterns[3].steps[14][0].note = 79; // G-5

    // Pulse 2: Rising Echoes
    song.patterns[3].steps[2][1].note = 67;  // G-4
    song.patterns[3].steps[5][1].note = 70;  // Bb4
    song.patterns[3].steps[8][1].note = 72;  // C-5
    song.patterns[3].steps[11][1].note = 74; // D-5
    song.patterns[3].steps[14][1].note = 75; // Eb5

    // Triangle: Sub Bass Grooves
    song.patterns[3].steps[0][2].note = 36;  // C-2
    song.patterns[3].steps[4][2].note = 36;  // C-2
    song.patterns[3].steps[8][2].note = 31;  // G-1
    song.patterns[3].steps[12][2].note = 34; // Bb1

    // Noise: Rising Snare / Drum Roll
    song.patterns[3].steps[0][3].note = audio.DrumType.HiHatCl;
    song.patterns[3].steps[2][3].note = audio.DrumType.HiHatCl;
    song.patterns[3].steps[4][3].note = audio.DrumType.HiHatCl;
    song.patterns[3].steps[6][3].note = audio.DrumType.HiHatCl;
    song.patterns[3].steps[8][3].note = audio.DrumType.Snare;
    song.patterns[3].steps[9][3].note = audio.DrumType.Snare;
    song.patterns[3].steps[10][3].note = audio.DrumType.Snare;
    song.patterns[3].steps[11][3].note = audio.DrumType.Snare;
    song.patterns[3].steps[12][3].note = audio.DrumType.Snare;
    song.patterns[3].steps[13][3].note = audio.DrumType.Snare;
    song.patterns[3].steps[14][3].note = audio.DrumType.Zap;
    song.patterns[3].steps[15][3].note = audio.DrumType.Crash;
}

// =============================================================================
// DEMO SONG 2: "MEGAMAN RUSH" (Capcom NES / GB Heroic Stage Theme)
// 150 BPM, D Minor, Rapid 16th rolling bass, soaring heroic square leads
// =============================================================================
void initDemoMegaman(ref Song song) @nogc nothrow {
    song.magic = SONG_MAGIC;
    song.versionNum = SONG_VERSION;
    song.bpm = 150;
    song.playlistLen = 4;
    song.playlist[0] = 0;
    song.playlist[1] = 1;
    song.playlist[2] = 2;
    song.playlist[3] = 3;

    initDefaultSynths(song.synths);
    audio.initDefaultDrums(song.drums);
    clearAllPatterns(song);

    // Pulse 1: 50% square, crisp attack & release
    song.synths[audio.Channel.Pulse1].dutyCycle = audio.DutyCycle.Duty50;
    song.synths[audio.Channel.Pulse1].attack = 0;
    song.synths[audio.Channel.Pulse1].decay = 3;
    song.synths[audio.Channel.Pulse1].sustain = 8;
    song.synths[audio.Channel.Pulse1].release = 4;
    song.synths[audio.Channel.Pulse1].sustainVol = 85;
    song.synths[audio.Channel.Pulse1].peakVol = 100;

    // Pulse 2: 25% duty cycle, punchy harmonizer
    song.synths[audio.Channel.Pulse2].dutyCycle = audio.DutyCycle.Duty25;
    song.synths[audio.Channel.Pulse2].attack = 0;
    song.synths[audio.Channel.Pulse2].decay = 3;
    song.synths[audio.Channel.Pulse2].sustain = 6;
    song.synths[audio.Channel.Pulse2].release = 3;
    song.synths[audio.Channel.Pulse2].sustainVol = 75;
    song.synths[audio.Channel.Pulse2].peakVol = 90;

    // Triangle: Ultra punchy 16th bass
    song.synths[audio.Channel.Triangle].attack = 0;
    song.synths[audio.Channel.Triangle].decay = 1;
    song.synths[audio.Channel.Triangle].sustain = 12;
    song.synths[audio.Channel.Triangle].release = 2;
    song.synths[audio.Channel.Triangle].sustainVol = 100;
    song.synths[audio.Channel.Triangle].peakVol = 100;

    // --- PATTERN 0: Main Heroic Stage Theme ---
    // Pulse 1: Lead Melody (D5, D5, F5, G5, A5, C6, A5...)
    song.patterns[0].steps[0][0].note = 74;  // D-5
    song.patterns[0].steps[1][0].note = 74;  // D-5
    song.patterns[0].steps[2][0].note = 77;  // F-5
    song.patterns[0].steps[3][0].note = 79;  // G-5
    song.patterns[0].steps[4][0].note = 81;  // A-5
    song.patterns[0].steps[6][0].note = 81;  // A-5
    song.patterns[0].steps[7][0].note = 84;  // C-6
    song.patterns[0].steps[8][0].note = 81;  // A-5
    song.patterns[0].steps[9][0].note = 79;  // G-5
    song.patterns[0].steps[10][0].note = 77; // F-5
    song.patterns[0].steps[11][0].note = 74; // D-5
    song.patterns[0].steps[12][0].note = 77; // F-5
    song.patterns[0].steps[14][0].note = 79; // G-5

    // Pulse 2: Harmonizing lower line (F4, F4, A4, C5, D5...)
    song.patterns[0].steps[0][1].note = 65;  // F-4
    song.patterns[0].steps[1][1].note = 65;  // F-4
    song.patterns[0].steps[2][1].note = 69;  // A-4
    song.patterns[0].steps[3][1].note = 72;  // C-5
    song.patterns[0].steps[4][1].note = 74;  // D-5
    song.patterns[0].steps[6][1].note = 74;  // D-5
    song.patterns[0].steps[7][1].note = 77;  // F-5
    song.patterns[0].steps[8][1].note = 74;  // D-5
    song.patterns[0].steps[9][1].note = 72;  // C-5
    song.patterns[0].steps[10][1].note = 69; // A-4
    song.patterns[0].steps[11][1].note = 65; // F-4
    song.patterns[0].steps[12][1].note = 69; // A-4
    song.patterns[0].steps[14][1].note = 72; // C-5

    // Triangle: Continuous rolling 16th bassline (Mega Man signature!)
    song.patterns[0].steps[0][2].note = 50;  // D-3
    song.patterns[0].steps[1][2].note = 38;  // D-2
    song.patterns[0].steps[2][2].note = 50;  // D-3
    song.patterns[0].steps[3][2].note = 38;  // D-2
    song.patterns[0].steps[4][2].note = 50;  // D-3
    song.patterns[0].steps[5][2].note = 38;  // D-2
    song.patterns[0].steps[6][2].note = 50;  // D-3
    song.patterns[0].steps[7][2].note = 38;  // D-2
    song.patterns[0].steps[8][2].note = 53;  // F-3
    song.patterns[0].steps[9][2].note = 41;  // F-2
    song.patterns[0].steps[10][2].note = 55; // G-3
    song.patterns[0].steps[11][2].note = 43; // G-2
    song.patterns[0].steps[12][2].note = 57; // A-3
    song.patterns[0].steps[13][2].note = 45; // A-2
    song.patterns[0].steps[14][2].note = 48; // C-3
    song.patterns[0].steps[15][2].note = 60; // C-4

    // Noise: Fast rock beat
    song.patterns[0].steps[0][3].note = audio.DrumType.Crash;
    song.patterns[0].steps[2][3].note = audio.DrumType.HiHatCl;
    song.patterns[0].steps[4][3].note = audio.DrumType.Snare;
    song.patterns[0].steps[6][3].note = audio.DrumType.HiHatCl;
    song.patterns[0].steps[8][3].note = audio.DrumType.Kick;
    song.patterns[0].steps[9][3].note = audio.DrumType.Kick;
    song.patterns[0].steps[10][3].note = audio.DrumType.HiHatCl;
    song.patterns[0].steps[12][3].note = audio.DrumType.Snare;
    song.patterns[0].steps[14][3].note = audio.DrumType.Snare;
    song.patterns[0].steps[15][3].note = audio.DrumType.HiHatCl;

    // --- PATTERN 1: Wily Fortress B-Section ---
    song.patterns[1].steps[0][0].note = 82;  // Bb5
    song.patterns[1].steps[2][0].note = 84;  // C-6
    song.patterns[1].steps[4][0].note = 86;  // D-6
    song.patterns[1].steps[6][0].note = 84;  // C-6
    song.patterns[1].steps[7][0].note = 82;  // Bb5
    song.patterns[1].steps[8][0].note = 81;  // A-5
    song.patterns[1].steps[10][0].note = 79; // G-5
    song.patterns[1].steps[12][0].note = 81; // A-5
    song.patterns[1].steps[14][0].note = 74; // D-5

    song.patterns[1].steps[0][1].note = 74;  // D-5
    song.patterns[1].steps[2][1].note = 76;  // E-5
    song.patterns[1].steps[4][1].note = 77;  // F-5
    song.patterns[1].steps[6][1].note = 76;  // E-5
    song.patterns[1].steps[7][1].note = 74;  // D-5
    song.patterns[1].steps[8][1].note = 72;  // C-5
    song.patterns[1].steps[10][1].note = 70; // Bb4
    song.patterns[1].steps[12][1].note = 72; // C-5
    song.patterns[1].steps[14][1].note = 69; // A-4

    // Triangle: Octave pumping bass
    song.patterns[1].steps[0][2].note = 46;  // Bb2
    song.patterns[1].steps[1][2].note = 58;  // Bb3
    song.patterns[1].steps[2][2].note = 46;  // Bb2
    song.patterns[1].steps[3][2].note = 58;  // Bb3
    song.patterns[1].steps[4][2].note = 48;  // C-3
    song.patterns[1].steps[5][2].note = 60;  // C-4
    song.patterns[1].steps[6][2].note = 48;  // C-3
    song.patterns[1].steps[7][2].note = 60;  // C-4
    song.patterns[1].steps[8][2].note = 50;  // D-3
    song.patterns[1].steps[9][2].note = 62;  // D-4
    song.patterns[1].steps[10][2].note = 50; // D-3
    song.patterns[1].steps[11][2].note = 62; // D-4
    song.patterns[1].steps[12][2].note = 45; // A-2
    song.patterns[1].steps[13][2].note = 57; // A-3
    song.patterns[1].steps[14][2].note = 48; // C-3
    song.patterns[1].steps[15][2].note = 60; // C-4

    song.patterns[1].steps[0][3].note = audio.DrumType.Kick;
    song.patterns[1].steps[2][3].note = audio.DrumType.HiHatCl;
    song.patterns[1].steps[4][3].note = audio.DrumType.Snare;
    song.patterns[1].steps[6][3].note = audio.DrumType.HiHatCl;
    song.patterns[1].steps[8][3].note = audio.DrumType.Kick;
    song.patterns[1].steps[10][3].note = audio.DrumType.HiHatCl;
    song.patterns[1].steps[12][3].note = audio.DrumType.Snare;
    song.patterns[1].steps[14][3].note = audio.DrumType.Snare;
    song.patterns[1].steps[15][3].note = audio.DrumType.HiHatOp;

    // --- PATTERN 2: 16th Solo Run (Boss Encounter) ---
    song.patterns[2].steps[0][0].note = 74;  // D-5
    song.patterns[2].steps[1][0].note = 76;  // E-5
    song.patterns[2].steps[2][0].note = 77;  // F-5
    song.patterns[2].steps[3][0].note = 79;  // G-5
    song.patterns[2].steps[4][0].note = 81;  // A-5
    song.patterns[2].steps[5][0].note = 84;  // C-6
    song.patterns[2].steps[6][0].note = 86;  // D-6
    song.patterns[2].steps[7][0].note = 89;  // F-6
    song.patterns[2].steps[8][0].note = 88;  // E-6
    song.patterns[2].steps[9][0].note = 86;  // D-6
    song.patterns[2].steps[10][0].note = 84; // C-6
    song.patterns[2].steps[11][0].note = 81; // A-5
    song.patterns[2].steps[12][0].note = 79; // G-5
    song.patterns[2].steps[13][0].note = 77; // F-5
    song.patterns[2].steps[14][0].note = 79; // G-5
    song.patterns[2].steps[15][0].note = 81; // A-5

    // Staccato stabs on Pulse 2
    song.patterns[2].steps[0][1].note = 62;  // D-4
    song.patterns[2].steps[4][1].note = 65;  // F-4
    song.patterns[2].steps[8][1].note = 69;  // A-4
    song.patterns[2].steps[12][1].note = 72; // C-5

    // Rolling bass
    for (int s = 0; s < 16; ++s) {
        song.patterns[2].steps[s][2].note = cast(ubyte)(s % 2 == 0 ? 50 : 38);
    }

    song.patterns[2].steps[0][3].note = audio.DrumType.Kick;
    song.patterns[2].steps[2][3].note = audio.DrumType.Snare;
    song.patterns[2].steps[4][3].note = audio.DrumType.Kick;
    song.patterns[2].steps[6][3].note = audio.DrumType.Snare;
    song.patterns[2].steps[8][3].note = audio.DrumType.Kick;
    song.patterns[2].steps[10][3].note = audio.DrumType.Snare;
    song.patterns[2].steps[12][3].note = audio.DrumType.Kick;
    song.patterns[2].steps[14][3].note = audio.DrumType.Zap;
    song.patterns[2].steps[15][3].note = audio.DrumType.Crash;

    // --- PATTERN 3: Dramatic Climax & Loop Reset ---
    song.patterns[3].steps[0][0].note = 86;  // D-6
    song.patterns[3].steps[4][0].note = 84;  // C-6
    song.patterns[3].steps[8][0].note = 82;  // Bb5
    song.patterns[3].steps[12][0].note = 81; // A-5

    song.patterns[3].steps[0][1].note = 74;  // D-5
    song.patterns[3].steps[4][1].note = 72;  // C-5
    song.patterns[3].steps[8][1].note = 70;  // Bb4
    song.patterns[3].steps[12][1].note = 69; // A-4

    song.patterns[3].steps[0][2].note = 50;  // D-3
    song.patterns[3].steps[4][2].note = 48;  // C-3
    song.patterns[3].steps[8][2].note = 46;  // Bb2
    song.patterns[3].steps[12][2].note = 45; // A-2
    song.patterns[3].steps[14][2].note = 43; // G-2
    song.patterns[3].steps[15][2].note = 45; // A-2

    for (int s = 0; s < 12; s += 2) {
        song.patterns[3].steps[s][3].note = audio.DrumType.HiHatCl;
    }
    song.patterns[3].steps[12][3].note = audio.DrumType.Snare;
    song.patterns[3].steps[13][3].note = audio.DrumType.Snare;
    song.patterns[3].steps[14][3].note = audio.DrumType.Snare;
    song.patterns[3].steps[15][3].note = audio.DrumType.Crash;
}

// =============================================================================
// DEMO SONG 3: "CYBER DNB 174" (Modern Drum & Bass / Jungle)
// 174 BPM, F Minor, 16th Amen break rhythm, 808 Reese sub bass, cyberpunk arps
// =============================================================================
void initDemoDnB(ref Song song) @nogc nothrow {
    song.magic = SONG_MAGIC;
    song.versionNum = SONG_VERSION;
    song.bpm = 174;
    song.playlistLen = 4;
    song.playlist[0] = 0;
    song.playlist[1] = 1;
    song.playlist[2] = 2;
    song.playlist[3] = 3;

    initDefaultSynths(song.synths);
    audio.initDefaultDrums(song.drums);
    clearAllPatterns(song);

    // Pulse 1: 12.5% thin reese/acid pluck
    song.synths[audio.Channel.Pulse1].dutyCycle = audio.DutyCycle.Duty12_5;
    song.synths[audio.Channel.Pulse1].attack = 0;
    song.synths[audio.Channel.Pulse1].decay = 2;
    song.synths[audio.Channel.Pulse1].sustain = 4;
    song.synths[audio.Channel.Pulse1].release = 2;
    song.synths[audio.Channel.Pulse1].sustainVol = 60;
    song.synths[audio.Channel.Pulse1].peakVol = 95;

    // Pulse 2: 50% square atmospheric stab
    song.synths[audio.Channel.Pulse2].dutyCycle = audio.DutyCycle.Duty50;
    song.synths[audio.Channel.Pulse2].attack = 0;
    song.synths[audio.Channel.Pulse2].decay = 5;
    song.synths[audio.Channel.Pulse2].sustain = 6;
    song.synths[audio.Channel.Pulse2].release = 8;
    song.synths[audio.Channel.Pulse2].sustainVol = 70;
    song.synths[audio.Channel.Pulse2].peakVol = 85;

    // Triangle: Deep sub bass with long sustain
    song.synths[audio.Channel.Triangle].attack = 0;
    song.synths[audio.Channel.Triangle].decay = 1;
    song.synths[audio.Channel.Triangle].sustain = 15;
    song.synths[audio.Channel.Triangle].release = 2;
    song.synths[audio.Channel.Triangle].sustainVol = 100;
    song.synths[audio.Channel.Triangle].peakVol = 100;

    // --- PATTERN 0: The Classic DnB Amen Roller ---
    // Pulse 1: Techy Cyberpunk Arp
    song.patterns[0].steps[0][0].note = 65;  // F-4
    song.patterns[0].steps[1][0].note = 68;  // Ab4
    song.patterns[0].steps[2][0].note = 72;  // C-5
    song.patterns[0].steps[3][0].note = 75;  // Eb5
    song.patterns[0].steps[4][0].note = 72;  // C-5
    song.patterns[0].steps[5][0].note = 68;  // Ab4
    song.patterns[0].steps[6][0].note = 65;  // F-4
    song.patterns[0].steps[7][0].note = 66;  // Gb4
    song.patterns[0].steps[8][0].note = 65;  // F-4
    song.patterns[0].steps[9][0].note = 68;  // Ab4
    song.patterns[0].steps[10][0].note = 72; // C-5
    song.patterns[0].steps[11][0].note = 77; // F-5
    song.patterns[0].steps[12][0].note = 75; // Eb5
    song.patterns[0].steps[13][0].note = 72; // C-5
    song.patterns[0].steps[14][0].note = 70; // Bb4
    song.patterns[0].steps[15][0].note = 68; // Ab4

    // Pulse 2: Off-beat chord stabs
    song.patterns[0].steps[2][1].note = 60;  // C-4
    song.patterns[0].steps[6][1].note = 61;  // Db4
    song.patterns[0].steps[10][1].note = 60; // C-4
    song.patterns[0].steps[14][1].note = 58; // Bb3

    // Triangle: Heavy 808 Sub Bassline
    song.patterns[0].steps[0][2].note = 41;  // F-2
    song.patterns[0].steps[3][2].note = 41;  // F-2
    song.patterns[0].steps[6][2].note = 41;  // F-2
    song.patterns[0].steps[8][2].note = 44;  // Ab2
    song.patterns[0].steps[10][2].note = 46; // Bb2
    song.patterns[0].steps[12][2].note = 49; // Db3
    song.patterns[0].steps[14][2].note = 48; // C-3

    // Noise: Syncopated DnB Amen Break (174 BPM!)
    song.patterns[0].steps[0][3].note = audio.DrumType.Kick;
    song.patterns[0].steps[1][3].note = audio.DrumType.HiHatCl;
    song.patterns[0].steps[2][3].note = audio.DrumType.HiHatCl;
    song.patterns[0].steps[3][3].note = audio.DrumType.HiHatCl;
    song.patterns[0].steps[4][3].note = audio.DrumType.Snare;
    song.patterns[0].steps[5][3].note = audio.DrumType.HiHatCl;
    song.patterns[0].steps[6][3].note = audio.DrumType.HiHatCl;
    song.patterns[0].steps[7][3].note = audio.DrumType.Snare; // ghost snare!
    song.patterns[0].steps[8][3].note = audio.DrumType.HiHatCl;
    song.patterns[0].steps[9][3].note = audio.DrumType.HiHatCl;
    song.patterns[0].steps[10][3].note = audio.DrumType.Kick;  // off-beat kick!
    song.patterns[0].steps[11][3].note = audio.DrumType.HiHatCl;
    song.patterns[0].steps[12][3].note = audio.DrumType.Snare;
    song.patterns[0].steps[13][3].note = audio.DrumType.HiHatCl;
    song.patterns[0].steps[14][3].note = audio.DrumType.HiHatOp;
    song.patterns[0].steps[15][3].note = audio.DrumType.Snare; // ghost pickup!

    // --- PATTERN 1: The DnB Roller ---
    song.patterns[1].steps[0][0].note = 77;  // F-5
    song.patterns[1].steps[2][0].note = 75;  // Eb5
    song.patterns[1].steps[4][0].note = 72;  // C-5
    song.patterns[1].steps[6][0].note = 70;  // Bb4
    song.patterns[1].steps[8][0].note = 72;  // C-5
    song.patterns[1].steps[10][0].note = 75; // Eb5
    song.patterns[1].steps[12][0].note = 77; // F-5
    song.patterns[1].steps[14][0].note = 80; // Ab5

    song.patterns[1].steps[1][1].note = 65;  // F-4
    song.patterns[1].steps[5][1].note = 68;  // Ab4
    song.patterns[1].steps[9][1].note = 65;  // F-4
    song.patterns[1].steps[13][1].note = 61; // Db4

    // Rolling syncopated sub bass
    song.patterns[1].steps[0][2].note = 29;  // F-1
    song.patterns[1].steps[2][2].note = 41;  // F-2
    song.patterns[1].steps[4][2].note = 41;  // F-2
    song.patterns[1].steps[6][2].note = 44;  // Ab2
    song.patterns[1].steps[8][2].note = 29;  // F-1
    song.patterns[1].steps[10][2].note = 46; // Bb2
    song.patterns[1].steps[12][2].note = 41; // F-2
    song.patterns[1].steps[14][2].note = 49; // Db3

    // Double kick DnB groove
    song.patterns[1].steps[0][3].note = audio.DrumType.Kick;
    song.patterns[1].steps[2][3].note = audio.DrumType.HiHatCl;
    song.patterns[1].steps[4][3].note = audio.DrumType.Snare;
    song.patterns[1].steps[6][3].note = audio.DrumType.HiHatCl;
    song.patterns[1].steps[8][3].note = audio.DrumType.Kick;
    song.patterns[1].steps[10][3].note = audio.DrumType.Kick;
    song.patterns[1].steps[12][3].note = audio.DrumType.Snare;
    song.patterns[1].steps[14][3].note = audio.DrumType.HiHatOp;
    song.patterns[1].steps[15][3].note = audio.DrumType.Snare;

    // --- PATTERN 2: Neurofunk Drop ---
    song.patterns[2].steps[0][0].note = 65;  // F-4
    song.patterns[2].steps[3][0].note = 66;  // Gb4
    song.patterns[2].steps[6][0].note = 65;  // F-4
    song.patterns[2].steps[9][0].note = 68;  // Ab4
    song.patterns[2].steps[12][0].note = 65; // F-4
    song.patterns[2].steps[15][0].note = 72; // C-5

    song.patterns[2].steps[2][1].note = 53;  // F-3
    song.patterns[2].steps[6][1].note = 56;  // Ab3
    song.patterns[2].steps[10][1].note = 58; // Bb3
    song.patterns[2].steps[14][1].note = 61; // Db4

    // Deep sub hits
    song.patterns[2].steps[0][2].note = 41;  // F-2
    song.patterns[2].steps[4][2].note = 41;  // F-2
    song.patterns[2].steps[8][2].note = 39;  // Eb2
    song.patterns[2].steps[12][2].note = 37; // Db2
    song.patterns[2].steps[14][2].note = 36; // C-2

    song.patterns[2].steps[0][3].note = audio.DrumType.Kick;
    song.patterns[2].steps[2][3].note = audio.DrumType.Zap;
    song.patterns[2].steps[4][3].note = audio.DrumType.Snare;
    song.patterns[2].steps[6][3].note = audio.DrumType.HiHatCl;
    song.patterns[2].steps[8][3].note = audio.DrumType.Kick;
    song.patterns[2].steps[10][3].note = audio.DrumType.Kick;
    song.patterns[2].steps[12][3].note = audio.DrumType.Snare;
    song.patterns[2].steps[14][3].note = audio.DrumType.Zap;
    song.patterns[2].steps[15][3].note = audio.DrumType.Crash;

    // --- PATTERN 3: Jungle Breakdown & Build ---
    song.patterns[3].steps[0][0].note = 65;  // F-4
    song.patterns[3].steps[4][0].note = 68;  // Ab4
    song.patterns[3].steps[8][0].note = 72;  // C-5
    song.patterns[3].steps[12][0].note = 77; // F-5

    song.patterns[3].steps[2][1].note = 60;  // C-4
    song.patterns[3].steps[6][1].note = 63;  // Eb4
    song.patterns[3].steps[10][1].note = 67; // G-4
    song.patterns[3].steps[14][1].note = 70; // Bb4

    song.patterns[3].steps[0][2].note = 29;  // F-1
    song.patterns[3].steps[8][2].note = 32;  // Ab1

    // Snare rush build up
    for (int s = 0; s < 8; s += 2) {
        song.patterns[3].steps[s][3].note = audio.DrumType.HiHatCl;
    }
    song.patterns[3].steps[8][3].note = audio.DrumType.Snare;
    song.patterns[3].steps[9][3].note = audio.DrumType.Snare;
    song.patterns[3].steps[10][3].note = audio.DrumType.Snare;
    song.patterns[3].steps[11][3].note = audio.DrumType.Snare;
    song.patterns[3].steps[12][3].note = audio.DrumType.Snare;
    song.patterns[3].steps[13][3].note = audio.DrumType.Snare;
    song.patterns[3].steps[14][3].note = audio.DrumType.Zap;
    song.patterns[3].steps[15][3].note = audio.DrumType.Crash;
}

// Save song to WASM-4 persistent cartridge storage
bool saveSongToDisk(ref const(Song) song) @nogc nothrow {
    uint written = w4.diskw(cast(const(void)*)&song, Song.sizeof);
    return (written == Song.sizeof);
}

// Load song from WASM-4 persistent cartridge storage
bool loadSongFromDisk(ref Song song) @nogc nothrow {
    Song temp;
    uint bytesRead = w4.diskr(cast(void*)&temp, Song.sizeof);
    if (bytesRead >= Song.sizeof && temp.magic == SONG_MAGIC && temp.versionNum == SONG_VERSION) {
        song = temp;
        return true;
    }
    return false;
}
