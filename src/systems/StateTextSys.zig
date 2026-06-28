const std = @import("std");
const ecs = @import("ecs");
const World = ecs.World;
const StateText = ecs.StateText;
const Text = ecs.Text;
const gsm = @import("game_state");
const GameStateManager = gsm.GameStateManager;

pub fn run(world: *World, states: *GameStateManager) void {
    var query = world.query(.{ StateText, Text });
    while (query.next()) |entry| {
        const st = entry.get(0);
        const text = entry.get(1);
        const val = states.getStateVar(st.key) orelse continue;

        // Format "<prefix><value>" into the component's OWN buffer, truncating
        // to fit rather than failing — a HUD label is better short than blank.
        // The value's format spec is chosen per StateValue variant (a plain
        // "{any}" would print the union's debug form, e.g. "StateValue{ .int = 7 }").
        var len: usize = appendStr(&st.buf, 0, st.prefix);
        len = switch (val) {
            .int => |v| appendFmt(&st.buf, len, "{d}", .{v}),
            .float => |v| appendFmt(&st.buf, len, "{d:.1}", .{v}),
            .bool => |v| appendFmt(&st.buf, len, "{}", .{v}),
            .string => |v| appendStr(&st.buf, len, v),
        };

        // Re-point text at our own buffer. If the instantiator handed this Text a
        // duped (owned) string, free it once and drop the flag — from now on
        // text.text lives in st.buf (not heap), so Text.deinit must not free it.
        if (text.text_owned) {
            world.persistent.free(text.text);
            text.text_owned = false;
        }
        st.len = len;
        text.text = st.buf[0..st.len]; // points INTO the owned buffer (load-bearing)
    }
}

// Copy as much of `s` as fits after `start`; return the new end index. Never
// overruns `buf` — silently truncates when full.
fn appendStr(buf: []u8, start: usize, s: []const u8) usize {
    const room = buf.len - start;
    const n = @min(room, s.len);
    @memcpy(buf[start .. start + n], s[0..n]);
    return start + n;
}

// Format into the tail of `buf` after `start`; truncate on overflow. bufPrint
// gives no partial result on NoSpaceLeft, so the value is rendered into a small
// stack scratch first, then copied in via appendStr (which truncates for us).
fn appendFmt(
    buf: []u8,
    start: usize,
    comptime fmt: []const u8,
    args: anytype,
) usize {
    var scratch: [64]u8 = undefined;
    const rendered = std.fmt.bufPrint(&scratch, fmt, args) catch &scratch; // worst case: full scratch

    return appendStr(buf, start, rendered);
}
