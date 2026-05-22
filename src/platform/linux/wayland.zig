//! Wayland platform layer — single import point for linux.zig.
//! Consolidates all files in the wayland/ subfolder.

const wl = @import("wayland/interfaces.zig");
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
pub const XdgWmBase = wl.XdgWmBase;
pub const XdgToplevel = wl.XdgToplevel;
pub const XdgSurface = wl.XdgSurface;

const st = @import("wayland/state.zig");
pub const WaylandState = st.WaylandState;
pub const WindowState = st.WindowState;
pub const BoundObject = st.BoundObject;
pub const OutputInfo = st.OutputInfo;
pub const EventRingBuffer = st.EventRingBuffer;

pub const Proxy = @import("wayland/proxy.zig").Proxy;

pub const handlers = @import("wayland/handlers.zig");

pub const c = @import("wayland/c.zig").c;

pub const consts = @import("wayland/consts.zig");
