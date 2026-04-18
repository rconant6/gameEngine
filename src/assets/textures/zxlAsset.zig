const std = @import("std");
const ArrayList = std.ArrayList;
const zxl = @import("zxl");
const ZixelImage = zxl.ZxlImage;
const rend = @import("renderer");
const Texture = rend.Renderer.Texture;

const Self = @This();

image: ZixelImage,
frame_textures: ArrayList(?*Texture),
