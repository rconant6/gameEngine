const std = @import("std");
const wl = @import("wl.zig");
pub const WlArray = wl.WlArray;

pub const XdgWmBase = struct {
    pub const Event = union(enum) {
        ping: struct { serial: u32 },
    };
};
comptime {
    std.debug.assert(@intFromEnum(XdgWmBase.Event.ping) == 0);
}

pub const XdgSurface = struct {
    pub const Event = union(enum) {
        configure: struct {
            serial: u32,
        },
    };
};
comptime {
    std.debug.assert(@intFromEnum(XdgSurface.Event.configure) == 0);
}

pub const XdgToplevel = struct {
    pub const Event = union(enum) {
        configure: struct {
            width: i32,
            height: i32,
            states: WlArray,
        },
        close: struct {},
        configure_bounds: struct { width: i32, height: i32 },
        wm_capabilites: struct { capabilities: WlArray },
    };
};
comptime {
    std.debug.assert(@intFromEnum(XdgToplevel.Event.configure) == 0);
    std.debug.assert(@intFromEnum(XdgToplevel.Event.close) == 1);
    std.debug.assert(@intFromEnum(XdgToplevel.Event.configure_bounds) == 2);
    std.debug.assert(@intFromEnum(XdgToplevel.Event.wm_capabilites) == 3);
}
