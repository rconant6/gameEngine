pub const c = @import("c.zig").c;
const std = @import("std");
const defs = @import("consts.zig");
const log = @import("debug").log;

pub const WaylandState = struct {
    display: *c.wl_display = undefined,
    registry: *c.wl_registry = undefined,
    compositor: ?*c.wl_compositor = null,
    xdg_wm_base: ?*c.xdg_wm_base = null,
    seat: ?*c.wl_seat = null,
    output: ?*c.wl_output = null,
};

// MARK: REGISTRY
pub const RegistryListener: c.wl_registry_listener = .{
    .global = listenerGlobal,
    .global_remove = listenerGlobalRemove,
};
fn listenerGlobal(
    data: ?*anyopaque,
    wl_registry: ?*c.struct_wl_registry,
    name: u32,
    interface: [*c]const u8,
    version: u32,
) callconv(.c) void {
    const state: *WaylandState = @ptrCast(@alignCast(data));
    const iface: []const u8 = std.mem.span(interface);

    if (std.mem.eql(u8, iface, defs.wl_compositor)) {
        state.compositor = @ptrCast(c.wl_registry_bind(
            wl_registry,
            name,
            &c.wl_compositor_interface,
            version,
        ));
        log.info(.platform, "Bound: {d} {s}, {d}", .{ name, iface, version });
        return;
    }
    if (std.mem.eql(u8, iface, defs.xdg_wm_base)) {
        state.xdg_wm_base = @ptrCast(c.wl_registry_bind(
            wl_registry,
            name,
            &c.xdg_wm_base_interface,
            version,
        ));
        log.info(.platform, "Bound: {d} {s}, {d}", .{ name, iface, version });
        return;
    }
    if (std.mem.eql(u8, iface, defs.wl_seat)) {
        state.seat = @ptrCast(c.wl_registry_bind(
            wl_registry,
            name,
            &c.wl_seat_interface,
            version,
        ));
        log.info(.platform, "Bound: {d} {s}, {d}", .{ name, iface, version });
        return;
    }
    if (std.mem.eql(u8, iface, defs.wl_output)) {
        state.output = @ptrCast(c.wl_registry_bind(wl_registry, name, &c.wl_output_interface, version));
        log.info(.platform, "Bound: {d} {s}, {d}", .{ name, iface, version });
        return;
    }
}
fn listenerGlobalRemove(
    data: ?*anyopaque,
    wl_registry: ?*c.struct_wl_registry,
    name: u32,
) callconv(.c) void {
    _ = data;
    _ = wl_registry;
    _ = name;
}
