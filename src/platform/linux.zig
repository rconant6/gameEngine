const std = @import("std");
const Allocator = std.mem.Allocator;
const net = std.Io.net;
const plat = @import("platform.zig");
const wlp = @import("linux/wayland/protocall.zig");
const wli = @import("linux/wayland/interfaces.zig");
const WLDisplay = wli.Display;
const WLRegistry = wli.Registry;
const Event = plat.Event;
const KeyModifiers = plat.KeyModifiers;
const WindowConfig = plat.WindowConfig;
const Capabilities = plat.Capabilities;
const DisplayInfo = plat.DisplayInfo;
const V2I = @import("math").V2I;
const log = @import("debug").log;

// const WaylandState = struct {
// stream: std.Io.net.Stream = undefined, // unix socket id
// send_buf: [4096]u8 = undefined, // outgoing msg buffer
// recv_buf: [65536]u8 = undefined, // incoming msg buffer
// recv_len: usize = 0, // valid bytes in recv_buf

// display_id: u32 = 1, // always 1, set by protocol
// registry_id: u32 = 0, // get from the registry
//     compositor_id: u32 = 0, // from the registry
//     xdg_wm_base_id: u32 = 0, // from the registry
//     seat_id: u32 = 0, // from teh registry
//     keyboard_id: u32 = 0, // created from the seat
//     pointer_id: u32 = 0, // created from the seat
//     ids: wlp.ObjIdAllocator = .{}, // ID counter, starts at 2 (display = 1)
// };

pub const Window = struct {
    surface_id: u32, // wl_surface
    xdg_surface_id: u32, // xdg_surface wrapper
    xdg_toplevel_id: u32, // xdg_toplevel (the actual window)
    configured: bool, // has compositor sent configure+ack?

    width: u32,
    height: u32,
    should_close: bool,

    events: [64]Event,
    event_head: usize,
    event_tail: usize,

    pub fn deinit(self: *Window) void {
        _ = self;
    }

    pub fn shouldClose(self: *const Window) bool {
        return self.should_close;
    }

    pub fn swapBuffers(self: *const Window, offset: u32) void {
        _ = self;
        _ = offset;
    }

    fn pushEvent(self: *Window, event: Event) void {
        self.events[self.event_tail % 64] = event;
        self.event_tail += 1;
    }

    fn popEvent(self: *Window) ?Event {
        if (self.event_head == self.event_tail) return null;
        const event = self.events[self.event_head % 64];
        self.event_head += 1;
        return event;
    }
};

var gpa: Allocator = undefined;
var io: std.Io = undefined;
var stream: std.Io.net.Stream = undefined; // unix socket id
var send_buf = std.mem.zeroes([4096]u8); // outgoing msg buffer
var send_len: usize = 0;
var recv_buf = std.mem.zeroes([65536]u8); // incoming msg buffer
var recv_len: usize = 0; // valid bytes in recv_buf
var display_id: u32 = 1; // always 1, set by protocol
var registry_id: u32 = 0; // get from the registry
var ids: wlp.ObjIdAllocator = .{}; // ID counter, starts at 2 (display = 1)

var write_buf = std.mem.zeroes([4096]u8); // writer buffer
var writer: std.Io.net.Stream.Writer = undefined;
// var out: *std.Io.Writer = undefined;
var read_buf = std.mem.zeroes([65536]u8); // reader buffer
var reader: std.Io.net.Stream.Reader = undefined;

