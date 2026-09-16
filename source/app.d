module app;

import w4 = wasm4;
import audio;
import song;
import ui;

// Palette Themes
enum PaletteTheme : ubyte {
    DmgGreen = 0,
    PocketBw = 1,
    CyberNeon = 2,
    AmberCrt = 3
}

static immutable uint[4][4] PALETTES = [
    // 0: Classic Game Boy DMG Green
    [0x9bbc0f, 0x8bac0f, 0x306230, 0x0f380f],
    // 1: Game Boy Pocket (Clean Monochrome)
    [0xe0f8d0, 0x88c070, 0x346856, 0x081820],
    // 2: Cyber Neon
    [0xfafafa, 0x29b6f6, 0x7e57c2, 0x1a0033],
    // 3: Warm Amber Retro
    [0xfff9c4, 0xffb74d, 0xf57c00, 0x3e2723],
];

enum Tab : ubyte {
    Seq = 0,
    Synth = 1,
    SongTab = 2
}

// Global App State
__gshared {
    song.Song currentSong;
    Tab currentTab = Tab.Seq;
    PaletteTheme currentTheme = PaletteTheme.DmgGreen;

    // Playback state
    bool isPlaying = false;
    bool playSongMode = true; // true: full arrangement, false: loop current pattern
    int currentStep = 0;
    ubyte currentPlaylistIdx = 0;
    ubyte currentPattern = 0;
    uint tickAccumulator = 0;

    // Sequencer cursor
    int cursorStep = 0;     // 0..15
    int cursorChannel = 0;  // 0..3
    ubyte currentOctave = 4; // 2..6

    // Synth editor state
    ubyte selectedSynthChannel = 0; // 0..3

    // Input state
    ubyte prevGamepad = 0;
    ubyte prevMouse = 0;
    short prevMouseX = 0;
    short prevMouseY = 0;
    int heldDir = 0;
    int holdTimer = 0;

    // Notification banner
    char[32] bannerMsg;
    int bannerTimer = 0;
}

void applyPalette(PaletteTheme theme) @nogc nothrow {
    currentTheme = theme;
    for (int i = 0; i < 4; ++i) {
        w4.palette[i] = PALETTES[theme][i];
    }
}

void setBanner(const(char)[] msg) @nogc nothrow {
    size_t len = msg.length;
    if (len >= bannerMsg.length) len = bannerMsg.length - 1;
    for (size_t i = 0; i < len; ++i) {
        bannerMsg[i] = msg[i];
    }
    bannerMsg[len] = '\0';
    bannerTimer = 120; // 2 seconds at 60 fps
}

// Audition the note at the given channel and note number
void audition(ubyte channel, ubyte note) @nogc nothrow {
    if (channel < 3) {
        if (note > 0) {
            audio.playMelodicNote(channel, note, currentSong.synths[channel], 100);
        }
    } else {
        if (note > 0) {
            audio.playDrum(note, currentSong.synths[audio.Channel.Noise], 100);
        }
    }
}

// Trigger all notes at a given pattern and step
void playStepNotes(ubyte patIdx, int stepIdx) @nogc nothrow {
    if (patIdx >= song.MAX_PATTERNS || stepIdx < 0 || stepIdx >= song.STEPS_PER_PAT) return;

    for (ubyte c = 0; c < 3; ++c) {
        ubyte n = currentSong.patterns[patIdx].steps[stepIdx][c].note;
        if (n > 0) {
            audio.playMelodicNote(c, n, currentSong.synths[c], 100);
        }
    }

    // Noise / Drum channel
    ubyte drum = currentSong.patterns[patIdx].steps[stepIdx][3].note;
    if (drum > 0) {
        audio.playDrum(drum, currentSong.synths[audio.Channel.Noise], 100);
    }
}

