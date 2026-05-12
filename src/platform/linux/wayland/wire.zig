const std = @import("std");
const Allocator = std.mem.Allocator;
const log = @import("debug").log;
const wire = @import("interfaces.zig");
const WlFixed = wire.WlFixed;
const WlArray = wire.WlArray;

pub const Header = packed struct {
    obj_id: u32,
    size_opcode: u32,

    pub fn size(h: Header) u16 {
        return @intCast(h.size_opcode >> 16);
    }
    pub fn opcode(h: Header) u16 {
        return @intCast(h.size_opcode & 0xFFFF);
    }
};

pub const Message = struct {
    header: Header,
    bytes: []const u8,
};

// OBJ_ID who i'm sending it to
// opcode - what i'm sending
// val - payload
// buf - storage for bytes
fn emit(obj_id: u32, opcode: u16, msg: anytype, buf: []u8) usize {
    var offset: usize = 0;

    std.mem.writeInt(u32, buf[0..][0..4], obj_id, .little);
    offset += 4;
    offset += 4; // fill in opcode and size after we calculate it

    inline for (@typeInfo(@TypeOf(msg)).@"union".fields, 0..) |u_field, idx| {
        if (@intFromEnum(std.meta.activeTag(msg)) == idx) {
            const payload = @field(msg, u_field.name);
            inline for (@typeInfo(@TypeOf(payload)).@"struct".fields) |field| {
                const value = @field(payload, field.name);
                switch (@TypeOf(value)) {
                    u32 => {
                        std.mem.writeInt(u32, buf[offset..][0..4], value, .little);
                        offset += 4;
                    },
                    i32 => {
                        std.mem.writeInt(i32, buf[offset..][0..4], value, .little);
                        offset += 4;
                    },
                    WlFixed => {
                        std.mem.writeInt(u32, buf[offset..][0..4], @bitCast(value), .little);
                        offset += 4;
                    },
                    WlArray => {
                        // BUG: probably not right for now
                        const len: u32 = @intCast(value.len + 1);
                        std.mem.writeInt(u32, buf[offset..][0..4], len, .little);
                        offset += 4;
                        @memcpy(buf[offset..][0..value.len], value);
                        offset += value.len;
                        buf[offset] = 0;
                        offset += 1;
                        const pad = wlPad(len);
                        @memset(buf[offset..][0..pad], 0);
                        offset += pad;
                    },
                    []const u8 => {
                        const len: u32 = @intCast(value.len + 1);
                        std.mem.writeInt(u32, buf[offset..][0..4], len, .little);
                        offset += 4;
                        @memcpy(buf[offset..][0..value.len], value);
                        offset += value.len;
                        buf[offset] = 0;
                        offset += 1;
                        const pad = wlPad(len);
                        @memset(buf[offset..][0..pad], 0);
                        offset += pad;
                    },
                    else => @compileError("emit: unsupported field type " ++ @typeName(@TypeOf(value))),
                }
            }
        }
    }

    const opcode_size: u32 = (@as(u32, @intCast(offset)) << 16 | @as(u32, opcode));
    std.mem.writeInt(u32, buf[4..8], opcode_size, .little);

    return offset;
}

fn parse(comptime T: type, data: []const u8) !T {
    var result: T = undefined;
    var offset: usize = @sizeOf(Header);

    inline for (@typeInfo(T).@"struct".fields) |field| {
        switch (field.type) {
            u32 => {
                @field(result, field.name) = std.mem.readInt(
                    u32,
                    data[offset..][0..4],
                    .little,
                );
                offset += 4;
            },
            i32 => {
                @field(result, field.name) = std.mem.readInt(
                    i32,
                    data[offset..][0..4],
                    .little,
                );
                offset += 4;
            },
            WlFixed => {
                const bits = std.mem.readInt(
                    u32,
                    data[offset..][0..4],
                    .little,
                );
                offset += 4;
                @field(result, field.name) = WlFixed.fromF32(bits);
            },
            WlArray => {
                const len = std.mem.readInt(
                    u32,
                    data[offset..][0..4],
                    .little,
                );
                offset += 4;
                @field(result, field.name) = WlArray{
                    .len = len,
                    .data = data[offset..][4 .. 4 + len],
                };
                offset += len;
                const pad = wlPad(len);
                offset += pad;
            },
            []const u8 => {
                const len = std.mem.readInt(
                    u32,
                    data[offset..][0..4],
                    .little,
                ); // get size
                offset += 4;

                @field(result, field.name) = data[offset..][0 .. len - 1];
                offset += len; // str_len
                const pad = wlPad(offset);
                offset += pad; // offset to nearest 4
            },
            void => {},
            else => @compileError("parse: unsupported field type " ++ @typeName(field.type)),
        }
    }

    return result;
}

pub fn parseEvent(
    comptime EventUnion: type,
    opcode: u16,
    data: []const u8,
) !EventUnion {
    inline for (@typeInfo(EventUnion).@"union".fields, 0..) |field, i| {
        if (i == opcode) {
            const inner = try parse(field.type, data);
            return @unionInit(EventUnion, field.name, inner);
        }
    }

    return error.UnknownOpcode;
}

pub fn Proxy(comptime Iface: type) type {
    return struct {
        obj_id: u32,
        conn: *Connection,
        on_event: *const fn (event: Iface.Event) anyerror!void,

        pub const Self = @This();
        pub const Interface = Iface;

        pub fn send(self: Self, msg: Iface.Request) !void {
            try self.conn.sendRaw(self.obj_id, msg);
        }
        pub fn handle(self: Self, opcode: u16, bytes: []const u8) !void {
            const event = try parseEvent(Iface.Event, opcode, bytes);
            try self.on_event(event);
        }
    };
}

