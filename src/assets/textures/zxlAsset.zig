const std = @import("std");
const zxl = @import("zxl");
const ZxlImage = zxl.ZxlImage;
const rend = @import("renderer");
const Texture = rend.Renderer.Texture;

const Self = @This();

image: ZxlImage,
frame_textures: std.ArrayList(?*Texture),
// Each slot corresponds to a frame index in image.frames
// null = not yet uploaded to GPU, non-null = cached GPU texture
