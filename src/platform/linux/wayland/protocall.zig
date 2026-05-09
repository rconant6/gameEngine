const std = @import("std");
const log = @import("debug").log;

pub const WlFixed = packed struct {
    frac: u8,
    integer: i24,

    pub fn toF32(self: WlFixed) f32 {
        _ = self;
        return 0.0;
    }
    pub fn fromF32(f: f32) WlFixed {
        _ = f;
        return .{ .frac = 0, .integer = 0 };
    }
};

pub const ObjIdAllocator = struct {
    next: u32 = 2,

    pub fn alloc(self: *ObjIdAllocator) u32 {
        const id = self.next;
        self.next += 1;
        return id;
    }
};

pub fn parse(comptime T: type, data: []const u8, offset: *usize) !T {
    var result: T = undefined;

    inline for (@typeInfo(T).@"struct".fields) |field| {
        switch (field.type) {
            u32 => {
                @field(result, field.name) = std.mem.readInt(
                    u32,
                    data[offset.*..][0..4],
                    .little,
                );
                offset.* += 4;
            },
            i32 => {
                @field(result, field.name) = std.mem.readInt(
                    i32,
                    data[offset.*..][0..4],
                    .little,
                );
                offset.* += 4;
            },
            WlFixed => {
                @field(result, field.name) = std.mem.readInt(
                    u32,
                    data[offset.*..][0..4],
                    .little,
                );
                offset.* += 4;
            },
            []const u8 => {
                const len = std.mem.readInt(
                    u32,
                    data[offset.*..][0..4],
                    .little,
                ); // get size
                offset.* += 4;

                @field(result, field.name) = data[offset.*..][0 .. len - 1];
                offset.* += len; // str_len
                const pad = wlPad(offset.*);
                offset.* += pad; // offset to nearest 4
            },
            else => @compileError("parse: unsupported field type " ++ @typeName(field.type)),
        }
    }

    return result;
}

// OBJ_ID who i'm sending it to
// opcode - what i'm sending
// val - payload
// buf - storage for bytes
pub fn emit(obj_id: u32, opcode: u16, msg: anytype, buf: []u8) usize {
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

fn wlPad(len: usize) usize {
    return (4 - @mod(len, 4)) % 4;
}