pub const ObjIdAllocator = struct {
    next: u32 = 2,

    pub fn alloc(self: *ObjIdAllocator) u32 {
        const id = self.next;
        self.next += 1;
        return id;
    }
};

inline fn wlPad(len: usize) usize {
    return (4 - @mod(len, 4)) % 4;
}
inline fn wlAlign(len: usize, lim: u32) usize {
    return (lim - @mod(len, lim)) % lim;
}

pub const Connection = struct {
    gpa: Allocator,
    io: std.Io,
    stream: std.Io.net.Stream, // unix socket id

    send_buf: [4096]u8, // outgoing msg buffer
    write_stage: [4096]u8, // writer buffer
    read_buf: [65536]u8, // reader buffer
    writer: std.Io.net.Stream.Writer,
    reader: std.Io.net.Stream.Reader,

    ids: ObjIdAllocator, // ID counter, starts at 2 (display = 1)
    handlers: std.AutoHashMap(u32, Handler),

    const Handler = struct {
        ctx: *anyopaque,
        handle_fn: *const fn (
            ctx: *anyopaque,
            opcode: u16,
            bytes: []const u8,
        ) anyerror!void,
    };

    pub fn init(
        gpa: Allocator,
        io: std.Io,
        env: *std.process.Environ.Map,
    ) !*Connection {
        const socket = try gpa.create(Connection);

        const runtime_dir = env.get("XDG_RUNTIME_DIR") orelse return error.NoRuntimeDir;
        const display_name = env.get("WAYLAND_DISPLAY") orelse "wayland-0";
        var path_buf: [108]u8 = undefined; // 108 is value in stdlib
        const path = try std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ runtime_dir, display_name });
        if (path.len > 108) {
            log.err(.platform, "Wayland socket addr {s} is to long {d}: max 108", .{ path, path.len });
            return error.InvalidWaylandDisplayPath;
        }
        const addr = std.Io.net.UnixAddress.init(path) catch |e| {
            log.err(.platform, "Unable to open wayland socket at {s}, {any}", .{ path, e });
            return error.WaylandSocketAddressBad;
        };

        socket.gpa = gpa;
        socket.io = io;
        socket.stream = addr.connect(io) catch |e| {
            log.err(.platform, "Unable to connect to wayland socket: {any}", .{e});
            return error.WaylandSocketConnectFailed;
        };
        socket.writer = socket.stream.writer(io, &socket.write_stage);
        socket.reader = socket.stream.reader(io, &socket.read_buf);
        socket.ids = .{};
        socket.handlers = .init(gpa);

        return socket;
    }
    pub fn deinit(self: *Connection) void {
        self.stream.close(self.io);

        var iter = self.handlers.iterator();
        while (iter.next()) |entry| {
            self.gpa.free(entry.value_ptr);
        }
        self.handlers.deinit(self.gpa);

        self.gpa.destroy(self);
    }

    pub fn sendRaw(self: *Connection, obj_id: u32, msg: anytype) !void {
        const opcode: u16 = @intCast(@intFromEnum(std.meta.activeTag(msg)));
        const msg_len = emit(obj_id, opcode, msg, &self.send_buf);

        self.writer.interface.writeAll(self.send_buf[0..msg_len]) catch |e| {
            log.err(.platform, "Failed to write to Wayland Socket {any}", .{e});
        };
        self.writer.interface.flush() catch |e| {
            log.err(.platform, "Failed to flush to Wayland Socket {any}", .{e});
        };
    }

    pub fn nextMessage(self: *Connection) !Message {
        const header = try self.reader.interface.peekStruct(Header, .little);
        const obj_id = header.obj_id;
        const size_op = header.size_opcode;
        const size = header.size();

        const bytes = try self.reader.interface.take(size);

        return .{
            .header = .{
                .obj_id = obj_id,
                .size_opcode = size_op,
            },
            .bytes = bytes,
        };
    }

    pub fn registerProxy(
        self: *Connection,
        comptime Iface: type,
        proxy: *Proxy(Iface),
    ) !void {
        const trampoline = struct {
            fn handle(ctx: *anyopaque, opcode: u16, bytes: []const u8) !void {
                const p: *Proxy(Iface) = @ptrCast(@alignCast(ctx));
                try p.handle(opcode, bytes);
            }
        };
        try self.handlers.put(proxy.obj_id, .{
            .ctx = proxy,
            .handle_fn = trampoline.handle,
        });
    }

    pub fn unregistryProxy(self: *Connection, obj_id: u32) void {
        _ = self.handlers.remove(obj_id);
    }

    pub fn drain(self: *Connection, stop_obj_id: u32) !void {
        while (true) {
            const m = try self.nextMessage();
            if (m.header.obj_id == stop_obj_id) return;

            if (self.handlers.get(m.header.obj_id)) |h| {
                try h.handle_fn(h.ctx, m.header.opcode(), m.bytes);
            } else {
                log.warn(
                    .platform,
                    "No handler for obj_id: {d} opcode: {d}",
                    .{ m.header.obj_id, m.header.opcode() },
                );
            }

            if (m.header.obj_id == 1 and m.header.opcode() == 1) {
                const deleted = std.mem.readInt(
                    u32,
                    m.bytes[@sizeOf(Header)..][0..4],
                    .little,
                );
                _ = self.handlers.remove(deleted);
            }
        }
    }
};