// Advance playback by one 16th-note step
void stepForward() @nogc nothrow {
    currentStep++;
    if (currentStep >= song.STEPS_PER_PAT) {
        currentStep = 0;
        if (playSongMode) {
            currentPlaylistIdx++;
            if (currentPlaylistIdx >= currentSong.playlistLen) {
                currentPlaylistIdx = 0;
            }
            currentPattern = currentSong.playlist[currentPlaylistIdx];
        }
    }
    playStepNotes(currentPattern, currentStep);
}

// Update playback clock (rock-solid 60Hz tick accumulator)
void updatePlayback() @nogc nothrow {
    if (!isPlaying) return;

    tickAccumulator += cast(uint)currentSong.bpm * 4;
    while (tickAccumulator >= 3600) {
        tickAccumulator -= 3600;
        stepForward();
    }
}

// Modify current cell note
void modifyCurrentCell(int semitoneDelta) @nogc nothrow {
    ref song.Step st = currentSong.patterns[currentPattern].steps[cursorStep][cursorChannel];
    if (cursorChannel < 3) {
        if (st.note == 0) {
            st.note = cast(ubyte)(currentOctave * 12); // Base C in current octave
        } else {
            int newNote = cast(int)st.note + semitoneDelta;
            if (newNote < 24) newNote = 24;
            if (newNote > 96) newNote = 96;
            st.note = cast(ubyte)newNote;
        }
        audition(cast(ubyte)cursorChannel, st.note);
    } else {
        // Drum channel
        int newDrum = cast(int)st.note + semitoneDelta;
        if (newDrum < 0) newDrum = audio.DrumType.Zap;
        if (newDrum > audio.DrumType.Zap) newDrum = 0;
        st.note = cast(ubyte)newDrum;
        audition(3, st.note);
    }
}

// Clear current cell
void clearCurrentCell() @nogc nothrow {
    currentSong.patterns[currentPattern].steps[cursorStep][cursorChannel].note = 0;
}

// =============================================================================
// RENDERING
// =============================================================================

// Draw top navigation bar (Tabs & Play status)
void drawTopBar(int mx, int my, bool mClick) @nogc nothrow {
    // Background bar
    ui.drawRect(0, 0, 160, 12, 0x22);

    // Tab buttons: SEQ, SYNTH, SONG
    static immutable string[3] tabNames = ["SEQ", "SYNTH", "SONG"];
    static immutable int[3] tabX = [2, 38, 86];
    static immutable int[3] tabW = [34, 46, 40];

    for (ubyte i = 0; i < 3; ++i) {
        bool active = (currentTab == i);
        bool hover = ui.pointInRect(mx, my, tabX[i], 1, tabW[i], 10);
        if (hover && mClick) {
            currentTab = cast(Tab)i;
        }
        ui.drawButton(tabX[i], 1, tabW[i], 10, tabNames[i], active, hover);
    }

    // Play/Pause icon in top right
    bool playHover = ui.pointInRect(mx, my, 132, 1, 26, 10);
    if (playHover && mClick) {
        isPlaying = !isPlaying;
        if (isPlaying) {
            tickAccumulator = 0;
            playStepNotes(currentPattern, currentStep);
        }
    }
    ui.drawButton(132, 1, 26, 10, isPlaying ? "||" : ">", isPlaying, playHover);
}

