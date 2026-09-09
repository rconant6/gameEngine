const std = @import("std");
const testing = std.testing;
const ui = @import("ui");
const WidgetState = ui.WidgetState;
const TextState = WidgetState.TextState;

fn typeStr(t: *TextState, s: []const u8) !void {
    var it = (try std.unicode.Utf8View.init(s)).iterator();
    while (it.nextCodepoint()) |cp| t.insert(cp);
}

test "TextState: insert ascii advances caret" {
    var t: TextState = .{};
    try typeStr(&t, "abc");
    try testing.expectEqualStrings("abc", t.slice());
    try testing.expectEqual(@as(u8, 3), t.caret);
}

test "TextState: insert 2-byte é then backspace removes both bytes" {
    var t: TextState = .{};
    try typeStr(&t, "aé");
    try testing.expectEqual(@as(u8, 3), t.len);
    t.backspace();
    try testing.expectEqualStrings("a", t.slice());
    try testing.expectEqual(@as(u8, 1), t.caret);
}

test "TextState: moveLeft over 3-byte char lands on its lead byte" {
    var t: TextState = .{};
    try typeStr(&t, "x€"); // € = E2 82 AC
    t.moveLeft();
    try testing.expectEqual(@as(u8, 1), t.caret);
    t.moveRight();
    try testing.expectEqual(@as(u8, 4), t.caret);
}

test "TextState: insert mid-string shifts tail right" {
    var t: TextState = .{};
    try typeStr(&t, "ac");
    t.moveLeft();
    t.insert('b');
    try testing.expectEqualStrings("abc", t.slice());
    try testing.expectEqual(@as(u8, 2), t.caret);
}

test "TextState: delete removes the codepoint after the caret" {
    var t: TextState = .{};
    try typeStr(&t, "aéb");
    t.caret = 1;
    t.delete();
    try testing.expectEqualStrings("ab", t.slice());
    try testing.expectEqual(@as(u8, 1), t.caret);
}

test "TextState: delete at end and backspace at 0 are no-ops" {
    var t: TextState = .{};
    try typeStr(&t, "ab");
    t.delete();
    try testing.expectEqualStrings("ab", t.slice());
    t.caret = 0;
    t.backspace();
    try testing.expectEqualStrings("ab", t.slice());
    try testing.expectEqual(@as(u8, 0), t.caret);
}

test "TextState: insert past capacity drops, buffer unchanged" {
    var t: TextState = .{};
    const full = "a" ** TextState.capacity;
    t.set(full);
    t.insert('z');
    try testing.expectEqual(@as(usize, TextState.capacity), t.slice().len);
    try testing.expectEqualStrings(full, t.slice());
}

test "TextState: set truncates on a codepoint boundary" {
    var t: TextState = .{};
    // 127 ascii + a 2-byte char straddling the 128 limit → the é is dropped whole.
    const s = ("a" ** (TextState.capacity - 1)) ++ "é";
    t.set(s);
    try testing.expectEqual(@as(u8, TextState.capacity - 1), t.len);
    try testing.expectEqual(t.len, t.caret);
}

test "WidgetState.takeChanged: reports once, then clears" {
    var ws: WidgetState = .{ .text = .{} };
    try testing.expect(!ws.takeChanged());
    ws.text.flags |= WidgetState.changed;
    try testing.expect(ws.takeChanged());
    try testing.expect(!ws.takeChanged());

    var flags: WidgetState = .{ .flags = WidgetState.changed | WidgetState.hovered };
    try testing.expect(flags.takeChanged());
    try testing.expectEqual(WidgetState.hovered, flags.flags);
}
