const std = @import("std");

pub const FontReader = struct {
    data: []const u8,
    pos: usize = 0,

    pub fn readStruct(self: *FontReader, comptime T: type) T {
        const size = @sizeOf(T);
        if (self.pos + size > self.data.len) std.debug.panic(
            "FontReader.readStruct({s}): read of {d} bytes at pos {d} exceeds data length {d}",
            .{ @typeName(T), size, self.pos, self.data.len },
        );

        const result = fromBigEndian(T, self.data[self.pos .. self.pos + size]);
        self.pos += size;

        return result;
    }

    pub fn readU8(self: *FontReader) u8 {
        if (self.pos + 1 > self.data.len) std.debug.panic(
            "FontReader.readU8: read at pos {d} exceeds data length {d}",
            .{ self.pos, self.data.len },
        );

        const result = self.data[self.pos];
        self.pos += 1;

        return result;
    }
    pub fn readU16BigEndian(self: *FontReader) u16 {
        if (self.pos + 2 > self.data.len) std.debug.panic(
            "FontReader.readU16: read of 2 bytes at pos {d} exceeds data length {d}",
            .{ self.pos, self.data.len },
        );

        const bytes = self.data[self.pos .. self.pos + 2];
        const result = std.mem.bigToNative(u16, @bitCast(bytes[0..2].*));

        self.pos += 2;

        return result;
    }

    pub fn readU32BigEndian(self: *FontReader) u32 {
        if (self.pos + 4 > self.data.len) std.debug.panic(
            "FontReader.readU32: read of 4 bytes at pos {d} exceeds data length {d}",
            .{ self.pos, self.data.len },
        );

        const bytes = self.data[self.pos .. self.pos + 4];
        const result = std.mem.bigToNative(u32, @bitCast(bytes[0..4].*));

        self.pos += 4;

        return result;
    }

    pub fn readI16BigEndian(self: *FontReader) i16 {
        if (self.pos + 2 > self.data.len) std.debug.panic(
            "FontReader.readI16: read of 2 bytes at pos {d} exceeds data length {d}",
            .{ self.pos, self.data.len },
        );

        const bytes = self.data[self.pos .. self.pos + 2];
        const result = std.mem.bigToNative(i16, @bitCast(bytes[0..2].*));

        self.pos += 2;

        return result;
    }

    pub fn readI32BigEndian(self: *FontReader) i32 {
        if (self.pos + 4 > self.data.len) std.debug.panic(
            "FontReader.readI32: read of 4 bytes at pos {d} exceeds data length {d}",
            .{ self.pos, self.data.len },
        );

        const bytes = self.data[self.pos .. self.pos + 4];
        const result = std.mem.bigToNative(i32, @bitCast(bytes[0..4].*));

        self.pos += 4;

        return result;
    }

    pub fn readU64BigEndian(self: *FontReader) u64 {
        if (self.pos + 8 > self.data.len) std.debug.panic(
            "FontReader.readU64: read of 8 bytes at pos {d} exceeds data length {d}",
            .{ self.pos, self.data.len },
        );

        const bytes = self.data[self.pos .. self.pos + 8];
        const result = std.mem.bigToNative(u64, @bitCast(bytes[0..8].*));

        self.pos += 8;

        return result;
    }

    pub fn seek(self: *FontReader, offset: usize) void {
        if (offset > self.data.len) std.debug.panic(
            "FontReader.seek: offset {d} exceeds data length {d}",
            .{ offset, self.data.len },
        );
        self.pos = offset;
    }

    pub fn rewind(self: *FontReader, negOffset: usize) void {
        if (negOffset > self.pos) std.debug.panic(
            "FontReader.rewind: cannot back up {d} bytes from pos {d} (past start)",
            .{ negOffset, self.pos },
        );
        self.pos -= negOffset;
    }

    pub fn skip(self: *FontReader, bytes: usize) void {
        if (self.pos + bytes > self.data.len) std.debug.panic(
            "FontReader.skip: skipping {d} bytes from pos {d} exceeds data length {d}",
            .{ bytes, self.pos, self.data.len },
        );
        self.pos += bytes;

        return;
    }

    pub fn remaining(self: *const FontReader) usize {
        return self.data.len - self.pos;
    }

    pub fn calculateChecksum(
        self: *FontReader,
        offset: usize,
        length: usize,
        is_head: bool,
    ) u32 {
        const old_loc = self.pos;

        var sum: u32 = 0;
        var pos: u32 = 0;

        self.seek(offset);
        if (self.pos + length > self.data.len) std.debug.panic(
            "FontReader.calculateChecksum: range [{d}, {d}) exceeds data length {d}",
            .{ self.pos, self.pos + length, self.data.len },
        );

        while (pos + 4 <= length) {
            var value = self.readU32BigEndian();
            if (pos == 8 and is_head) value = 0;
            sum = sum +% value;
            pos += 4;
        }

        if (pos < length) {
            var final_bytes: [4]u8 = .{ 0, 0, 0, 0 };
            var i: u32 = 0;
            while (pos + i < length) {
                final_bytes[i] = self.data[self.pos + i];
                i += 1;
            }
            const final_value = std.mem.bigToNative(u32, @bitCast(final_bytes));
            sum = sum +% final_value;
        }

        self.pos = old_loc;

        return sum;
    }
};

fn swapEndianness(comptime T: type, value: T) T {
    var result: T = undefined;
    inline for (@typeInfo(T).@"struct".fields) |field| {
        @field(result, field.name) = std.mem.bigToNative(
            field.type,
            @field(value, field.name),
        );
    }

    return result;
}

fn fromBigEndian(comptime T: type, bytes: []const u8) T {
    const raw: T = @bitCast(bytes[0..@sizeOf(T)].*);
    return swapEndianness(T, raw);
}
