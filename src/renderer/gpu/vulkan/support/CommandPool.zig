const vk = @import("../c_bridge.zig").c;
const Device = @import("Device.zig");
const PhysicalDevice = @import("PhysicalDevice.zig");

const frames_in_flight = @import("constants.zig").frames_in_flight;

pool: *vk.struct_VkCommandPool_T,
buffers: [frames_in_flight]vk.VkCommandBuffer,

const Self = @This();

pub fn init(dev: Device, gpu: PhysicalDevice) !Self {
    var pool: vk.VkCommandPool = null;
    var create_info: vk.struct_VkCommandPoolCreateInfo = .{};
    create_info.sType = vk.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
    create_info.flags = vk.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
    create_info.queueFamilyIndex = gpu.queue_families.graphics;
    if (vk.vkCreateCommandPool(dev.handle, &create_info, null, &pool) != vk.VK_SUCCESS)
        return error.UnableToCreateCommandPool;

    var buffers: [frames_in_flight]vk.VkCommandBuffer = undefined;
    var allocate_info: vk.VkCommandBufferAllocateInfo = .{};
    allocate_info.sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    allocate_info.commandBufferCount = frames_in_flight;
    allocate_info.commandPool = pool;
    allocate_info.level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    if (vk.vkAllocateCommandBuffers(dev.handle, &allocate_info, &buffers) != vk.VK_SUCCESS)
        return error.UnableToAllocateCommandBuffers;

    return .{
        .buffers = buffers,
        .pool = pool.?,
    };
}

pub fn deinit(self: *Self, dev: Device) void {
    vk.vkDestroyCommandPool(dev.handle, self.pool, null);
}