// Draw SEQ TAB: 16-step 4-channel tracker grid
void drawSeqTab(int mx, int my, bool mClick, bool mRight) @nogc nothrow {
    // Sub-header (y: 13..21)
    ui.drawRect(0, 12, 160, 10, 0x11);

    // Pattern selector
    ui.drawText("P:", 2, 13, 0x04);
    ui.drawNumber(currentPattern, 18, 13, 0x04);

    // Prev / Next Pattern buttons
    if (ui.pointInRect(mx, my, 28, 13, 10, 8) && mClick) {
        if (currentPattern > 0) currentPattern--;
    }
    ui.drawButton(28, 13, 10, 8, "<", false, ui.pointInRect(mx, my, 28, 13, 10, 8));

    if (ui.pointInRect(mx, my, 40, 13, 10, 8) && mClick) {
        if (currentPattern + 1 < song.MAX_PATTERNS) currentPattern++;
    }
    ui.drawButton(40, 13, 10, 8, ">", false, ui.pointInRect(mx, my, 40, 13, 10, 8));

    // BPM display
    ui.drawNumber(currentSong.bpm, 54, 13, 0x04, 3);
    ui.drawText("BPM", 80, 13, 0x03);

    // Mode: PAT / SNG
    bool modeHover = ui.pointInRect(mx, my, 110, 13, 48, 8);
    if (modeHover && mClick) {
        playSongMode = !playSongMode;
    }
    ui.drawButton(110, 13, 48, 8, playSongMode ? "SNG-ALL" : "PAT-LOOP", playSongMode, modeHover);

    // Column Headers (y: 22..29)
    ui.drawRect(0, 22, 160, 8, 0x33);
    ui.drawText("ST", 2, 22, 0x14);
    ui.drawText("P1", 28, 22, 0x14);
    ui.drawText("P2", 60, 22, 0x14);
    ui.drawText("TR", 92, 22, 0x14);
    ui.drawText("NO", 124, 22, 0x14);

    // 16 Rows of Steps (y: 30..142)
    static immutable int[4] colX = [26, 58, 90, 122];
    char[4] strBuf;

    for (int s = 0; s < 16; ++s) {
        int ry = 30 + s * 7;
        bool isPlayRow = (isPlaying && currentStep == s);
        bool isBeat = (s % 4 == 0);

        // Row background
        if (isPlayRow) {
            ui.drawRect(0, ry, 160, 7, 0x43); // Highlight playhead
        } else if (isBeat) {
            ui.drawRect(0, ry, 160, 7, 0x22); // Beat separator
        }

        // Step number
        ushort numCol = isPlayRow ? 0x14 : (isBeat ? 0x04 : 0x03);
        if (s < 10) {
            ui.drawText("0", 2, ry, numCol);
            ui.drawNumber(s, 10, ry, numCol);
        } else {
            ui.drawNumber(s, 2, ry, numCol, 2);
        }

        // Channels
        for (int c = 0; c < 4; ++c) {
            int cx = colX[c];
            bool isCursor = (cursorStep == s && cursorChannel == c);

            // Handle mouse click on cell
            if (ui.pointInRect(mx, my, cx - 1, ry, 30, 7)) {
                if (mClick) {
                    if (isCursor) {
                        modifyCurrentCell(1); // Cycle note
                    } else {
                        cursorStep = s;
                        cursorChannel = c;
                        ubyte n = currentSong.patterns[currentPattern].steps[s][c].note;
                        audition(cast(ubyte)c, n);
                    }
                } else if (mRight) {
                    cursorStep = s;
                    cursorChannel = c;
                    clearCurrentCell();
                }
            }

            // Cell highlight box
            if (isCursor) {
                ui.drawRect(cx - 2, ry - 1, 31, 8, 0x44);
            }

            // Note text
            ubyte noteVal = currentSong.patterns[currentPattern].steps[s][c].note;
            if (c < 3) {
                audio.noteToString(noteVal, strBuf.ptr);
            } else {
                audio.drumToString(noteVal, strBuf.ptr);
            }

            ushort textCol;
            if (isCursor) {
                textCol = 0x14; // Inverted text on cursor
            } else if (noteVal > 0) {
                textCol = isPlayRow ? 0x14 : 0x04; // Active note
            } else {
                textCol = isPlayRow ? 0x14 : 0x03; // Rest note
            }

            ui.drawCString(strBuf.ptr, cx, ry, textCol);
        }
    }

    // Bottom Toolbar (y: 143..160)
    ui.drawRect(0, 143, 160, 17, 0x22);

    // Play button
    bool pClick = ui.pointInRect(mx, my, 2, 145, 26, 13);
    if (pClick && mClick) {
        isPlaying = !isPlaying;
        if (isPlaying) {
            tickAccumulator = 0;
            playStepNotes(currentPattern, currentStep);
        }
    }
    ui.drawButton(2, 145, 26, 13, isPlaying ? "STOP" : "PLAY", isPlaying, pClick);

    // Octave controls
    ui.drawText("OCT", 32, 148, 0x04);
    ui.drawNumber(currentOctave, 56, 148, 0x04);

    if (ui.pointInRect(mx, my, 66, 145, 12, 13) && mClick) {
        if (currentOctave > 1) currentOctave--;
    }
    ui.drawButton(66, 145, 12, 13, "-", false, ui.pointInRect(mx, my, 66, 145, 12, 13));

    if (ui.pointInRect(mx, my, 80, 145, 12, 13) && mClick) {
        if (currentOctave < 7) currentOctave++;
    }
    ui.drawButton(80, 145, 12, 13, "+", false, ui.pointInRect(mx, my, 80, 145, 12, 13));

    // Note - / + buttons
    if (ui.pointInRect(mx, my, 96, 145, 16, 13) && mClick) {
        modifyCurrentCell(-1);
    }
    ui.drawButton(96, 145, 16, 13, "-N", false, ui.pointInRect(mx, my, 96, 145, 16, 13));

    if (ui.pointInRect(mx, my, 114, 145, 16, 13) && mClick) {
        modifyCurrentCell(1);
    }
    ui.drawButton(114, 145, 16, 13, "+N", false, ui.pointInRect(mx, my, 114, 145, 16, 13));

    // Clear note button
    if (ui.pointInRect(mx, my, 133, 145, 25, 13) && mClick) {
        clearCurrentCell();
    }
    ui.drawButton(133, 145, 25, 13, "DEL", false, ui.pointInRect(mx, my, 133, 145, 25, 13));
}

