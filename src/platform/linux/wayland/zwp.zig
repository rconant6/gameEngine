const std = @import("std");
const wl = @import("wl.zig");
const WlArray = wl.WlArray;

pub const ZwpLinuxDmabuf_v1 = struct {
    pub const Event = union(enum) {
        format: struct { format: u32 },
        modifier: struct {
            format: u32,
            modifier_hi: u32,
            modifier_lo: u32,
        },
    };
};
comptime {
    std.debug.assert(@intFromEnum(ZwpLinuxDmabuf_v1.Event.format) == 0);
    std.debug.assert(@intFromEnum(ZwpLinuxDmabuf_v1.Event.modifier) == 1);
}

pub const ZwpLinuxBufferParams_v1 = struct {
    pub const Event = union(enum) {
        created: struct { buffer: u32 },
        failed: struct {},
    };
};
comptime {
    std.debug.assert(@intFromEnum(ZwpLinuxBufferParams_v1.Event.created) == 0);
    std.debug.assert(@intFromEnum(ZwpLinuxBufferParams_v1.Event.failed) == 1);
}

pub const ZwpLinuxDmabufFeedback_v1 = struct {
    pub const Event = union(enum) {
        done: struct {},
        format_table: struct {
            fd: i32,
            size: u32,
        },
        main_device: struct { device: WlArray },
        tranche_done: struct {},
        tranche_target_device: struct { device: WlArray },
        tranche_formats: struct { indices: WlArray },
        tranche_flags: struct { flags: u32 },
    };
};
comptime {
    std.debug.assert(@intFromEnum(ZwpLinuxDmabufFeedback_v1.Event.done) == 0);
    std.debug.assert(@intFromEnum(ZwpLinuxDmabufFeedback_v1.Event.format_table) == 1);
    std.debug.assert(@intFromEnum(ZwpLinuxDmabufFeedback_v1.Event.main_device) == 2);
    std.debug.assert(@intFromEnum(ZwpLinuxDmabufFeedback_v1.Event.tranche_done) == 3);
    std.debug.assert(@intFromEnum(ZwpLinuxDmabufFeedback_v1.Event.tranche_target_device) == 4);
    std.debug.assert(@intFromEnum(ZwpLinuxDmabufFeedback_v1.Event.tranche_formats) == 5);
    std.debug.assert(@intFromEnum(ZwpLinuxDmabufFeedback_v1.Event.tranche_flags) == 6);
}
