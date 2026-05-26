const c = @import("c.zig").c;
const std = @import("std");
const Allocator = std.mem.Allocator;
const faces = @import("interfaces.zig");
const WlCompositor = faces.WlCompositor;
const WlDisplay = faces.WlDisplay;
const WlKeyboard = faces.WlKeyboard;
const WlOutput = faces.WlOutput;
const WlPointer = faces.WlPointer;
const WlRegistry = faces.WlRegistry;
const WlSeat = faces.WlSeat;
const WlSeatCape = faces.WlSeatCape;
const WlSurface = faces.WlSurface;
const XdgSurface = faces.XdgSurface;
const XdgToplevel = faces.XdgToplevel;
const XdgWmBase = faces.XdgWmBase;
const ZwpLinuxDmabuf = faces.ZwpLinuxDmabuf;
const ZwpLinuxDmabufFeedback = faces.ZwpLinuxDmabufFeedback;
const wire = @import("proxy.zig");
const plat = @import("../../platform.zig");
const Event = plat.Event;

pub fn BoundObject(comptime T: type) type {
    return struct {
        name: u32 = 0,
        version: u32 = 0,
        proxy: wire.Proxy(T) = undefined,
    };
}

pub const OutputInfo = struct {
    width: i32 = 0,
    height: i32 = 0,
    refresh: i32 = 0,
    scale: i32 = 0,
};

pub const DmabufFormatEntry = extern struct {
    format: u32,
    padding: u32,
    modifier: u64,
};

pub const DmabufFeedback = struct {
    // Resolved feedback — populated after the done event
    main_device: u64 = 0,
    target_device: u64 = 0,
    format_table: []const DmabufFormatEntry = &.{},
    format_table_mapped_size: usize = 0,

    // Transient state accumulated across a single tranche
    current_tranche_device: u64 = 0,
    current_tranche_flags: u32 = 0,
    has_scanout_tranche: bool = false,
};

pub const WaylandState = struct {
    // raw c pointers
    display: *c.wl_display,
    registry: *c.wl_registry,
    // proxies hold the pointer
    compositor: BoundObject(WlCompositor),
    dmabuf: BoundObject(ZwpLinuxDmabuf),
    xdg_wm_base: BoundObject(XdgWmBase),
    seat: BoundObject(WlSeat),
    output: BoundObject(WlOutput),
    keyboard: BoundObject(WlKeyboard) = .{},

    has_pointer: bool = false,
    has_keyboard: bool = false,
    output_info: OutputInfo = .{},
    dmafeedback: DmabufFeedback = .{},
    active_events: ?*EventRingBuffer = null,
};

pub const WindowState = struct {
    surface: BoundObject(WlSurface),
    xdg_surface: BoundObject(XdgSurface),
    xdg_toplevel: BoundObject(XdgToplevel),
    dmabuf_feedback: wire.Proxy(ZwpLinuxDmabufFeedback) = undefined,

    configure_serial: u32 = 0,
    configured: bool = false,
    should_close: bool = false,
    width: u32,
    height: u32,
    configured_width: u32 = 0,
    configured_height: u32 = 0,
    events: EventRingBuffer,
};

pub const EventRingBuffer = struct {
    alloc: Allocator,
    head: usize = 0,
    tail: usize = 0,
    max: usize = 64,
    data: []Event,

    pub fn init(alloc: Allocator) !EventRingBuffer {
        return .{
            .alloc = alloc,
            .data = try alloc.alloc(Event, 64),
        };
    }

    pub fn deinit(self: *EventRingBuffer) void {
        self.alloc.free(self.data);
    }

    pub fn push(self: *EventRingBuffer, e: Event) void {
        self.data[self.tail % 64] = e;
        self.tail += 1;
    }
    pub fn popFront(self: *EventRingBuffer) ?Event {
        if (self.head == self.tail) return null;
        const event = self.data[self.head % 64];
        self.head += 1;
        return event;
    }
};