// Draw SYNTH TAB: sound design, ADSR envelopes, duty cycles, drum presets
void drawSynthTab(int mx, int my, bool mClick) @nogc nothrow {
    // Channel Selectors: [P1] [P2] [TR] [NO] (y: 14..24)
    static immutable string[4] chNames = ["PULSE1", "PULSE2", "TRIANGLE", "NOISE"];
    static immutable int[4] chX = [2, 42, 86, 126];
    static immutable int[4] chW = [38, 42, 38, 32];

    for (ubyte i = 0; i < 4; ++i) {
        bool active = (selectedSynthChannel == i);
        bool hover = ui.pointInRect(mx, my, chX[i], 14, chW[i], 11);
        if (hover && mClick) {
            selectedSynthChannel = i;
        }
        ui.drawButton(chX[i], 14, chW[i], 11, chNames[i], active, hover);
    }

    ref audio.SynthParams synth = currentSong.synths[selectedSynthChannel];

    // Mute toggle
    bool muteHover = ui.pointInRect(mx, my, 112, 28, 46, 10);
    if (muteHover && mClick) {
        synth.muted = !synth.muted;
    }
    ui.drawButton(112, 28, 46, 10, synth.muted ? "MUTED" : "ACTIVE", synth.muted, muteHover);

    int yPos = 28;

    // Channel specific controls
    if (selectedSynthChannel == audio.Channel.Pulse1 || selectedSynthChannel == audio.Channel.Pulse2) {
        // Duty cycle: 12.5%, 25%, 50%, 75%
        ui.drawText("DUTY:", 4, yPos + 1, 0x04);
        static immutable string[4] dutyLabels = ["12%", "25%", "50%", "75%"];
        for (ubyte d = 0; d < 4; ++d) {
            int dx = 42 + d * 22;
            bool active = (synth.dutyCycle == d);
            bool hover = ui.pointInRect(mx, my, dx, yPos, 20, 10);
            if (hover && mClick) {
                synth.dutyCycle = d;
                audition(selectedSynthChannel, 60);
            }
            ui.drawButton(dx, yPos, 20, 10, dutyLabels[d], active, hover);
        }
        yPos += 14;
    } else if (selectedSynthChannel == audio.Channel.Noise) {
        // Drum test pads
        ui.drawText("PADS:", 4, yPos + 1, 0x04);
        static immutable string[6] drumLabels = ["KCK", "SNR", "HAT", "OPH", "CRS", "ZAP"];
        for (ubyte d = 0; d < 6; ++d) {
            int dx = 42 + (d % 3) * 22;
            int dy = yPos + (d / 3) * 11;
            bool hover = ui.pointInRect(mx, my, dx, dy, 20, 10);
            if (hover && mClick) {
                audio.playDrum(cast(ubyte)(d + 1), synth, 100);
            }
            ui.drawButton(dx, dy, 20, 10, drumLabels[d], false, hover);
        }
        yPos += 24;
    } else {
        ui.drawText("TRIANGLE: WARM BASS", 4, yPos + 1, 0x03);
        yPos += 14;
    }

    // ADSR Envelope Controls
    // Attack
    drawParamRow("ATTACK", synth.attack, 0, 30, 4, yPos, mx, my, mClick);
    yPos += 12;

    // Decay
    drawParamRow("DECAY", synth.decay, 0, 30, 4, yPos, mx, my, mClick);
    yPos += 12;

    // Sustain
    drawParamRow("SUSTAIN", synth.sustain, 0, 30, 4, yPos, mx, my, mClick);
    yPos += 12;

    // Release
    drawParamRow("RELEASE", synth.release, 0, 30, 4, yPos, mx, my, mClick);
    yPos += 12;

    // Peak Volume
    drawParamRow("PEAK-VOL", synth.peakVol, 0, 100, 4, yPos, mx, my, mClick, 5);
    yPos += 12;

    // Sustain Volume
    drawParamRow("SUS-VOL", synth.sustainVol, 0, 100, 4, yPos, mx, my, mClick, 5);
    yPos += 14;

    // Audition / Test Button
    bool testHover = ui.pointInRect(mx, my, 20, yPos, 120, 14);
    if (testHover && mClick) {
        if (selectedSynthChannel < 3) {
            audition(selectedSynthChannel, 60);
        } else {
            audio.playDrum(audio.DrumType.Snare, synth, 100);
        }
    }
    ui.drawButton(20, yPos, 120, 14, "TEST SOUND (AUDITION)", false, testHover);
}

