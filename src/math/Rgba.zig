pub const Rgba = packed struct {
    pub const clear: Rgba = .{ .r = 0, .g = 0, .b = 0, .a = 0 };
    r: u8, // 0-255
    g: u8, // 0-255
    b: u8, // 0-255
    a: u8, // 0-255
};
