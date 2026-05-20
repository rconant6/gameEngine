const faces = @import("interfaces.zig");
const WlCompositor = faces.WlCompositor;
const WlDisplay = faces.WlDisplay;
const WlKeyboard = faces.WlKeyboard;
const WlOutput = faces.WlOutput;
const WlPointer = faces.WlPointer;
const WlRegistry = faces.WlRegistry;
const WlSeat = faces.WlSeat;
const WlSeatCape = faces.WlSeatCape;
const WlSurface = faces.WlSurface;
const XdgSurface = faces.XdgSurface;
const XdgToplevel = faces.XdgToplevel;
const XdgWmBase = faces.XdgWmBase;
const wire = @import("wire.zig");
const WlConnection = wire.Connection;

pub const WindowState = struct {
    surface: wire.Proxy(WlSurface) = undefined, // wl_surface
    xdg_surface: wire.Proxy(XdgSurface) = undefined, // xdg_surface wrapper
    xdg_toplevel: wire.Proxy(XdgToplevel) = undefined, // xdg_toplevel (the actual window)

    configure_serial: u32 = 0,
    configured: bool = false, // has compositor sent configure+ack?
};

pub fn BoundObject(comptime T: type) type {
    return struct {
        name: u32 = 0,
        version: u32 = 0,
        proxy: wire.Proxy(T) = undefined,
    };
}

pub const OutputInfo = struct {
    width: i32 = 0,
    height: i32 = 0,
    refresh: i32 = 0,
    scale: i32 = 0,
};

pub const WaylandState = struct {
    conn: *WlConnection,
    display_proxy: wire.Proxy(WlDisplay) = undefined,
    registry_proxy: wire.Proxy(WlRegistry) = undefined,
    compositor: BoundObject(WlCompositor) = .{},
    seat: BoundObject(WlSeat) = .{},
    pointer: BoundObject(WlPointer) = .{},
    keyboard: BoundObject(WlKeyboard) = .{},
    xdg_wm_base: BoundObject(XdgWmBase) = .{},
    output: BoundObject(WlOutput) = .{},

    has_keyboard: bool = false,
    has_pointer: bool = false,
    output_info: OutputInfo = .{},
};
