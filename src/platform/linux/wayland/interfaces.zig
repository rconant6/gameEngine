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
const protocol = @import("protocall.zig");
const WlFixed = protocol.WlFixed;

// wl_display (obj_id = 1, fixed by protocol)
// Core Global Object, special singleton object
// used for internal Wayland features
pub const Display = struct {
    // Requests
    pub const Request = union(enum) {
        sync: struct { callback: u32 },
        get_registry: struct { registry: u32 },
    };
    // Events
    pub const Event = union(enum) {
        err: struct {
            object_id: u32,
            code: u32,
            msg: []const u8,
        },
        deleteId: struct {
            id: u32,
        },
    };
    // Errors
    pub const Error = enum {
        invalid_obj, // obj doesn't exist
        invalid_method, // bad request or obj doesn't support
        no_memory, // server is out of memory
        implementation, // implementation error on the compositor side
    };
};

pub const Registry = struct {
    // Requests
    pub const Request = union(enum) {
        bind: struct {
            name: u32,
            new_id: u32,
        },
    };
    // Events
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

pub const Callback = struct {
    // Events
    pub const Event = union(enum) {
        done: struct {
            callback_data: u32,
        },
    };
};


    
comptime {
    std.debug.assert(@intFromEnum(Display.Event.err) == 0);
    std.debug.assert(@intFromEnum(Display.Event.deleteId) == 1);
    std.debug.assert(@intFromEnum(Display.Request.sync) == 0);
    std.debug.assert(@intFromEnum(Display.Request.get_registry) == 1);
    std.debug.assert(@intFromEnum(Display.Error.invalid_obj) == 0);
    std.debug.assert(@intFromEnum(Display.Error.invalid_method) == 1);
    std.debug.assert(@intFromEnum(Display.Error.no_memory) == 2);
    std.debug.assert(@intFromEnum(Display.Error.implementation) == 3);

    std.debug.assert(@intFromEnum(Registry.Request.bind) == 0);
    std.debug.assert(@intFromEnum(Registry.Event.global) == 0);
    std.debug.assert(@intFromEnum(Registry.Event.global_remove) == 1);

    std.debug.assert(@intFromEnum(Callback.Event.done) == 0);
}
