module ui;

import w4 = wasm4;

// Set draw colors helper
void setColors(ushort c) @nogc nothrow {
    *w4.drawColors = c;
}

// Draw a string literal or slice with given drawColors
void drawText(const(char)[] s, int x, int y, ushort colors = 0x04) @nogc nothrow {
    char[64] buf;
    if (s.length == 0 || s.length >= buf.length) return;
    for (size_t i = 0; i < s.length; ++i) {
        buf[i] = s[i];
    }
    buf[s.length] = '\0';
    *w4.drawColors = colors;
    w4.text(buf.ptr, x, y);
}

// Draw null-terminated C string
void drawCString(const(char)* s, int x, int y, ushort colors = 0x04) @nogc nothrow {
    *w4.drawColors = colors;
    w4.text(s, x, y);
}

// Draw an integer number
void drawNumber(int num, int x, int y, ushort colors = 0x04, int minDigits = 1) @nogc nothrow {
    char[16] buf;
    int idx = 15;
    buf[idx] = '\0';

    bool neg = false;
    uint n;
    if (num < 0) {
        neg = true;
        n = cast(uint)(-num);
    } else {
        n = cast(uint)num;
    }

    int digits = 0;
    if (n == 0) {
        idx--;
        buf[idx] = '0';
        digits++;
    } else {
        while (n > 0 && idx > 0) {
            idx--;
            buf[idx] = cast(char)('0' + (n % 10));
            n /= 10;
            digits++;
        }
    }

    while (digits < minDigits && idx > 0) {
        idx--;
        buf[idx] = '0';
        digits++;
    }

    if (neg && idx > 0) {
        idx--;
        buf[idx] = '-';
    }

    *w4.drawColors = colors;
    w4.text(&buf[idx], x, y);
}

// Draw filled rectangle with optional outline
void drawRect(int x, int y, int w, int h, ushort colors) @nogc nothrow {
    *w4.drawColors = colors;
    w4.rect(x, y, cast(uint)w, cast(uint)h);
}

// Check if point (px, py) is inside rect
bool pointInRect(int px, int py, int rx, int ry, int rw, int rh) @nogc nothrow {
    return (px >= rx && px < rx + rw && py >= ry && py < ry + rh);
}

// Draw a stylized button
void drawButton(int x, int y, int w, int h, const(char)[] label, bool active = false, bool selected = false) @nogc nothrow {
    ushort boxCol;
    ushort textCol;

    if (active) {
        boxCol = 0x44;   // Filled with color 4
        textCol = 0x14;  // Text color 1 on 4
    } else if (selected) {
        boxCol = 0x43;   // Fill color 3, border 4
        textCol = 0x13;  // Text color 1 on 3
    } else {
        boxCol = 0x32;   // Fill color 2, border 3
        textCol = 0x04;  // Text color 4
    }

    drawRect(x, y, w, h, boxCol);

    // Center text
    int textLen = cast(int)label.length;
    int textW = textLen * 8;
    int tx = x + (w - textW) / 2;
    int ty = y + (h - 8) / 2;
    if (tx < x + 1) tx = x + 1;
    drawText(label, tx, ty, textCol);
}
