const std = @import("std");

const Color = @import("../../color.zig").Color;
const shapes = @import("../../shapes.zig");
const ShapeData = shapes.ShapeData;
const RenderContext = @import("../../RenderContext.zig");
const utils = @import("../../geometry_utils.zig");
const Transform = utils.Transform;

pub const MetalRenderer = struct {
    // TODO: update to get a ctx vice the width/height
    pub fn init(alloc: std.mem.Allocator, width: u32, height: u32) !MetalRenderer {
        _ = alloc;
        _ = width;
        _ = height;
        return MetalRenderer{};
    }
    pub fn deinit(self: *MetalRenderer) void {
        _ = self;
    }

    pub fn beginFrame(self: *MetalRenderer) !void {
        _ = self;
    }

    pub fn endFrame(self: *MetalRenderer) !void {
        _ = self;
    }

    pub fn clear(self: *MetalRenderer) void {
        _ = self;
    }

    pub fn setClearColor(self: *MetalRenderer, color: Color) void {
        _ = self;
        _ = color;
    }
    pub fn drawShape(
        self: *MetalRenderer,
        shape: ShapeData,
        transform: ?Transform,
    ) void {
        _ = self;
        _ = shape;
        _ = transform;
    }
};
