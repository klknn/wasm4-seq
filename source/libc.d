module libc;

extern(C) @nogc nothrow:

export size_t strlen(const(char)* s) {
    size_t len = 0;
    while (s[len] != 0) {
        len++;
    }
    return len;
}

export void* memcpy(void* dest, const void* src, size_t n) {
    ubyte* d = cast(ubyte*)dest;
    const(ubyte)* s = cast(const(ubyte)*)src;
    for (size_t i = 0; i < n; ++i) {
        d[i] = s[i];
    }
    return dest;
}

export void* memset(void* s, int c, size_t n) {
    ubyte* p = cast(ubyte*)s;
    ubyte val = cast(ubyte)c;
    for (size_t i = 0; i < n; ++i) {
        p[i] = val;
    }
    return s;
}
