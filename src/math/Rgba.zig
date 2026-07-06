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
};
