const builtin = @import("builtin");
const vk = @import("../c_bridge.zig").c;
const log = @import("debug").log;

extern fn get_metal_layer(window: ?*anyopaque) ?*anyopaque; // TODO: remove this when done building on mac for linux

const Self = @This();

handle: *vk.struct_VkSurfaceKHR_T,

const WaylandHandles = struct {
    display: *anyopaque,
    surface: *anyopaque,
};

pub fn init(
    instance: *vk.struct_VkInstance_T,
    native_handle: *anyopaque,
) !Self {
    var surface: vk.VkSurfaceKHR = null;

    switch (builtin.os.tag) {
        .linux => {
            const handles: *WaylandHandles = @ptrCast(@alignCast(native_handle));
            const create_info: vk.VkWaylandSurfaceCreateInfoKHR = .{
                .sType = vk.VK_STRUCTURE_TYPE_WAYLAND_SURFACE_CREATE_INFO_KHR,
                .display = @ptrCast(handles.display),
                .surface = @ptrCast(handles.surface),
            };
            if (vk.vkCreateWaylandSurfaceKHR(instance, &create_info, null, &surface) != vk.VK_SUCCESS) {
                log.err(.renderer, "Failed to create Wayland surface", .{});
                return error.SurfaceCreationFailed_Wayland;
            }
        },
        .macos => {
            const layer = get_metal_layer(native_handle) orelse {
                log.err(.renderer, "Failed to get CAMetalLayer from window", .{});
                return error.MetalLayerUnavailable;
            };
            const create_info: vk.VkMetalSurfaceCreateInfoEXT = .{
                .sType = vk.VK_STRUCTURE_TYPE_METAL_SURFACE_CREATE_INFO_EXT,
                .pLayer = layer,
            };
            if (vk.vkCreateMetalSurfaceEXT(instance, &create_info, null, &surface) != vk.VK_SUCCESS) {
                log.err(.renderer, "Failed to create Metal surface", .{});
                return error.SurfaceCreationFailed_Metal;
            }
        },
        else => return error.UnsupportedPlatform,
    }

    return .{ .handle = surface.? };
}

pub fn deinit(self: *Self, instance: *vk.struct_VkInstance_T) void {
    vk.vkDestroySurfaceKHR(instance, self.handle, null);
}