// Helper to draw a parameter adjustment row: [LABEL] [-] [VAL] [+]
void drawParamRow(const(char)[] label, ref ubyte val, int minV, int maxV, int x, int y, int mx, int my, bool mClick, int step = 1) @nogc nothrow {
    ui.drawText(label, x, y + 1, 0x04);

    // Decrement button
    int btnMinusX = 84;
    bool hoverMinus = ui.pointInRect(mx, my, btnMinusX, y, 12, 10);
    if (hoverMinus && mClick) {
        if (cast(int)val - step >= minV) val = cast(ubyte)(val - step);
        else val = cast(ubyte)minV;
        audition(selectedSynthChannel, 60);
    }
    ui.drawButton(btnMinusX, y, 12, 10, "-", false, hoverMinus);

    // Value display
    ui.drawNumber(val, 102, y + 1, 0x04, 2);

    // Increment button
    int btnPlusX = 126;
    bool hoverPlus = ui.pointInRect(mx, my, btnPlusX, y, 12, 10);
    if (hoverPlus && mClick) {
        if (cast(int)val + step <= maxV) val = cast(ubyte)(val + step);
        else val = cast(ubyte)maxV;
        audition(selectedSynthChannel, 60);
    }
    ui.drawButton(btnPlusX, y, 12, 10, "+", false, hoverPlus);
}

