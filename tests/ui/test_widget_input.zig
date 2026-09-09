//! Headless interaction tests: build → setRoot → layoutAt → processInput,
//! exactly the per-frame sequence UILayer runs, with synthetic UIInput.
//! No renderer — layout and input never touch it.
const std = @import("std");
const testing = std.testing;
const ui = @import("ui");
const make = ui.make;
const UIManager = ui.UIManager;
const UIInput = ui.UIInput;
const WidgetNode = ui.WidgetNode;
const WidgetState = ui.WidgetState;

const BuildFn = *const fn (std.mem.Allocator) *WidgetNode;

fn frame(mgr: *UIManager, build: BuildFn, in: UIInput) void {
    mgr.rebuild();
    mgr.setRoot(build(mgr.allocator()));
    mgr.layoutAt(0, 0, 300, 120);
    mgr.processInput(in);
}

fn click(x: f32, y: f32) [2]UIInput {
    return .{
        .{ .mouse_x = x, .mouse_y = y, .left_down = true },
        .{ .mouse_x = x, .mouse_y = y, .left_up = true },
    };
}

fn withKey(k: ui.UIKeyCode) UIInput {
    var in: UIInput = .{};
    in.key_buf[0] = k;
    in.key_len = 1;
    return in;
}

// ── ScrollView ─────────────────────────────────────────────

fn buildRows(a: std.mem.Allocator) *WidgetNode {
    var rows: [20]*WidgetNode = undefined;
    for (&rows, 0..) |*r, i| {
        const id = std.fmt.allocPrint(a, "row{d}", .{i}) catch unreachable;
        r.* = make.checkbox(a, id, "", false, .{ .box_size = 20 });
    }
    return make.scrollView(a, "sv", make.vstack(a, &rows, .{ .spacing = 0 }), .{});
}

fn firstRowY(mgr: *UIManager) f32 {
    const sv = mgr.root.?.widget.ScrollView;
    return sv.child.widget.VStack.childs[0].bounds.y;
}

test "ScrollView: wheel offset reaches the next frame's layout" {
    var mgr = UIManager.init(testing.allocator);
    defer mgr.deinit();

    frame(&mgr, buildRows, .{});
    try testing.expectEqual(@as(f32, 0), firstRowY(&mgr));

    // One notch down (negative delta) → offset += scroll_speed (30).
    frame(&mgr, buildRows, .{ .mouse_x = 10, .mouse_y = 10, .scroll_delta = -1 });
    frame(&mgr, buildRows, .{});
    try testing.expectEqual(@as(f32, -30), firstRowY(&mgr));
}

test "ScrollView: offset clamps at content end" {
    var mgr = UIManager.init(testing.allocator);
    defer mgr.deinit();

    // 20 rows × 20px = 400 content, 120 viewport → max scroll 280.
    for (0..5) |_| frame(&mgr, buildRows, .{ .mouse_x = 10, .mouse_y = 10, .scroll_delta = -10 });
    frame(&mgr, buildRows, .{});
    try testing.expectEqual(@as(f32, -280), firstRowY(&mgr));
}

test "ScrollView: clicks outside the viewport don't reach scrolled-away rows" {
    var mgr = UIManager.init(testing.allocator);
    defer mgr.deinit();

    frame(&mgr, buildRows, .{ .mouse_x = 10, .mouse_y = 10, .scroll_delta = -2 }); // offset 60
    frame(&mgr, buildRows, .{});
    // row0 now sits at y = -60..-40 — above the viewport. Click it.
    const c = click(10, -50);
    frame(&mgr, buildRows, c[0]);
    frame(&mgr, buildRows, c[1]);
    try testing.expect(!mgr.getState("row0").?.takeChanged());

    // A visible row (row3 at y 0..20) still takes the click.
    const v = click(10, 10);
    frame(&mgr, buildRows, v[0]);
    frame(&mgr, buildRows, v[1]);
    try testing.expect(mgr.getState("row3").?.takeChanged());
}

// ── Checkbox ───────────────────────────────────────────────

fn buildCheckbox(a: std.mem.Allocator) *WidgetNode {
    return make.checkbox(a, "cb", "", false, .{ .box_size = 20 });
}

test "Checkbox: press+release inside reports changed once" {
    var mgr = UIManager.init(testing.allocator);
    defer mgr.deinit();

    const c = click(10, 10);
    frame(&mgr, buildCheckbox, c[0]);
    frame(&mgr, buildCheckbox, c[1]);
    const ws = mgr.getState("cb").?;
    try testing.expect(ws.takeChanged());
    try testing.expect(!ws.takeChanged());
}

test "Checkbox: press inside, release outside does not toggle" {
    var mgr = UIManager.init(testing.allocator);
    defer mgr.deinit();

    frame(&mgr, buildCheckbox, .{ .mouse_x = 10, .mouse_y = 10, .left_down = true });
    frame(&mgr, buildCheckbox, .{ .mouse_x = 200, .mouse_y = 100, .left_up = true });
    try testing.expect(!mgr.getState("cb").?.takeChanged());
}

