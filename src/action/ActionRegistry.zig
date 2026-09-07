const std = @import("std");
const math = @import("math");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const act = @import("Action.zig");
const ActionId = act.ActionId;
const ActionRunContext = act.ActionRunContext;
const scene_fmt = @import("scene-format");
const Property = scene_fmt.Property;
const Value = scene_fmt.Value;
const log = @import("debug").log;

// Pointer-typed fn aliases — Entry stores these, makeExecute/makeDecode return
// them, register takes ?DecodeFn. One definition, no drift.
pub const ExecuteFn = *const fn (?*const anyopaque, *ActionRunContext) void;
pub const DecodeFn = *const fn (Allocator, []const Property) anyerror!?*const anyopaque;

pub const ActionRegistry = struct {
    persistent: Allocator,
    entries: ArrayList(Entry),

    pub const Entry = struct {
        name: []const u8, // duped into persistent; registry owns it
        execute: ExecuteFn,
        // decode allocates the param struct into the GAME arena (persistent-playthrough)
        decode: DecodeFn,
    };

    pub fn init(persistent: Allocator) ActionRegistry {
        return .{
            .persistent = persistent,
            .entries = .empty,
        };
    }
    pub fn deinit(self: *ActionRegistry) void {
        for (self.entries.items) |item| self.persistent.free(item.name);
        self.entries.deinit(self.persistent);
    }

    pub fn register(
        self: *ActionRegistry,
        comptime Params: type,
        name: []const u8,
        comptime handler: fn (*ActionRunContext, Params) void,
        comptime decode_fn: ?DecodeFn,
    ) !ActionId {
        if (self.lookup(name) != null) return error.DuplicateActionName;

        const owned = try self.persistent.dupe(u8, name);
        errdefer self.persistent.free(owned);

        const id = self.entries.items.len;
        try self.entries.append(self.persistent, .{
            .name = owned,
            .execute = makeExecute(Params, handler),
            .decode = decode_fn orelse makeDecode(Params),
        });
        return @intCast(id);
    }

    pub fn lookup(self: *const ActionRegistry, name: []const u8) ?ActionId {
        for (self.entries.items, 0..) |entry, idx| {
            if (std.mem.eql(u8, name, entry.name)) return @intCast(idx);
        }
        return null;
    }
    pub fn get(self: *const ActionRegistry, id: ActionId) *const Entry {
        std.debug.assert(id < self.entries.items.len);
        return &self.entries.items[id];
    }
};

fn makeExecute(comptime Params: type, comptime handler: fn (*ActionRunContext, Params) void) ExecuteFn {
    return &struct {
        fn thunk(p: ?*const anyopaque, ctx: *ActionRunContext) void {
            if (@sizeOf(Params) == 0) {
                handler(ctx, Params{}); // ctx is the param; handler/Params closed over from outer
            } else {
                const typed: *const Params = @ptrCast(@alignCast(p.?));
                handler(ctx, typed.*);
            }
        }
    }.thunk;
}
fn makeDecode(comptime Params: type) DecodeFn {
    return &struct {
        // game arrives HERE as a param, when the instantiator calls decode.
        fn thunk(game: Allocator, props: []const Property) anyerror!?*const anyopaque {
            if (@sizeOf(Params) == 0) return null;
            const out = try game.create(Params);
            inline for (@typeInfo(Params).@"struct".fields) |field| {
                if (getProperty(props, field.name)) |prop| {
                    @field(out.*, field.name) = try decodeValue(field.type, game, prop.value);
                } else if (field.defaultValue()) |default| {
                    @field(out.*, field.name) = default;
                } else {
                    return error.MissingActionParam;
                }
            }
            return out;
        }
    }.thunk;
}

fn getProperty(props: []const Property, property: []const u8) ?Property {
    for (props) |prop| {
        if (std.mem.eql(u8, prop.name, property)) return prop;
    }

    return null;
}

fn decodeValue(
    comptime T: type,
    game: Allocator,
    value: Value,
) !T {
    switch (@typeInfo(T)) {
        .float => {
            // T is f32 or f64
            return switch (value) {
                .number => |n| @floatCast(n),
                else => error.ActionFloatTypeMismatch,
            };
        },
        .int => {
            // T is i32, u8, u32...
            return switch (value) {
                .number => |n| @intFromFloat(n),
                else => error.ActionIntTypeMismatch,
            };
        },
        .bool => {
            return switch (value) {
                .boolean => |b| b,
                else => error.ActionBoolTypeMismatch,
            };
        },
        .pointer => |ptr_info| {
            // For []const u8 (strings)
            if (ptr_info.size == .slice and ptr_info.child == u8) {
                return switch (value) {
                    .string => |s| try game.dupe(u8, s),
                    else => error.ActionStringTypeMismatch,
                };
            }
            @compileError("unsupported pointer param type: " ++ @typeName(T));
        },
        .@"struct" => {
            if (T == math.V2) {
                return switch (value) {
                    .vector => |v| if (v.len < 2)
                        error.ActionV2TooFewComponents
                    else
                        math.V2{
                            .x = @floatCast(v[0]),
                            .y = @floatCast(v[1]),
                        },
                    else => error.ActionV2TypeMismatch,
                };
            }
            @compileError("unsupported struct param type: " ++ @typeName(T));
        },
        .@"enum" => {
            return switch (value) {
                .string => |s| std.meta.stringToEnum(T, s) orelse error.ActionEnumValueInvalid,
                else => error.ActionEnumTypeMismatch,
            };
        },
        else => {
            @compileError("unsupported param type: " ++ @typeName(T));
        },
    }
}
