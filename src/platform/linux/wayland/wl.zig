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
pub const WlArray = struct {
    len: u32,
    data: []const u8,
};

pub const WlFixed = packed struct {
    frac: u8,
    integer: i24,

    pub fn toF32(self: WlFixed) f32 {
        _ = self;
        return 0.0;
    }
    pub fn fromU32(u: u32) WlFixed {
        _ = u;
        return .{ .frac = 0, .integer = 0 };
    }
};

pub const WlErrors = enum {
    invalid_obj, // obj doesn't exist
    invalid_method, // bad request or obj doesn't support
    no_memory, // server is out of memory
    implementation, // implementation error on the compositor side
};
comptime {
    std.debug.assert(@intFromEnum(WlErrors.invalid_obj) == 0);
    std.debug.assert(@intFromEnum(WlErrors.invalid_method) == 1);
    std.debug.assert(@intFromEnum(WlErrors.no_memory) == 2);
    std.debug.assert(@intFromEnum(WlErrors.implementation) == 3);
}

// wl_display (obj_id = 1, fixed by protocol)
// Core Global Object, special singleton object
// used for internal Wayland features
pub const WlDisplay = struct {
    pub const Request = union(enum) {
        sync: struct { callback: u32 },
        get_registry: struct { registry: u32 },
    };
    pub const Event = union(enum) {
        err: struct {
            object_id: u32,
            code: u32,
            msg: []const u8,
        },
        delete_id: struct {
            id: u32,
        },
    };
    comptime {
        std.debug.assert(@intFromEnum(WlDisplay.Request.sync) == 0);
        std.debug.assert(@intFromEnum(WlDisplay.Request.get_registry) == 1);

        std.debug.assert(@intFromEnum(WlDisplay.Event.err) == 0);
        std.debug.assert(@intFromEnum(WlDisplay.Event.delete_id) == 1);
    }
};
pub const WlRegistry = struct {
    pub const Request = union(enum) {
        bind: struct {
            name: u32,
            interface: []const u8,
            version: u32,
            new_id: u32,
        },
    };
    pub const Event = union(enum) {
        global: struct {
            name: u32,
            interface: []const u8,
            version: u32,
        },
        global_remove: struct {
            name: u32,
        },
    };
};
comptime {
    std.debug.assert(@intFromEnum(WlRegistry.Request.bind) == 0);

    std.debug.assert(@intFromEnum(WlRegistry.Event.global) == 0);
    std.debug.assert(@intFromEnum(WlRegistry.Event.global_remove) == 1);
}

pub const WlCompositor = struct {
    pub const Request = union(enum) {
        create_surface: struct {
            new_id: u32,
        },
        create_region: struct {
            new_id: u32,
        },
        release: struct {},
    };
    pub const Event = union(enum) {};
};
comptime {
    std.debug.assert(@intFromEnum(WlCompositor.Request.create_surface) == 0);
    std.debug.assert(@intFromEnum(WlCompositor.Request.create_region) == 1);
    std.debug.assert(@intFromEnum(WlCompositor.Request.release) == 2);
}

pub const WlSeatCape = struct {
    pub const pointer: u32 = 1;
    pub const keyboard: u32 = 2;
    pub const touch: u32 = 4;
};
pub const WlSeat = struct {
    pub const Request = union(enum) {
        get_pointer: struct { new_id: u32 },
        get_keyboard: struct { new_id: u32 },
        get_touch: struct { new_id: u32 },
        release: struct {},
    };
    pub const Event = union(enum) {
        capabilities: struct {
            capes: u32,
        },
        name: struct {
            name: []const u8,
        },
    };
};
comptime {
    std.debug.assert(@intFromEnum(WlSeat.Request.get_pointer) == 0);
    std.debug.assert(@intFromEnum(WlSeat.Request.get_keyboard) == 1);
    std.debug.assert(@intFromEnum(WlSeat.Request.get_touch) == 2);
    std.debug.assert(@intFromEnum(WlSeat.Request.release) == 3);

    std.debug.assert(@intFromEnum(WlSeat.Event.capabilities) == 0);
    std.debug.assert(@intFromEnum(WlSeat.Event.name) == 1);
}

pub const WlPointer = struct {
    pub const Request = union(enum) {
        set_cursor: struct {
            serial: u32,
            surface: u32,
            hotspot_x: i32,
            hotspot_y: i32,
        },
        release: struct {},
    };
    pub const Event = union(enum) {
        enter: struct {
            serial: u32,
            surface: u32,
            surface_x: WlFixed,
            surface_y: WlFixed,
        },
        leave: struct {
            serial: u32,
            surface: u32,
        },
        motion: struct {
            time: u32,
            surface_x: WlFixed,
            surface_y: WlFixed,
        },
        button: struct {
            serial: u32,
            time: u32,
            button: u32,
            state: u32,
        },
        axis: struct {
            time: u32,
            axis: u32,
            value: WlFixed,
        },
        frame: struct {},
        axis_source: struct {
            source: u32,
        },
        axis_stop: struct {
            time: u32,
            axis: u32,
        },
        axis_discrete: struct {
            axis: u32,
            discrete: i32,
        },
        axis_value120: struct {
            axis: u32,
            value120: i32,
        },
        axis_relative_direction: struct {
            axis: u32,
            direction: u32,
        },
    };
};

pub const WlKeyboard = struct {
    pub const Request = union(enum) {
        release: struct {},
    };
    pub const Event = union(enum) {
        keymap: struct {
            format: u32,
            fd: void,
            size: u32,
        },
        enter: struct {
            serial: u32,
            surface: u32,
            keys: WlArray,
        },
        leave: struct {
            serial: u32,
            surface: u32,
        },
        key: struct {
            serial: u32,
            time: u32,
            key: u32,
            state: u32,
        },
        modifiers: struct {
            serial: u32,
            mods_depressed: u32,
            mods_latched: u32,
            mods_locked: u32,
            group: u32,
        },
        repeat_info: struct {
            rate: u32,
            delay: u32,
        },
    };
};

pub const WlSurface = struct {
    pub const Request = union(enum) {
        destroy: struct {},
        attach: struct {
            buf: u32,
            x: i32,
            y: i32,
        },
        damage: struct {
            x: i32,
            y: i32,
            width: i32,
            height: i32,
        },
        frame: struct { callback: u32 },
        set_opque_region: struct { region: u32 },
        set_input_region: struct { region: u32 },
        commit: struct {},
        set_buffer_transform: struct { transform: i32 },
        set_buffer_scale: struct { scale: i32 },
        damage_buffer: struct {
            x: i32,
            y: i32,
            width: i32,
            height: i32,
        },
        offset: struct { x: i32, y: i32 },
        get_release: struct { callback: u32 },
    };
    pub const Event = union(enum) {
        enter: struct { output: u32 },
        leave: struct { output: u32 },
        preferred_buffer_scale: struct { factor: i32 },
        preferred_buffer_transform: struct { transform: u32 },
    };
};