// Draw SONG TAB: Playlist arranger, BPM, persistent disk save/load, demo songs, palette theme
void drawSongTab(int mx, int my, bool mClick) @nogc nothrow {
    int yPos = 14;

    // Tempo Control + Mode button on same row
    ui.drawText("BPM", 4, yPos + 2, 0x04);
    bool bMinus = ui.pointInRect(mx, my, 30, yPos, 12, 11);
    if (bMinus && mClick) {
        if (currentSong.bpm > 60) currentSong.bpm -= 2;
    }
    ui.drawButton(30, yPos, 12, 11, "-", false, bMinus);

    ui.drawNumber(currentSong.bpm, 45, yPos + 2, 0x04, 3);

    bool bPlus = ui.pointInRect(mx, my, 72, yPos, 12, 11);
    if (bPlus && mClick) {
        if (currentSong.bpm < 240) currentSong.bpm += 2;
    }
    ui.drawButton(72, yPos, 12, 11, "+", false, bPlus);

    // Playback Mode button
    bool playModeHover = ui.pointInRect(mx, my, 90, yPos, 66, 11);
    if (playModeHover && mClick) {
        playSongMode = !playSongMode;
    }
    ui.drawButton(90, yPos, 66, 11, playSongMode ? "ALL-SONG" : "LOOP-PAT", playSongMode, playModeHover);

    yPos += 14;

    // Arranger Playlist: [P0] [P1] [P2] [P3]
    ui.drawText("CHAIN:", 4, yPos + 2, 0x04);
    for (ubyte i = 0; i < currentSong.playlistLen; ++i) {
        int sx = 46 + i * 20;
        bool isCurrent = (isPlaying && currentPlaylistIdx == i);
        bool hover = ui.pointInRect(mx, my, sx, yPos, 18, 11);
        if (hover && mClick) {
            currentSong.playlist[i] = cast(ubyte)((currentSong.playlist[i] + 1) % song.MAX_PATTERNS);
        }

        char[4] pBuf;
        pBuf[0] = 'P';
        pBuf[1] = cast(char)('0' + currentSong.playlist[i]);
        pBuf[2] = '\0';
        ui.drawButton(sx, yPos, 18, 11, pBuf[0..2], isCurrent, hover);
    }

    // Playlist length controls
    int lenX = 46 + currentSong.playlistLen * 20;
    if (lenX < 132) {
        bool lenMinus = ui.pointInRect(mx, my, 130, yPos, 12, 11);
        if (lenMinus && mClick && currentSong.playlistLen > 1) {
            currentSong.playlistLen--;
        }
        ui.drawButton(130, yPos, 12, 11, "-", false, lenMinus);

        bool lenPlus = ui.pointInRect(mx, my, 144, yPos, 12, 11);
        if (lenPlus && mClick && currentSong.playlistLen < song.MAX_PLAYLIST) {
            currentSong.playlistLen++;
        }
        ui.drawButton(144, yPos, 12, 11, "+", false, lenPlus);
    }

    yPos += 14;

    // --- SONG PRESETS ---
    ui.drawRect(2, yPos, 156, 1, 0x33); // Divider
    yPos += 3;
    ui.drawText("DEMO SONGS:", 4, yPos, 0x03);
    yPos += 9;

    // 1: Mega Man
    bool megaHover = ui.pointInRect(mx, my, 4, yPos, 152, 11);
    if (megaHover && mClick) {
        song.initDemoMegaman(currentSong);
        currentPattern = 0;
        currentPlaylistIdx = 0;
        setBanner("MEGAMAN LOADED!");
        audition(0, 74);
    }
    ui.drawButton(4, yPos, 152, 11, "1: MEGAMAN RUSH (150)", false, megaHover);
    yPos += 12;

    // 2: Cyber DnB 174
    bool dnbHover = ui.pointInRect(mx, my, 4, yPos, 152, 11);
    if (dnbHover && mClick) {
        song.initDemoDnB(currentSong);
        currentPattern = 0;
        currentPlaylistIdx = 0;
        setBanner("CYBER DNB LOADED!");
        audition(0, 65);
    }
    ui.drawButton(4, yPos, 152, 11, "2: CYBER DNB 174 (AMEN)", false, dnbHover);
    yPos += 12;

    // 3: Retro Quest
    bool questHover = ui.pointInRect(mx, my, 4, yPos, 152, 11);
    if (questHover && mClick) {
        song.initDemoSong(currentSong);
        currentPattern = 0;
        currentPlaylistIdx = 0;
        setBanner("RETRO QUEST LOADED!");
        audition(0, 72);
    }
    ui.drawButton(4, yPos, 152, 11, "3: CHIPTUNE QUEST(132)", false, questHover);
    yPos += 14;

    // --- DISK PERSISTENCE & ACTIONS ---
    ui.drawRect(2, yPos, 156, 1, 0x33); // Divider
    yPos += 3;

    // Save & Load Disk buttons side by side
    bool saveHover = ui.pointInRect(mx, my, 4, yPos, 74, 11);
    if (saveHover && mClick) {
        if (song.saveSongToDisk(currentSong)) {
            setBanner("SAVED TO DISK!");
        } else {
            setBanner("SAVE FAILED!");
        }
    }
    ui.drawButton(4, yPos, 74, 11, "SAVE DISK", false, saveHover);

    bool loadHover = ui.pointInRect(mx, my, 82, yPos, 74, 11);
    if (loadHover && mClick) {
        if (song.loadSongFromDisk(currentSong)) {
            setBanner("LOADED DISK!");
        } else {
            setBanner("NO SAVE FOUND!");
        }
    }
    ui.drawButton(82, yPos, 74, 11, "LOAD DISK", false, loadHover);
    yPos += 13;

    // Clear Pattern button
    bool clrHover = ui.pointInRect(mx, my, 4, yPos, 152, 11);
    if (clrHover && mClick) {
        song.clearPattern(currentSong.patterns[currentPattern]);
        setBanner("PATTERN CLEARED!");
    }
    ui.drawButton(4, yPos, 152, 11, "CLEAR CURRENT PATTERN", false, clrHover);
    yPos += 13;

    // Palette theme switcher
    bool themeHover = ui.pointInRect(mx, my, 4, yPos, 152, 11);
    if (themeHover && mClick) {
        ubyte nextTheme = (cast(ubyte)currentTheme + 1) % 4;
        applyPalette(cast(PaletteTheme)nextTheme);
        setBanner("PALETTE CHANGED!");
    }

    static immutable string[4] themeNames = [
        "THEME: DMG GREEN",
        "THEME: POCKET B&W",
        "THEME: CYBER NEON",
        "THEME: AMBER CRT"
    ];
    ui.drawButton(4, yPos, 152, 11, themeNames[currentTheme], false, themeHover);
}