pub fn init(p_gpa: Allocator, p_io: std.Io, env: *std.process.Environ.Map) !void {
    gpa = p_gpa;
    io = p_io;

    const runtime_dir = env.get("XDG_RUNTIME_DIR") orelse return error.NoRuntimeDir;
    const display_name = env.get("WAYLAND_DISPLAY") orelse "wayland-0";
    var path_buf: [108]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ runtime_dir, display_name });
    if (path.len > 108) {
        log.err(.platform, "Wayland socket addr {s} is to long {d}: max 108", .{ path, path.len });
        return error.InvalidWaylandDisplayPath;
    }

    const addr = net.UnixAddress.init(path) catch |e| {
        log.err(.platform, "Unable to open wayland socket at {s}, {any}", .{ path, e });
        return error.WaylandSocketAddressBad;
    };
    stream = addr.connect(io) catch |e| {
        log.err(.platform, "Unable to connect to wayland socke: {any}", .{e});
        return error.WaylandSocketConnectFailed;
    };
    writer = stream.writer(io, &write_buf);
    const out = &writer.interface;
    reader = stream.reader(io, &read_buf);
    const in = &reader.interface;

    registry_id = ids.alloc(); // Protocol gives next available
    send_len = wlp.emit(
        display_id, // 1
        @intFromEnum(WLDisplay.Request.get_registry), // 1
        WLDisplay.Request{ .get_registry = .{ .registry = registry_id } }, // emit extract
        &send_buf, // storage for msg bytes
    );
    std.debug.print("SEND_LEN = {d}\n", .{send_len});

    for (send_buf[0..send_len], 0..) |b, i| {
        if (@mod(i, 4) == 0) std.debug.print("\n", .{});
        std.debug.print("{x:0>2} ", .{b});
    }
    std.debug.print("\n", .{});

    out.writeAll(send_buf[0..send_len]) catch |e| {
        log.err(.platform, "Failed to write to Wayland Socket {any}", .{e});
    };
    out.flush() catch |e| {
        log.err(.platform, "Failed to flush to Wayland Socket {any}", .{e});
    };

    // PLACEHOLDER DRAIN LOOP
    while (true) {
        const header = in.peekStruct(WLHeader, .little) catch |e| blk: {
            log.err(.platform, "Failed to read WaylandHeader {any}", .{e});
            break :blk WLHeader{ .obj_id = 0, .size_opcode = 0 };
        };
        const obj_id = header.obj_id;
        const opcode = header.opcode();
        const size = header.size();

        const msg = try in.peek(size);
        dispatch(obj_id, opcode, msg);
        _ = try in.take(msg.len);
    }
}

fn dispatch(obj_id: u32, opcode: u16, payload: []const u8) void {
    var offset: usize = @sizeOf(WLHeader);

    if (obj_id == 1) {
        switch (opcode) {
            0 => {
                const T = std.meta.fields(WLDisplay.Event)[@intFromEnum(WLDisplay.Event.err)].type;
                const msg = try wlp.parse(T, payload, &offset);
                log.err(.platform, "display error: {any}", .{msg});
            },
            else => {},
        }
    } else if (obj_id == registry_id) {
        switch (opcode) {
            0 => {
                const T = std.meta.fields(WLRegistry.Event)[@intFromEnum(WLRegistry.Event.global)].type;
                const msg = try wlp.parse(T, payload, &offset);
                std.debug.print("{any}\n", .{msg});
            },
            else => log.debug(.platform, "Not implemented: registry_id", .{}),
        }
    } else {
        log.warn(.platform, "dispatch missed", .{});
    }
}

const WLHeader = packed struct {
    obj_id: u32,
    size_opcode: u32,

    pub fn size(h: WLHeader) u16 {
        return @intCast(h.size_opcode >> 16);
    }
    pub fn opcode(h: WLHeader) u16 {
        return @intCast(h.size_opcode & 0xFFFF);
    }
};

pub fn deinit() void {
    stream.close(io);
}

pub fn createWindow(config: WindowConfig) !*Window {
    _ = config;
    return error.NotImplemented;
}

pub fn setPixelBuffer(window: *Window, pixels: []const u8, width: u32, height: u32) void {
    _ = window;
    _ = pixels;
    _ = width;
    _ = height;
}

pub fn swapBuffers(window: *Window, offset: u32) void {
    _ = window;
    _ = offset;
}

pub fn pollNextEvent() ?Event {
    return null;
}

pub fn waitEvent() Event {
    return .NullEvent;
}

pub fn setMouseCursorVisible(window: *Window, visible: bool) void {
    _ = window;
    _ = visible;
}

pub fn setMouseCursorLocked(window: *Window, locked: bool) void {
    _ = window;
    _ = locked;
}

pub fn getTime() f64 {
    return @floatFromInt(std.time.milliTimestamp());
}

pub fn sleep(seconds: f64) void {
    std.time.sleep(@intFromFloat(seconds * std.time.ns_per_s));
}

pub fn getNativeWindowHandle(window: *Window) *anyopaque {
    return window;
}

pub fn getWindowScaleFactor(window: *Window) f32 {
    _ = window;
    return 1.0;
}

pub fn getDisplays(allocator: std.mem.Allocator) ![]DisplayInfo {
    _ = allocator;
    return &.{};
}

pub fn getClipboardText(allocator: std.mem.Allocator) ![]const u8 {
    _ = allocator;
    return error.NotImplemented;
}

pub fn setClipboardText(text: []const u8) !void {
    _ = text;
    return error.NotImplemented;
}

pub fn getCapabilities() Capabilities {
    return .{
        .has_vulkan = true,
        .has_opengl = true,
        .has_metal = false,
        .has_file_dialogs = false,
        .has_clipboard = false,
    };
}
