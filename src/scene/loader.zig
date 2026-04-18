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
    io: std.Io,
    file_path: []const u8,
) !scene_format.SceneFile {
    const folder = "scenes/";
    return loadFile(allocator, io, file_path, folder, ".scene");
}

pub fn loadTemplateFile(
    allocator: std.mem.Allocator,
    io: std.Io,
    file_path: []const u8,
) !scene_format.SceneFile {
    const folder = "templates/";
    return loadFile(allocator, io, file_path, folder, ".template");
}

fn loadFile(
    allocator: std.mem.Allocator,
    io: std.Io,
    file_path: []const u8,
    folder: []const u8,
    ext: []const u8,
) !scene_format.SceneFile {
    const is_simple_filename = std.mem.indexOfAny(u8, file_path, "/\\") == null;
    const has_extension = std.mem.endsWith(u8, file_path, ext);

    const resolved_path = if (is_simple_filename) blk: {
        if (has_extension) {
            break :blk try std.fmt.allocPrint(allocator, "assets/{s}{s}", .{ folder, file_path });
        } else {
            break :blk try std.fmt.allocPrint(allocator, "assets/{s}{s}{s}", .{ folder, file_path, ext });
        }
    } else blk: {
        if (has_extension) {
            break :blk file_path;
        } else {
            break :blk try std.fmt.allocPrint(allocator, "{s}{s}", .{ file_path, ext });
        }
    };
    const needs_free = is_simple_filename or !has_extension;
    defer if (needs_free) allocator.free(resolved_path);

    const buf: [:0]u8 = try std.Io.Dir.cwd().readFileAllocOptions(
        io,
        resolved_path,
        allocator,
        std.Io.Limit.limited(1024 * 1024),
        .@"1",
        0,
    );
    errdefer allocator.free(buf);

    const scene = try scene_format.parseString(allocator, buf, file_path);

    allocator.free(buf);

    return scene;
}
