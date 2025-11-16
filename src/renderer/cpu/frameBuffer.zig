const std = @import("std");

const Color = @import("../renderer.zig").Color;

const BufferIndex = enum(u8) {
    zero = 0,
    one = 1,
    two = 2,

    pub fn next(self: BufferIndex) BufferIndex {
        return switch (self) {
            .zero => .one,
            .one => .two,
            .two => .zero,
        };
    }
};

/// Holds 3 buffers to handle the flicker seen w/ only 2 buffers
pub const FrameBuffer = struct {
    arena: std.heap.ArenaAllocator,
    displayBuffer: []Color,
    readyBuffer: []Color,
    writeBuffer: []Color,
    bufferMemory: []Color,
    displayBufferIndex: BufferIndex,
    width: u32,
    height: u32,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !FrameBuffer {
        const size: usize = @intCast(width * height);
        var arena = std.heap.ArenaAllocator.init(allocator);

        const buffer_memory = try arena.allocator().alloc(Color, size * 3);
        const display = buffer_memory[0..size];
        const ready = buffer_memory[size .. 2 * size];
        const write = buffer_memory[2 * size .. 3 * size];

        for (buffer_memory) |*pixel| {
            pixel.* = Color.init(0, 0, 0, 1);
        }

        return .{
            .arena = arena,
            .bufferMemory = buffer_memory[0..],
            .displayBuffer = display,
            .readyBuffer = ready,
            .writeBuffer = write,
            .displayBufferIndex = .zero,
            .width = width,
            .height = height,
        };
    }

    pub fn deinit(self: *FrameBuffer) void {
        self.arena.deinit();
    }

    pub fn clear(self: *FrameBuffer, color: Color) void {
        for (self.writeBuffer) |*pixel| {
            pixel.* = color;
        }
    }
    pub fn setPixel(self: *FrameBuffer, x: u32, y: u32, color: Color) void {
        if (x < 0 or y < 0 or x >= self.width or y >= self.height) {
            return;
        }

        const index: usize = @intCast(y * self.width + x);
        self.writeBuffer[index] = color;
    }
    pub fn getPixel(self: *FrameBuffer, x: u32, y: u32) ?Color {
        if (x < 0 or y < 0 or x >= self.width or y >= self.height) {
            return null;
        }

        const index: usize = @intCast(y * self.width + x);
        return self.writeBuffer[index];
    }

    pub fn rotateBuffers(self: *FrameBuffer) void {
        const temp = self.displayBuffer;
        self.displayBuffer = self.readyBuffer;
        self.readyBuffer = self.writeBuffer;
        self.writeBuffer = temp;

        self.displayBufferIndex = self.displayBufferIndex.next();
    }

    pub fn getDisplayBufferOffset(self: *const FrameBuffer) u32 {
        return @intFromEnum(self.displayBufferIndex) * self.width * self.height * 4;
    }
};
