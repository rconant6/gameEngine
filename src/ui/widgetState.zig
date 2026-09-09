const std = @import("std");

/// Internal storage for states of widgets.
/// Widgets declare `pub const state_kind = .flags`, `.value`, `.cursor` or
/// `.text` to indicate which variant they need.
///
/// flags:  bit-maskable boolean states (hovered, pressed, checked, disabled, etc.)
/// value:  continuous state (slider position) + flags for interaction
/// cursor: scroll offset in px (ScrollView) + flags
/// text:   an edit buffer + caret (TextInput) + flags
pub const WidgetState = union(enum) {
    pub const hovered: u16 = 0x1;
    pub const pressed: u16 = 0x2;
    pub const selected: u16 = 0x4;
    pub const dragging: u16 = 0x8;
    pub const focused: u16 = 0x10;
    /// The user committed a new value. The app applies it to its own data and
    /// clears the bit via `takeChanged`.
    pub const changed: u16 = 0x20;

    flags: u16,
    value: struct { val: f16, flags: u16 = 0 },
    cursor: struct {
        offset: f32 = 0, // ScrollView: scroll px
        max_offset: f32 = 0, // written by layout, so input can clamp without re-measuring
        flags: u16 = 0,
    },
    text: TextState,

    /// One pull API for every widget kind: true if the user committed a change
    /// since the last call (and clears it).
    pub fn takeChanged(self: *WidgetState) bool {
        const bits: *u16 = switch (self.*) {
            .flags => |*f| f,
            .value => |*v| &v.flags,
            .cursor => |*c| &c.flags,
            .text => |*t| &t.flags,
        };
        if (bits.* & changed == 0) return false;
        bits.* &= ~changed;
        return true;
    }

    /// Edit buffer for TextInput. Lives in the manager because the widget is
    /// rebuilt from the arena every frame and builders only see const app state.
    /// UTF-8; `caret` is a byte index that always sits on a codepoint boundary.
    pub const TextState = struct {
        pub const capacity = 128;

        buf: [capacity]u8 = undefined, // valid in [0..len)
        len: u8 = 0,
        caret: u8 = 0,
        flags: u16 = 0,

        pub fn slice(self: *const TextState) []const u8 {
            return self.buf[0..self.len];
        }

        /// Replace the contents. Truncates to capacity without splitting a codepoint.
        pub fn set(self: *TextState, s: []const u8) void {
            var n = @min(s.len, capacity);
            while (n > 0 and n < s.len and s[n] & 0xC0 == 0x80) n -= 1;
            @memcpy(self.buf[0..n], s[0..n]);
            self.len = @intCast(n);
            self.caret = @intCast(n);
        }

        /// Insert at the caret. Drops the codepoint if it would overflow.
        pub fn insert(self: *TextState, cp: u21) void {
            var tmp: [4]u8 = undefined;
            const n = std.unicode.utf8Encode(cp, &tmp) catch return;
            const len: usize = self.len;
            const caret: usize = self.caret;
            if (len + n > capacity) return;
            // Overlapping, dest > src → copy from the back.
            std.mem.copyBackwards(u8, self.buf[caret + n .. len + n], self.buf[caret..len]);
            @memcpy(self.buf[caret .. caret + n], tmp[0..n]);
            self.len = @intCast(len + n);
            self.caret = @intCast(caret + n);
        }

        pub fn backspace(self: *TextState) void {
            if (self.caret == 0) return;
            const len: usize = self.len;
            const caret: usize = self.caret;
            const start = self.prevBoundary(caret);
            const w = caret - start;
            std.mem.copyForwards(u8, self.buf[start .. len - w], self.buf[caret..len]);
            self.len = @intCast(len - w);
            self.caret = @intCast(start);
        }

        pub fn delete(self: *TextState) void {
            if (self.caret == self.len) return;
            const len: usize = self.len;
            const caret: usize = self.caret;
            const end = self.nextBoundary(caret);
            const w = end - caret;
            std.mem.copyForwards(u8, self.buf[caret .. len - w], self.buf[end..len]);
            self.len = @intCast(len - w);
        }

        pub fn moveLeft(self: *TextState) void {
            self.caret = @intCast(self.prevBoundary(self.caret));
        }

        pub fn moveRight(self: *TextState) void {
            self.caret = @intCast(self.nextBoundary(self.caret));
        }

        /// Step back over UTF-8 continuation bytes (10xxxxxx).
        fn prevBoundary(self: *const TextState, i: usize) usize {
            if (i == 0) return 0;
            var j = i - 1;
            while (j > 0 and self.buf[j] & 0xC0 == 0x80) j -= 1;
            return j;
        }

        fn nextBoundary(self: *const TextState, i: usize) usize {
            const len: usize = self.len;
            if (i >= len) return len;
            const step = std.unicode.utf8ByteSequenceLength(self.buf[i]) catch 1;
            return @min(len, i + step);
        }
    };
};