// ── TextInput ──────────────────────────────────────────────

fn buildFields(a: std.mem.Allocator) *WidgetNode {
    return make.vstack(a, &.{
        make.textInput(a, "ta", "ab", .{}),
        make.textInput(a, "tb", "xy", .{}),
    }, .{ .spacing = 0 });
}

fn fieldA(mgr: *UIManager) *WidgetState.TextState {
    return &mgr.getState("ta").?.text;
}

fn focusA(mgr: *UIManager) void {
    const c = click(5, 5);
    frame(mgr, buildFields, c[0]);
    frame(mgr, buildFields, c[1]);
}

test "TextInput: unfocused field mirrors the app value" {
    var mgr = UIManager.init(testing.allocator);
    defer mgr.deinit();

    frame(&mgr, buildFields, .{});
    try testing.expectEqualStrings("ab", fieldA(&mgr).slice());
    try testing.expect(!mgr.wantsKeyboard());
}

test "TextInput: click focuses, typing edits, Enter commits" {
    var mgr = UIManager.init(testing.allocator);
    defer mgr.deinit();

    focusA(&mgr);
    try testing.expect(mgr.wantsKeyboard());

    frame(&mgr, buildFields, .{ .text = &.{ 'c', 'd' } });
    try testing.expectEqualStrings("abcd", fieldA(&mgr).slice());
    frame(&mgr, buildFields, withKey(.backspace));
    try testing.expectEqualStrings("abc", fieldA(&mgr).slice());

    frame(&mgr, buildFields, withKey(.enter));
    try testing.expect(!mgr.wantsKeyboard());
    const ws = mgr.getState("ta").?;
    try testing.expectEqualStrings("abc", ws.text.slice()); // readable before the next layout
    try testing.expect(ws.takeChanged());
}

test "TextInput: Esc reverts to the app value without changed" {
    var mgr = UIManager.init(testing.allocator);
    defer mgr.deinit();

    focusA(&mgr);
    frame(&mgr, buildFields, .{ .text = &.{'z'} });
    frame(&mgr, buildFields, withKey(.escape));
    try testing.expect(!mgr.getState("ta").?.takeChanged());
    frame(&mgr, buildFields, .{}); // next layout reseeds
    try testing.expectEqualStrings("ab", fieldA(&mgr).slice());
}

test "TextInput: clicking another field blurs (commits) the first; one focus" {
    var mgr = UIManager.init(testing.allocator);
    defer mgr.deinit();

    focusA(&mgr);
    frame(&mgr, buildFields, .{ .text = &.{'!'} });

    // Field B sits directly below A; A's height is line + 2*padding.
    const b_y = mgr.root.?.widget.VStack.childs[1].bounds.y + 2;
    const c = click(5, b_y);
    frame(&mgr, buildFields, c[0]);

    // Pull in the same frame as the blur — the next layout reseeds A from its
    // app value, exactly as the editor's flushInspector expects.
    const a = mgr.getState("ta").?;
    try testing.expectEqualStrings("ab!", a.text.slice());
    try testing.expect(a.takeChanged());
    frame(&mgr, buildFields, c[1]);
    try testing.expect(a.text.flags & WidgetState.focused == 0);
    try testing.expect(mgr.getState("tb").?.text.flags & WidgetState.focused != 0);
}

test "TextInput: keys and text are ignored when unfocused" {
    var mgr = UIManager.init(testing.allocator);
    defer mgr.deinit();

    frame(&mgr, buildFields, .{ .text = &.{'q'} });
    frame(&mgr, buildFields, withKey(.backspace));
    try testing.expectEqualStrings("ab", fieldA(&mgr).slice());
}

// ── UIInput.fromDevices ────────────────────────────────────

test "UIInput.fromDevices maps keys structurally" {
    const Key = enum { A, Backspace, Delete, Left, Right, Enter, Esc, Tab };
    const Btn = enum { Left, Right };
    const Kb = struct {
        down: []const Key,
        pub fn isPressed(self: @This(), k: Key) bool {
            return std.mem.indexOfScalar(Key, self.down, k) != null;
        }
    };
    const Buttons = struct {
        pub fn isPressed(_: @This(), b: Btn) bool {
            return b == .Left;
        }
        pub fn isReleased(_: @This(), _: Btn) bool {
            return false;
        }
    };
    const Mouse = struct {
        position: struct { x: f32, y: f32 } = .{ .x = 3, .y = 4 },
        buttons: Buttons = .{},
        scroll_delta: struct { x: f32 = 0, y: f32 = -2 } = .{},
    };

    const in = UIInput.fromDevices(Mouse{}, Kb{ .down = &.{ .A, .Enter, .Backspace } }, &.{'x'});
    try testing.expectEqual(@as(f32, 3), in.mouse_x);
    try testing.expect(in.left_down);
    try testing.expectEqual(@as(f32, -2), in.scroll_delta);
    try testing.expectEqualSlices(ui.UIKeyCode, &.{ .backspace, .enter }, in.keys());
    try testing.expectEqual(@as(usize, 1), in.text.len);
}
