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
    const is_simple_filename = std.mem.indexOfAny(u8, file_path, "/\\") == null;
    const has_extension = std.mem.endsWith(u8, file_path, ".scene");

    const resolved_path = if (is_simple_filename) blk: {
        if (has_extension) {
            break :blk try std.fmt.allocPrint(allocator, "assets/scenes/{s}", .{file_path});
        } else {
            break :blk try std.fmt.allocPrint(allocator, "assets/scenes/{s}.scene", .{file_path});
        }
    } else blk: {
        if (has_extension) {
            break :blk file_path;
        } else {
            break :blk try std.fmt.allocPrint(allocator, "{s}.scene", .{file_path});
        }
    };
    const needs_free = is_simple_filename or !has_extension;
    defer if (needs_free) allocator.free(resolved_path);

    const buf: [:0]u8 = try std.fs.cwd().readFileAllocOptions(
        allocator,
        resolved_path,
        1024 * 1024,
        null,
        .@"1",
        @as(u8, 0),
    );
    errdefer allocator.free(buf);

    const scene = try scene_format.parseString(allocator, buf, file_path);

    allocator.free(buf);

    return scene;
}
