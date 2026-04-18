const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const metal = @import("metal_types.zig");
const TextureVertex = metal.TextureVertex;
const MTLTexture = metal.MTLTexture;

pub const TextureDrawCall = struct {
    texture: *MTLTexture,
    vertex_start: u32,
    vertex_count: u32 = 6,
};

pub const TextureBatch = struct {
    vertices: ArrayList(TextureVertex),
    draw_calls: ArrayList(TextureDrawCall),
    gpa: Allocator,

    pub fn init(gpa: Allocator) TextureBatch {
        return .{
            .gpa = gpa,
            .vertices = .empty,
            .draw_calls = .empty,
        };
    }
    pub fn deinit(self: *TextureBatch) void {
        self.vertices.deinit(self.gpa);
        self.draw_calls.deinit(self.gpa);
    }
    pub fn clear(self: *TextureBatch) void {
        self.vertices.clearRetainingCapacity();
        self.draw_calls.clearRetainingCapacity();
    }

    pub fn addSprite(
        self: *TextureBatch,
        texture: *MTLTexture,
        clip_corners: [4][2]f32, // TL, TR, BL, BR in clip space
        uvs: [4][2]f32, // TL, TR, BL, BR in uv coords
    ) !void {
        const vertex_start: u32 = @intCast(self.vertices.items.len);

        const verts: [6]TextureVertex = .{
            // TRI 1
            .{
                .position = clip_corners[0],
                .texcoord = uvs[0],
            },
            .{
                .position = clip_corners[1],
                .texcoord = uvs[1],
            },
            .{
                .position = clip_corners[2],
                .texcoord = uvs[2],
            },
            // TRI 2
            .{
                .position = clip_corners[1],
                .texcoord = uvs[1],
            },
            .{
                .position = clip_corners[3],
                .texcoord = uvs[3],
            },
            .{
                .position = clip_corners[2],
                .texcoord = uvs[2],
            },
        };
        try self.vertices.appendSlice(self.gpa, &verts);
        try self.draw_calls.append(self.gpa, .{
            .texture = texture,
            .vertex_start = vertex_start,
        });
    }
};
