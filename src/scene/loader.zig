const std = @import("std");
const scene_format = @import("scene-format");
const SceneFile = scene_format.SceneFile;

const LoadError = error{
    FileNotFound,
    ReadError,
    InavlidFormat,
};

pub fn loadSceneFile(
    allocator: std.mem.Allocator,
    file_path: []const u8,
) !scene_format.SceneFile {
    const buf: [:0]u8 = try std.fs.cwd().readFileAllocOptions(
        allocator,
        file_path,
        1024 * 1024,
        null,
        .@"1",
        @as(u8, 0),
    );
    errdefer allocator.free(buf);

    const scene = scene_format.parseString(allocator, buf, file_path);

    allocator.free(buf);

    return scene;
}
