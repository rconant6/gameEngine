const vk = @import("../c_bridge.zig").c;
const Device = @import("Device.zig");

const Self = @This();

handle: *vk.struct_VkRenderPass_T,

pub fn init(dev: Device, fmt: vk.VkFormat) !Self {
    var attachment: vk.VkAttachmentDescription = .{};
    attachment.format = fmt;
    attachment.samples = vk.VK_SAMPLE_COUNT_1_BIT;
    attachment.storeOp = vk.VK_ATTACHMENT_STORE_OP_STORE;
    attachment.loadOp = vk.VK_ATTACHMENT_LOAD_OP_CLEAR;
    attachment.stencilLoadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    attachment.stencilStoreOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE;
    attachment.initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED;
    attachment.finalLayout = vk.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

    var attach_ref: vk.VkAttachmentReference = .{};
    attach_ref.attachment = 0;
    attach_ref.layout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

    var subpass_desc: vk.VkSubpassDescription = .{};
    subpass_desc.pipelineBindPoint = vk.VK_PIPELINE_BIND_POINT_GRAPHICS;
    subpass_desc.colorAttachmentCount = 1;
    subpass_desc.pColorAttachments = &attach_ref;

    var subpass_dep: vk.VkSubpassDependency = .{};
    subpass_dep.srcSubpass = vk.VK_SUBPASS_EXTERNAL;
    subpass_dep.dstSubpass = 0;
    subpass_dep.srcStageMask = vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    subpass_dep.dstStageMask = vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    subpass_dep.dstAccessMask = vk.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;

    var create_info: vk.VkRenderPassCreateInfo = .{};
    create_info.sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
    create_info.attachmentCount = 1;
    create_info.pAttachments = &attachment;
    create_info.subpassCount = 1;
    create_info.pSubpasses = &subpass_desc;
    create_info.dependencyCount = 1;
    create_info.pDependencies = &subpass_dep;

    var handle: vk.VkRenderPass = null;
    if (vk.vkCreateRenderPass(dev.handle, &create_info, null, &handle) != 0)
        return error.RenderPassCreationFailed;

    return .{
        .handle = handle.?,
    };
}

pub fn deinit(self: *Self, dev: Device) void {
    vk.vkDestroyRenderPass(dev.handle, self.handle, null);
}
