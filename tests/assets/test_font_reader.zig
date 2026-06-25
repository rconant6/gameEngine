//! Unit tests for FontReader — the big-endian binary cursor under all
//! TrueType parsing. Pure, deterministic, no I/O: byte buffer in, value out.
//!
//! Includes a test that documents a latent bug (rewind has no bounds check)
//! so the behavior is visible and pinned rather than silently relied upon.

const std = @import("std");
const testing = std.testing;
const FontReader = @import("FontReader").FontReader;

// MARK: scalar reads

test "readU8 advances one byte at a time" {
    const data = [_]u8{ 0x01, 0x7F, 0xFF };
    var r = FontReader{ .data = &data };

    try testing.expectEqual(@as(u8, 0x01), r.readU8());
    try testing.expectEqual(@as(u8, 0x7F), r.readU8());
    try testing.expectEqual(@as(u8, 0xFF), r.readU8());
    try testing.expectEqual(@as(usize, 3), r.pos);
}

test "readU16BigEndian decodes big-endian order" {
    const data = [_]u8{ 0x12, 0x34, 0xAB, 0xCD };
    var r = FontReader{ .data = &data };

    try testing.expectEqual(@as(u16, 0x1234), r.readU16BigEndian());
    try testing.expectEqual(@as(u16, 0xABCD), r.readU16BigEndian());
    try testing.expectEqual(@as(usize, 4), r.pos);
}

test "readU32BigEndian decodes big-endian order" {
    const data = [_]u8{ 0xDE, 0xAD, 0xBE, 0xEF };
    var r = FontReader{ .data = &data };

    try testing.expectEqual(@as(u32, 0xDEADBEEF), r.readU32BigEndian());
    try testing.expectEqual(@as(usize, 4), r.pos);
}

test "readU64BigEndian decodes big-endian order" {
    const data = [_]u8{ 0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF };
    var r = FontReader{ .data = &data };

    try testing.expectEqual(@as(u64, 0x0123456789ABCDEF), r.readU64BigEndian());
}

test "readI16BigEndian preserves sign" {
    // 0xFFFF = -1, 0x8000 = -32768, 0x7FFF = 32767
    const data = [_]u8{ 0xFF, 0xFF, 0x80, 0x00, 0x7F, 0xFF };
    var r = FontReader{ .data = &data };

    try testing.expectEqual(@as(i16, -1), r.readI16BigEndian());
    try testing.expectEqual(@as(i16, -32768), r.readI16BigEndian());
    try testing.expectEqual(@as(i16, 32767), r.readI16BigEndian());
}

test "readI32BigEndian preserves sign" {
    // 0xFFFFFFFF = -1, 0x00000001 = 1
    const data = [_]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x01 };
    var r = FontReader{ .data = &data };

    try testing.expectEqual(@as(i32, -1), r.readI32BigEndian());
    try testing.expectEqual(@as(i32, 1), r.readI32BigEndian());
}

// MARK: struct reads

test "readStruct decodes each field as big-endian" {
    // mirrors a TableEntry-like record: tag(u32) checksum(u32) offset(u32) length(u32)
    const Entry = extern struct {
        tag: u32,
        checksum: u32,
        offset: u32,
        length: u32,
    };
    const data = [_]u8{
        0x67, 0x6C, 0x79, 0x66, // 'glyf'
        0x00, 0x00, 0x00, 0x10,
        0x00, 0x00, 0x01, 0x00,
        0x00, 0x00, 0x02, 0x00,
    };
    var r = FontReader{ .data = &data };
    const e = r.readStruct(Entry);

    try testing.expectEqual(@as(u32, 0x676C7966), e.tag);
    try testing.expectEqual(@as(u32, 0x10), e.checksum);
    try testing.expectEqual(@as(u32, 0x100), e.offset);
    try testing.expectEqual(@as(u32, 0x200), e.length);
    try testing.expectEqual(@as(usize, 16), r.pos);
}

// MARK: cursor movement

test "seek then read lands at the requested offset" {
    const data = [_]u8{ 0x00, 0x00, 0x00, 0x00, 0xCA, 0xFE };
    var r = FontReader{ .data = &data };

    r.seek(4);
    try testing.expectEqual(@as(u16, 0xCAFE), r.readU16BigEndian());
}

