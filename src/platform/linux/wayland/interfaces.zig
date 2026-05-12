//! Wayland protocol interfaces - wire protocol bindings.
//!
//! Each interface is a namespace containint:
//!     Event - union(enum) of all incoming messages
//!     Request - union(enum) of all outoging messages
//!
//! ORDERING CONTRACT !!!! THIS IS IMPORTANT
//! enum variant order == wire opcode (0-indexed)
//! Wayland guarantees new opcodes are append-only, so this is stable
//! Comptime asserts at the end of the file enforce the mapping
//! If they fire, the interface is out of sync w/ the spec

const std = @import("std");

pub const Callback = struct {
    pub const Request = union(enum) {};
    pub const Event = union(enum) {
        done: struct {
            callback_data: u32,
        },
    };
};
comptime {
    std.debug.assert(@intFromEnum(Callback.Event.done) == 0);
}

const wl = @import("wl.zig");
pub const WlArray = wl.WlArray;
pub const WlCompositor = wl.WlCompositor;
pub const WlDisplay = wl.WlDisplay;
pub const WlFixed = wl.WlFixed;
pub const WlKeyboard = wl.WlKeyboard;
pub const WlPointer = wl.WlPointer;
pub const WlRegistry = wl.WlRegistry;
pub const WlSeat = wl.WlSeat;
pub const WlSeatCape = wl.WlSeatCape;
pub const WlSurface = wl.WlSurface;

const xdg = @import("xdg.zig");
pub const XdgWmBase = xdg.XdgWmBase;
pub const XdgToplevel = xdg.XdgToplevel;
pub const XdgSurface = xdg.XdgSurface;
