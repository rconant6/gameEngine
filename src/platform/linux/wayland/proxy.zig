const std = @import("std");
const c = @import("c.zig").c;
const wl = @import("wl.zig");

pub fn Proxy(comptime T: type) type {
    return struct {
        const Self = @This();
        ptr: *anyopaque,
        handler: *const fn (T.Event, *anyopaque) anyerror!void,
        ctx: *anyopaque,

        pub fn listen(self: *Self) void {
            _ = c.wl_proxy_add_dispatcher(@ptrCast(self.ptr), dispatch, self, null);
        }
        fn dispatch(
            user_data: ?*const anyopaque,
            target: ?*anyopaque,
            opcode: u32,
            msg: [*c]const c.wl_message,
            args: [*c]c.wl_argument,
        ) callconv(.c) c_int {
            _ = target;
            _ = msg;

            const self: *const Self = @ptrCast(@alignCast(user_data orelse return -1));
            const event = buildEvent(T.Event, opcode, args) catch return -1;
            self.handler(event, self.ctx) catch return -1;

            return 0;
        }

        fn buildEvent(comptime EventUnion: type, opcode: u32, args: [*c]c.wl_argument) !EventUnion {
            inline for (std.meta.fields(EventUnion), 0..) |field, i| {
                if (opcode == i) {
                    var payload: field.type = undefined;
                    inline for (std.meta.fields(field.type), 0..) |arg_field, j| {
                        @field(payload, arg_field.name) = unpackArg(arg_field.type, args[j]);
                    }
                    return @unionInit(EventUnion, field.name, payload);
                }
            }
            return error.UnknownOpcode;
        }
    };
}

fn unpackArg(comptime ArgType: type, arg: c.wl_argument) ArgType {
    return switch (ArgType) {
        u32 => arg.u,
        i32 => arg.i,
        []const u8 => std.mem.span(arg.s),
        wl.WlFixed => @bitCast(arg.f),
        wl.WlArray => .{
            .len = @intCast(arg.a.*.size),
            .data = @as([*]const u8, @ptrCast(arg.a.*.data.?))[0..arg.a.*.size],
        },
        wl.WlObjectId => .{ .ptr = @ptrCast(arg.o.?) },
        void => {},
        else => @compileError("Unhandled Wayland argument type: " ++ @typeName(ArgType)),
    };
}
