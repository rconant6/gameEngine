//! Phase 3G — ActionRegistry tests (handle model).
//!
//! Action is plain data { id, params, priority } — no execute/free pointers,
//! no Action.deinit. Behavior resolves through the registry by id. Decoded
//! params live in the GAME arena (caller-owned, reclaimed wholesale), so these
//! tests decode into a local ArenaAllocator and free via arena.deinit —
//! there is no per-param free thunk.
//!
//! register(Params, name, handler, decode_fn): decode_fn null → generated.

const std = @import("std");
const testing = std.testing;

const Action = @import("Action");
const ActionRegistry = Action.ActionRegistry;
const ActionRunContext = Action.ActionRunContext;

const ecs = @import("ecs");
const World = ecs.World;
const Entity = ecs.Entity;

const math = @import("math");
const V2 = math.V2;

const scene_fmt = @import("scene-format");
const Property = scene_fmt.Property;
const Value = scene_fmt.Value;

// MARK: fixture helpers

fn prop(name: []const u8, base: scene_fmt.BaseType, value: Value) Property {
    return .{
        .name = name,
        .type_annotation = .{ .base_type = base, .is_array = false },
        .value = value,
        .location = .{ .line = 0, .col = 0, .len = 0 }, // type inferred from Property.location
    };
}

// One of every v1-supported field type + defaults.
const SampleParams = struct {
    flag: bool = false,
    count: i32 = 7, // default exercised when omitted
    speed: f32,
    label: []const u8, // string → duped into the game arena by decode
    dir: V2,
};

var captured: ?SampleParams = null;
fn sampleHandler(ctx: *ActionRunContext, p: SampleParams) void {
    _ = ctx;
    captured = p;
}

const EmptyParams = struct {};
var empty_ran: bool = false;
fn emptyHandler(ctx: *ActionRunContext, p: EmptyParams) void {
    _ = ctx;
    _ = p;
    empty_ran = true;
}

// MARK: register / lookup

test "register then lookup returns the id; unknown name is null" {
    var reg = ActionRegistry.init(testing.allocator);
    defer reg.deinit();

    const id = try reg.register(SampleParams, "sample", sampleHandler, null);
    try testing.expectEqual(id, reg.lookup("sample").?);
    try testing.expect(reg.lookup("does_not_exist") == null);
}

test "id is the index: first register is 0, second is 1" {
    var reg = ActionRegistry.init(testing.allocator);
    defer reg.deinit();

    const a = try reg.register(EmptyParams, "a", emptyHandler, null);
    const b = try reg.register(EmptyParams, "b", emptyHandler, null);
    try testing.expectEqual(@as(Action.ActionId, 0), a);
    try testing.expectEqual(@as(Action.ActionId, 1), b);
}

test "registering a duplicate name is an error" {
    var reg = ActionRegistry.init(testing.allocator);
    defer reg.deinit();

    _ = try reg.register(SampleParams, "dup", sampleHandler, null);
    try testing.expectError(
        error.DuplicateActionName,
        reg.register(SampleParams, "dup", sampleHandler, null),
    );
}

test "register dupes the name (caller's buffer can change)" {
    var reg = ActionRegistry.init(testing.allocator);
    defer reg.deinit();

    var name_buf: [8]u8 = undefined;
    @memcpy(name_buf[0..4], "jump");
    const id = try reg.register(EmptyParams, name_buf[0..4], emptyHandler, null);

    name_buf[0] = 'X';
    try testing.expectEqual(id, reg.lookup("jump").?);
}

// MARK: decode

test "decode fills provided values and falls back to field defaults" {
    var reg = ActionRegistry.init(testing.allocator);
    defer reg.deinit();
    const id = try reg.register(SampleParams, "sample", sampleHandler, null);
    const entry = reg.get(id);

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const game = arena.allocator();

    // omit `count` (default 7) and `flag` (default false); supply the rest
    const props = [_]Property{
        prop("speed", .f32, .{ .number = 2.5 }),
        prop("label", .string, .{ .string = "hi" }),
        prop("dir", .vec2, .{ .vector = @constCast(&[_]f64{ 1.0, -1.0 }) }),
    };

    const params_ptr = (try entry.decode(game, &props)).?;
    const p: *const SampleParams = @ptrCast(@alignCast(params_ptr));

    try testing.expectEqual(@as(i32, 7), p.count); // default
    try testing.expect(!p.flag); // default
    try testing.expectApproxEqAbs(@as(f32, 2.5), p.speed, 0.0001);
    try testing.expectEqualStrings("hi", p.label);
    try testing.expectApproxEqAbs(@as(f32, 1.0), p.dir.x, 0.0001);
    try testing.expectApproxEqAbs(@as(f32, -1.0), p.dir.y, 0.0001);
}

test "decode errors when a required (defaultless) param is missing" {
    var reg = ActionRegistry.init(testing.allocator);
    defer reg.deinit();
    const id = try reg.register(SampleParams, "sample", sampleHandler, null);
    const entry = reg.get(id);

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    // omit `speed`, which has no default
    const props = [_]Property{
        prop("label", .string, .{ .string = "hi" }),
        prop("dir", .vec2, .{ .vector = @constCast(&[_]f64{ 0.0, 0.0 }) }),
    };

    try testing.expectError(error.MissingActionParam, entry.decode(arena.allocator(), &props));
}

