//! Re-export hub for all Wayland protocol interface types.
//! Import this instead of wl.zig / xdg.zig directly.

const wl = @import("wl.zig");
pub const WlArray = wl.WlArray;
pub const WlCompositor = wl.WlCompositor;
pub const WlDisplay = wl.WlDisplay;
pub const WlFixed = wl.WlFixed;
pub const WlKeyboard = wl.WlKeyboard;
pub const WlObjectId = wl.WlObjectId;
pub const WlOutput = wl.WlOutput;
pub const WlPointer = wl.WlPointer;
pub const WlRegistry = wl.WlRegistry;
pub const WlSeat = wl.WlSeat;
pub const WlSeatCape = wl.WlSeatCape;
pub const WlSurface = wl.WlSurface;

const xdg = @import("xdg.zig");
pub const XdgWmBase = xdg.XdgWmBase;
pub const XdgToplevel = xdg.XdgToplevel;
pub const XdgSurface = xdg.XdgSurface;
