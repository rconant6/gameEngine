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

pub const WlObjectId = struct { ptr: *anyopaque };

pub const WlArray = struct {
    len: u32,
    data: []const u8,
};

pub const WlFixed = packed struct {
    frac: u8,
    integer: i24,

    pub fn toF32(self: WlFixed) f32 {
        const raw: i32 = @as(i32, self.integer) << 8 | @as(i32, @intCast(self.frac));
        return @as(f32, @floatFromInt(raw)) / 256.0;
    }
};

// wl_display (obj_id = 1, fixed by protocol)
// Core Global Object, special singleton object
// used for internal Wayland features
pub const WlDisplay = struct {
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
        std.debug.assert(@intFromEnum(WlDisplay.Event.err) == 0);
        std.debug.assert(@intFromEnum(WlDisplay.Event.delete_id) == 1);
    }
};
pub const WlRegistry = struct {
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
    std.debug.assert(@intFromEnum(WlRegistry.Event.global) == 0);
    std.debug.assert(@intFromEnum(WlRegistry.Event.global_remove) == 1);
}

pub const WlCompositor = struct {
    pub const Event = union(enum) {};
};

pub const WlSeatCape = struct {
    pub const pointer: u32 = 1;
    pub const keyboard: u32 = 2;
    pub const touch: u32 = 4;
};
pub const WlSeat = struct {
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
    std.debug.assert(@intFromEnum(WlSeat.Event.capabilities) == 0);
    std.debug.assert(@intFromEnum(WlSeat.Event.name) == 1);
}

pub const WlPointer = struct {
    pub const Event = union(enum) {
        enter: struct {
            serial: u32,
            surface: WlObjectId,
            surface_x: WlFixed,
            surface_y: WlFixed,
        },
        leave: struct {
            serial: u32,
            surface: WlObjectId,
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
comptime {
    std.debug.assert(@intFromEnum(WlPointer.Event.enter) == 0);
    std.debug.assert(@intFromEnum(WlPointer.Event.leave) == 1);
    std.debug.assert(@intFromEnum(WlPointer.Event.motion) == 2);
    std.debug.assert(@intFromEnum(WlPointer.Event.button) == 3);
    std.debug.assert(@intFromEnum(WlPointer.Event.axis) == 4);
    std.debug.assert(@intFromEnum(WlPointer.Event.frame) == 5);
    std.debug.assert(@intFromEnum(WlPointer.Event.axis_source) == 6);
    std.debug.assert(@intFromEnum(WlPointer.Event.axis_stop) == 7);
    std.debug.assert(@intFromEnum(WlPointer.Event.axis_discrete) == 8);
    std.debug.assert(@intFromEnum(WlPointer.Event.axis_value120) == 9);
    std.debug.assert(@intFromEnum(WlPointer.Event.axis_relative_direction) == 10);
}

pub const WlKeyboard = struct {
    pub const Event = union(enum) {
        keymap: struct {
            format: u32,
            fd: void,
            size: u32,
        },
        enter: struct {
            serial: u32,
            surface: WlObjectId,
            keys: WlArray,
        },
        leave: struct {
            serial: u32,
            surface: WlObjectId,
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
comptime {
    std.debug.assert(@intFromEnum(WlKeyboard.Event.keymap) == 0);
    std.debug.assert(@intFromEnum(WlKeyboard.Event.enter) == 1);
    std.debug.assert(@intFromEnum(WlKeyboard.Event.leave) == 2);
    std.debug.assert(@intFromEnum(WlKeyboard.Event.key) == 3);
    std.debug.assert(@intFromEnum(WlKeyboard.Event.modifiers) == 4);
    std.debug.assert(@intFromEnum(WlKeyboard.Event.repeat_info) == 5);
}

pub const WlSurface = struct {
    pub const Event = union(enum) {
        enter: struct { output: WlObjectId },
        leave: struct { output: WlObjectId },
        preferred_buffer_scale: struct { factor: i32 },
        preferred_buffer_transform: struct { transform: u32 },
    };
};
comptime {
    std.debug.assert(@intFromEnum(WlSurface.Event.enter) == 0);
    std.debug.assert(@intFromEnum(WlSurface.Event.leave) == 1);
    std.debug.assert(@intFromEnum(WlSurface.Event.preferred_buffer_scale) == 2);
    std.debug.assert(@intFromEnum(WlSurface.Event.preferred_buffer_transform) == 3);
}

pub const WlOutput = struct {
    pub const Event = union(enum) {
        geometry: struct {
            x: i32,
            y: i32,
            physical_width: i32,
            physical_height: i32,
            subpixel: i32,
            make: []const u8,
            model: []const u8,
            transform: i32,
        },
        mode: struct {
            flags: u32,
            width: i32,
            height: i32,
            refresh: i32,
        },
        done: struct {},
        scale: struct { scale: i32 },
        name: struct { name: []const u8 },
        description: struct { desc: []const u8 },
    };
};
comptime {
    std.debug.assert(@intFromEnum(WlOutput.Event.geometry) == 0);
    std.debug.assert(@intFromEnum(WlOutput.Event.mode) == 1);
    std.debug.assert(@intFromEnum(WlOutput.Event.done) == 2);
    std.debug.assert(@intFromEnum(WlOutput.Event.scale) == 3);
    std.debug.assert(@intFromEnum(WlOutput.Event.name) == 4);
    std.debug.assert(@intFromEnum(WlOutput.Event.description) == 5);
}
