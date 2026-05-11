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
const wire = @import("wire.zig");
const WlFixed = wire.WlFixed;

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
