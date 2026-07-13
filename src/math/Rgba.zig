/// This defines the RRGGBBAA format for color
/// As a user you can pack and unpack only
pub const Rgba = packed struct {
    pub const clear: Rgba = .{ .r = 0, .g = 0, .b = 0, .a = 0 };

    r: u8, // 0-255
    g: u8, // 0-255
    b: u8, // 0-255
    a: u8, // 0-255

    pub fn pack(self: Rgba) u32 {
        return (@as(u32, self.r) << 24) |
            (@as(u32, self.g) << 16) |
            (@as(u32, self.b) << 8) |
            @as(u32, self.a);
    }

    pub fn unpack(p: u32) Rgba {
        return .{
            .r = @truncate(p >> 24),
            .g = @truncate(p >> 16),
            .b = @truncate(p >> 8),
            .a = @truncate(p),
        };
    }
};
