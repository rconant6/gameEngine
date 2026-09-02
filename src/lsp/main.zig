const std = @import("std");
const Transport = @import("Transport.zig");
const Server = @import("Server.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;
    // const arena = init.arena.allocator();

    // const args = init.minimal.args.toSlice(arena) catch |err| switch (err) {
    //     error.OutOfMemory => @panic("[LSP] Fatal error: Out Of Memory"),
    //     error.Unexpected => @panic("[LSP] Unexpected error while parsing arguments"),
    // };

    var in_buf: [64 * 1024]u8 = undefined;
    var out_buf: [64 * 1024]u8 = undefined;
    var file_reader = std.Io.File.stdin().reader(io, &in_buf);
    var file_writer = std.Io.File.stdout().writer(io, &out_buf);

    const transport = Transport{
        .in = &file_reader.interface,
        .out = &file_writer.interface,
        .gpa = gpa,
    };

    var server = Server.init(gpa, transport);
    defer server.deinit();
    try server.run();
}