// Draw notification banner popup
void drawNotificationBanner() @nogc nothrow {
    if (bannerTimer <= 0) return;
    bannerTimer--;

    // Centered banner popup
    ui.drawRect(10, 70, 140, 20, 0x44); // Filled color 4
    ui.drawRect(12, 72, 136, 16, 0x11); // Border / Inner color 1

    int len = 0;
    while (bannerMsg[len] != '\0' && len < 32) len++;
    int tx = 80 - (len * 8) / 2;
    ui.drawCString(bannerMsg.ptr, tx, 76, 0x04);
}

// =============================================================================
// INPUT PROCESSING (GAMEPAD & MOUSE)
// =============================================================================
void handleGamepad() @nogc nothrow {
    ubyte pad = *w4.gamepad1;

    // Up / Down / Left / Right
    int dx = 0, dy = 0;
    if ((pad & w4.buttonUp) && !(prevGamepad & w4.buttonUp)) dy = -1;
    if ((pad & w4.buttonDown) && !(prevGamepad & w4.buttonDown)) dy = 1;
    if ((pad & w4.buttonLeft) && !(prevGamepad & w4.buttonLeft)) dx = -1;
    if ((pad & w4.buttonRight) && !(prevGamepad & w4.buttonRight)) dx = 1;

    // Key repeat logic
    if (pad & (w4.buttonUp | w4.buttonDown | w4.buttonLeft | w4.buttonRight)) {
        if (pad == heldDir) {
            holdTimer++;
            if (holdTimer > 18 && (holdTimer % 5 == 0)) {
                if (pad & w4.buttonUp) dy = -1;
                if (pad & w4.buttonDown) dy = 1;
                if (pad & w4.buttonLeft) dx = -1;
                if (pad & w4.buttonRight) dx = 1;
            }
        } else {
            heldDir = pad;
            holdTimer = 0;
        }
    } else {
        heldDir = 0;
        holdTimer = 0;
    }

    // Apply directional navigation in SEQ tab
    if (currentTab == Tab.Seq) {
        if (dy != 0) {
            cursorStep = (cursorStep + dy + 16) % 16;
            ubyte n = currentSong.patterns[currentPattern].steps[cursorStep][cursorChannel].note;
            audition(cast(ubyte)cursorChannel, n);
        }
        if (dx != 0) {
            cursorChannel = (cursorChannel + dx + 4) % 4;
            ubyte n = currentSong.patterns[currentPattern].steps[cursorStep][cursorChannel].note;
            audition(cast(ubyte)cursorChannel, n);
        }

        // Button 1 (X key): Enter / increment note
        if ((pad & w4.button1) && !(prevGamepad & w4.button1)) {
            modifyCurrentCell(1);
        }

        // Button 2 (Z key): Delete note / toggle play
        if ((pad & w4.button2) && !(prevGamepad & w4.button2)) {
            if (currentSong.patterns[currentPattern].steps[cursorStep][cursorChannel].note > 0) {
                clearCurrentCell();
            } else {
                isPlaying = !isPlaying;
                if (isPlaying) {
                    tickAccumulator = 0;
                    playStepNotes(currentPattern, currentStep);
                }
            }
        }
    } else {
        // In other tabs, button 2 toggles playback
        if ((pad & w4.button2) && !(prevGamepad & w4.button2)) {
            isPlaying = !isPlaying;
            if (isPlaying) {
                tickAccumulator = 0;
                playStepNotes(currentPattern, currentStep);
            }
        }
    }

    prevGamepad = pad;
}