test "decode dupes string params into the game arena (survives source mutation)" {
    var reg = ActionRegistry.init(testing.allocator);
    defer reg.deinit();
    const id = try reg.register(SampleParams, "sample", sampleHandler, null);
    const entry = reg.get(id);

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit(); // owns the duped string; no per-param free exists

    var label_buf: [8]u8 = undefined;
    @memcpy(label_buf[0..5], "alpha");
    const props = [_]Property{
        prop("speed", .f32, .{ .number = 1.0 }),
        prop("label", .string, .{ .string = label_buf[0..5] }),
        prop("dir", .vec2, .{ .vector = @constCast(&[_]f64{ 0.0, 0.0 }) }),
    };

    const params_ptr = (try entry.decode(arena.allocator(), &props)).?;

    @memset(label_buf[0..5], 'X'); // corrupt the source; decode must own a copy
    const p: *const SampleParams = @ptrCast(@alignCast(params_ptr));
    try testing.expectEqualStrings("alpha", p.label);
}

test "zero-size Params decodes to null params" {
    var reg = ActionRegistry.init(testing.allocator);
    defer reg.deinit();
    const id = try reg.register(EmptyParams, "noop", emptyHandler, null);
    const entry = reg.get(id);

    const params_ptr = try entry.decode(testing.allocator, &[_]Property{});
    try testing.expect(params_ptr == null);
}

// MARK: execute (resolve behavior by id through the registry)

test "execute thunk hands decoded values to the typed handler" {
    var reg = ActionRegistry.init(testing.allocator);
    defer reg.deinit();
    const id = try reg.register(SampleParams, "sample", sampleHandler, null);
    const entry = reg.get(id);

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const props = [_]Property{
        prop("flag", .bool, .{ .boolean = true }),
        prop("count", .i32, .{ .number = 42 }),
        prop("speed", .f32, .{ .number = 9.5 }),
        prop("label", .string, .{ .string = "go" }),
        prop("dir", .vec2, .{ .vector = @constCast(&[_]f64{ 3.0, 4.0 }) }),
    };
    const params_ptr = (try entry.decode(arena.allocator(), &props)).?;

    var world = try World.init(testing.allocator);
    defer world.deinit();
    const e = try world.createEntity();
    var run_ctx = makeRunCtx(&world, e);

    captured = null;
    entry.execute(params_ptr, &run_ctx);

    const c = captured orelse return error.HandlerNeverRan;
    try testing.expect(c.flag);
    try testing.expectEqual(@as(i32, 42), c.count);
    try testing.expectApproxEqAbs(@as(f32, 9.5), c.speed, 0.0001);
    try testing.expectEqualStrings("go", c.label);
    try testing.expectApproxEqAbs(@as(f32, 3.0), c.dir.x, 0.0001);
}

test "execute thunk runs a zero-size-param handler with null params" {
    var reg = ActionRegistry.init(testing.allocator);
    defer reg.deinit();
    const id = try reg.register(EmptyParams, "noop", emptyHandler, null);
    const entry = reg.get(id);

    var world = try World.init(testing.allocator);
    defer world.deinit();
    const e = try world.createEntity();
    var run_ctx = makeRunCtx(&world, e);

    empty_ran = false;
    entry.execute(null, &run_ctx);
    try testing.expect(empty_ran);
}

// MARK: custom decode (the registerRaw replacement — pass a decode_fn)

var custom_decoded: bool = false;
const CustomParams = struct { n: i32 };

fn customDecode(game: std.mem.Allocator, props: []const Property) anyerror!?*const anyopaque {
    _ = props;
    custom_decoded = true;
    const out = try game.create(CustomParams);
    out.* = .{ .n = 99 }; // ignores props, proves the custom path ran
    return out;
}
var custom_seen: i32 = 0;
fn customHandler(ctx: *ActionRunContext, p: CustomParams) void {
    _ = ctx;
    custom_seen = p.n;
}

test "register with a custom decode_fn uses it instead of the generated one" {
    var reg = ActionRegistry.init(testing.allocator);
    defer reg.deinit();

    const id = try reg.register(CustomParams, "custom", customHandler, customDecode);
    try testing.expectEqual(id, reg.lookup("custom").?);
    const entry = reg.get(id);

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    custom_decoded = false;
    const params_ptr = (try entry.decode(arena.allocator(), &[_]Property{})).?;
    try testing.expect(custom_decoded); // custom path ran

    var world = try World.init(testing.allocator);
    defer world.deinit();
    const e = try world.createEntity();
    var run_ctx = makeRunCtx(&world, e);

    custom_seen = 0;
    entry.execute(params_ptr, &run_ctx);
    try testing.expectEqual(@as(i32, 99), custom_seen); // decoded value flowed through
}

// MARK: helper

fn makeRunCtx(world: *World, self: Entity) ActionRunContext {
    return .{
        .world = world,
        .services = undefined, // not touched by these handlers
        .self_ent = self,
    };
}
