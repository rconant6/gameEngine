const std = @import("std");
const log = @import("debug").log;
const wlProt = @import("consts.zig");
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
const state = @import("state.zig");
const WindowState = state.WindowState;
const BoundObject = state.BoundObject;
const WaylandState = state.WaylandState;
const OuputInfo = state.OutputInfo;

// MARK: State Specific Handlers
pub fn onDisplayEvent(event: WlDisplay.Event, ctx: *anyopaque) !void {
    _ = ctx;
    switch (event) {
        .err => |e| {
            log.err(
                .platform,
                "wl_display error: obj: {d} code: {d} msg: {s}",
                .{ e.object_id, e.code, e.msg },
            );
            return error.WaylandProtocolError;
        },
        .delete_id => {},
    }
}

pub fn onRegistryEvent(event: WlRegistry.Event, s_ctx: *anyopaque) !void {
    const ws: *WaylandState = @ptrCast(@alignCast(s_ctx));
    switch (event) {
        .global => |g| {
            log.info(
                .platform,
                "GLOBAL: {d}  {s}  v:{}",
                .{ g.name, g.interface, g.version },
            );
            if (std.mem.eql(u8, g.interface, wlProt.wl_compositor)) {
                ws.compositor.name = g.name;
                ws.compositor.version = g.version;
            } else if (std.mem.eql(u8, g.interface, wlProt.xdg_wm_base)) {
                ws.xdg_wm_base.name = g.name;
                ws.xdg_wm_base.version = g.version;
            } else if (std.mem.eql(u8, g.interface, wlProt.wl_seat)) {
                ws.seat.name = g.name;
                ws.seat.version = g.version;
            } else if (std.mem.eql(u8, g.interface, wlProt.wl_output)) {
                ws.output.name = g.name;
                ws.output.version = g.version;
            }
        },
        .global_remove => {},
    }
}

pub fn onCompositorEvent(event: WlCompositor.Event, ctx: *anyopaque) !void {
    _ = ctx;
    switch (event) {}
    return;
}

pub fn onSeatEvent(event: WlSeat.Event, s_ctx: *anyopaque) !void {
    const ws: *WaylandState = @ptrCast(@alignCast(s_ctx));
    switch (event) {
        .capabilities => |c| {
            log.info(.platform, "Seat capes: {d}", .{c.capes});
            ws.has_pointer = (c.capes & WlSeatCape.pointer) != 0;
            ws.has_keyboard = (c.capes & WlSeatCape.keyboard) != 0;
            // ws.has_touch = (c.capes & SeatCap.touch) != 0;
        },
        .name => |s| log.info(.platform, "Seat name: {s}", .{s.name}),
    }
}

pub fn onOutputEvent(event: WlOutput.Event, s_ctx: *anyopaque) !void {
    const ws: *WaylandState = @ptrCast(@alignCast(s_ctx));
    switch (event) {
        .geometry => |g| {
            log.info(
                .platform,
                "output geometry: {d}x{d} mm, make={s} model={s}",
                .{ g.physical_width, g.physical_height, g.make, g.model },
            );
        },
        .mode => |m| {
            ws.output_info.width = m.width;
            ws.output_info.height = m.height;
            ws.output_info.refresh = m.refresh;
            log.info(
                .platform,
                "output mode: {d}x{d} @ {d}mHz",
                .{ m.width, m.height, m.refresh },
            );
        },
        .scale => |s| {
            ws.output_info.scale = s.scale;
            log.info(.platform, "output scale: {d}", .{ws.output_info.scale});
        },
        .name, .description => {},
        .done => {},
    }
}

pub fn onXdgWmBaseEvent(event: XdgWmBase.Event, s_ctx: *anyopaque) !void {
    _ = s_ctx;
    switch (event) {
        .ping => |p| log.trace(.platform, "XdgBase PING serial: {d}", .{p.serial}),
    }
}

pub fn onKeyboardEvent(event: WlKeyboard.Event, s_ctx: *anyopaque) !void {
    _ = s_ctx;
    switch (event) {
        .enter => |ent| log.trace(.platform, "KB Enter event serial {d}, surf {d}", .{ ent.serial, ent.surface }),
        .leave => |l| log.trace(.platform, "KB Leave event serial {d} surf {d}", .{ l.serial, l.surface }),
        .keymap => |km| log.trace(.platform, "KB Keymap event format {d}", .{km.format}),
        .key => |k| log.trace(.platform, "KB Key event key {d}", .{k.key}),
        .modifiers => |mds| log.trace(.platform, "KB Modifiers event group {d}", .{mds.group}),
        .repeat_info => |ri| log.trace(.platform, "KB Repeat Info event rate {d}", .{ri.rate}),
    }
}
pub fn onPointerEvent(event: WlPointer.Event, s_ctx: *anyopaque) !void {
    _ = s_ctx;
    switch (event) {
        .enter => |ent| log.trace(.platform, "PTR enter event serial {d}, surf {d}", .{ ent.serial, ent.surface }),
        .leave => |l| log.trace(.platform, "PTR leave event serial {d} surf {d}", .{ l.serial, l.surface }),
        .button => |b| log.trace(.platform, "PTR event button {d}", .{b.button}),
        .frame => log.trace(.platform, "PTR frame event", .{}),
        else => |e| {
            log.warn(.platform, "PTR event not implemented: {any}", .{e});
        },
    }
}

// MARK: Window Specific Handlers
pub fn onSurfaceEvent(event: WlSurface.Event, w_ctx: *anyopaque) !void {
    const win: *WindowState = @ptrCast(@alignCast(w_ctx));
    _ = win;
    switch (event) {
        else => {
            log.warn(.platform, "WlSurface Events are not handled", .{});
        },
    }
}

pub fn onXdgToplevelEvent(event: XdgToplevel.Event, w_ctx: *anyopaque) !void {
    const win: *WindowState = @ptrCast(@alignCast(w_ctx));
    _ = win;

    switch (event) {
        else => {
            log.warn(.platform, "XdgTopLevelEvents are not handled", .{});
        },
    }
}

pub fn onXdgSurfaceEvent(event: XdgSurface.Event, w_ctx: *anyopaque) !void {
    const win: *WindowState = @ptrCast(@alignCast(w_ctx));

    switch (event) {
        .configure => |c| {
            log.trace(.platform, "XdgSurface CONFIG serial: {d}", .{c.serial});
            win.configure_serial = c.serial;
        },
    }
}