// =============================================================================
// WASM-4 LIFECYCLE
// =============================================================================

extern(C) export void start() {
    // Try to load existing saved song from cartridge disk; if not found, initialize Mega Man demo song!
    if (!song.loadSongFromDisk(currentSong)) {
        song.initDemoMegaman(currentSong);
        setBanner("MEGAMAN RUSH (150 BPM)");
    } else {
        setBanner("LOADED FROM DISK!");
    }

    isPlaying = true; // Auto-play demo chiptune on boot!
    applyPalette(PaletteTheme.DmgGreen);
}

extern(C) export void update() {
    // Read mouse inputs
    int mx = *w4.mouseX;
    int my = *w4.mouseY;
    ubyte mouseBtns = *w4.mouseButtons;
    bool mClick = (mouseBtns & w4.mouseLeft) && !(prevMouse & w4.mouseLeft);
    bool mRight = (mouseBtns & w4.mouseRight) && !(prevMouse & w4.mouseRight);

    // Process inputs
    handleGamepad();

    // Advance playback
    updatePlayback();

    // Clear background
    ui.drawRect(0, 0, 160, 160, 0x11);

    // Draw active tab
    switch (currentTab) {
        case Tab.Seq:
            drawSeqTab(mx, my, mClick, mRight);
            break;
        case Tab.Synth:
            drawSynthTab(mx, my, mClick);
            break;
        case Tab.SongTab:
            drawSongTab(mx, my, mClick);
            break;
        default:
            break;
    }

    // Draw top navigation bar on top
    drawTopBar(mx, my, mClick);

    // Draw notification banner if active
    drawNotificationBanner();

    prevMouse = mouseBtns;
    prevMouseX = cast(short)mx;
    prevMouseY = cast(short)my;
}
