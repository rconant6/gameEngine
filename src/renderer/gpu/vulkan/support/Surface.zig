const vk = @import("../c_bridge.zig").c;

const Self = @This();

handle: *vk.struct_VkSurfaceKHR_T,
pub fn init() !Self {
    //
}
pub fn deinit(self: *Self) void {
    _ = self;
    //
}