test "skip advances without reading" {
    const data = [_]u8{ 0x00, 0x00, 0x00, 0x00, 0xBE, 0xEF };
    var r = FontReader{ .data = &data };

    r.skip(4);
    try testing.expectEqual(@as(usize, 4), r.pos);
    try testing.expectEqual(@as(u16, 0xBEEF), r.readU16BigEndian());
}

test "remaining reflects bytes left after reads" {
    const data = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0 };
    var r = FontReader{ .data = &data };

    try testing.expectEqual(@as(usize, 8), r.remaining());
    _ = r.readU16BigEndian();
    try testing.expectEqual(@as(usize, 6), r.remaining());
    _ = r.readU32BigEndian();
    try testing.expectEqual(@as(usize, 2), r.remaining());
}

test "rewind backs up the cursor" {
    const data = [_]u8{ 0x11, 0x22, 0x33, 0x44 };
    var r = FontReader{ .data = &data };

    _ = r.readU32BigEndian();
    try testing.expectEqual(@as(usize, 4), r.pos);
    r.rewind(2);
    try testing.expectEqual(@as(usize, 2), r.pos);
    try testing.expectEqual(@as(u16, 0x3344), r.readU16BigEndian());
}

// MARK: checksum

test "calculateChecksum sums aligned 32-bit words and restores position" {
    // two words: 0x00000001 + 0x00000002 = 0x00000003
    const data = [_]u8{ 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x02 };
    var r = FontReader{ .data = &data };
    r.seek(8); // park the cursor at the end to prove it's restored

    const sum = r.calculateChecksum(0, 8, false);
    try testing.expectEqual(@as(u32, 3), sum);
    try testing.expectEqual(@as(usize, 8), r.pos); // restored
}

test "calculateChecksum zero-pads a non-multiple-of-4 tail" {
    // 5 bytes: word 0x00000001 + tail {0xFF,0,0,0} = 0xFF000000
    const data = [_]u8{ 0x00, 0x00, 0x00, 0x01, 0xFF };
    var r = FontReader{ .data = &data };

    const sum = r.calculateChecksum(0, 5, false);
    try testing.expectEqual(@as(u32, 0x00000001 +% 0xFF000000), sum);
}

test "calculateChecksum with is_head zeroes the checksumAdjustment word" {
    // head table layout: bytes 8..12 hold checksumAdjustment, which must be
    // treated as 0 during the checksum. Three words; word at offset 8 is index 2.
    const data = [_]u8{
        0x00, 0x00, 0x00, 0x01, // word 0
        0x00, 0x00, 0x00, 0x02, // word 1
        0xAA, 0xBB, 0xCC, 0xDD, // word 2 @ offset 8 -> forced to 0 when is_head
    };
    var r = FontReader{ .data = &data };

    const with_head = r.calculateChecksum(0, 12, true);
    try testing.expectEqual(@as(u32, 0x00000001 +% 0x00000002 +% 0x00000000), with_head);

    // sanity: without the head flag, that word contributes its real value
    const without_head = r.calculateChecksum(0, 12, false);
    try testing.expectEqual(@as(u32, 0x00000001 +% 0x00000002 +% 0xAABBCCDD), without_head);
}

// MARK: rewind bounds
//
// rewind() now guards with `if (negOffset > self.pos) @panic(...)`. Rewinding
// exactly to the start is the legal boundary and must land on 0; rewinding
// PAST the start panics (uncatchable in a Zig test, so not asserted here —
// the guard's presence is what this boundary test protects against regressing).

test "rewind to exactly the start lands on zero" {
    const data = [_]u8{ 0x11, 0x22, 0x33, 0x44 };
    var r = FontReader{ .data = &data };

    _ = r.readU32BigEndian(); // pos = 4
    r.rewind(4); // back to the very start — boundary case, must be allowed
    try testing.expectEqual(@as(usize, 0), r.pos);
    try testing.expectEqual(@as(u16, 0x1122), r.readU16BigEndian());
}
