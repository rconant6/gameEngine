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

pub const WaylandState = struct {
    // raw c pointers
    display: *c.wl_display,
    registry: *c.wl_registry,
    // proxies hold the pointer
    compositor: BoundObject(WlCompositor),
    xdg_wm_base: BoundObject(XdgWmBase),
    seat: BoundObject(WlSeat),
    output: BoundObject(WlOutput),

    has_pointer: bool = false,
    has_keyboard: bool = false,
    output_info: OutputInfo,
};

pub const WindowState = struct {
    surface: BoundObject(WlSurface),
    xdg_surface: BoundObject(XdgSurface),
    xdg_toplevel: BoundObject(XdgToplevel),

    configure_serial: u32 = 0,
    configured: bool = false,
    should_close: bool = false,
    width: u32,
    height: u32,
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
        self.data[self.event_tail % 64] = e;
        self.tail += 1;
    }
    pub fn popFront(self: *EventRingBuffer) ?Event {
        if (self.head == self.tail) return null;
        const event = self.data[self.head % 64];
        self.head += 1;
        return event;
    }
};
