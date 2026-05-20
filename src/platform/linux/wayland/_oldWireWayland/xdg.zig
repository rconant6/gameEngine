const wl = @import("wl.zig");
pub const WlArray = wl.WlArray;

pub const XdgWmBase = struct {
    pub const Request = union(enum) {
        destroy: struct {},
        create_positioner: struct { new_id: u32 },
        get_xdg_surface: struct {
            id: u32,
            surface: u32,
        },
        pong: struct { serial: u32 },
    };
    pub const Event = union(enum) {
        ping: struct { serial: u32 },
    };
};
pub const XdgSurface = struct {
    pub const Request = union(enum) {
        destroy: struct {},
        get_toplevel: struct { id: u32 },
        get_popup: struct { id: u32, parent: u32, positioner: u32 },
        set_window_geometry: struct {
            x: i32,
            y: i32,
            width: i32,
            height: i32,
        },
        ack_configure: struct {
            serial: u32,
        },
    };
    pub const Event = union(enum) {
        configure: struct {
            serial: u32,
        },
    };
};
pub const XdgToplevel = struct {
    pub const Request = union(enum) {
        destroy: struct {},
        set_parent: struct { parent: u32 },
        set_title: struct { title: []const u8 },
        set_app_id: struct { app_id: []const u8 },
        show_window_menu: struct {
            seat: u32,
            serial: u32,
            x: i32,
            y: i32,
        },
        move: struct {
            seat: u32,
            serial: u32,
        },
        resize: struct {
            seat: u32,
            serial: u32,
            edges: u32,
        },
        set_max_size: struct {
            width: i32,
            height: i32,
        },
        set_min_size: struct {
            width: i32,
            height: i32,
        },
        set_maximized: struct {},
        unset_maximized: struct {},
        set_fullscreen: struct { output: u32 },
        unset_fullscreen: struct {},
        set_minimized: struct {},
    };
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
