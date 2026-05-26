const std = @import("std");
const log = @import("debug").log;
const c = @import("c.zig").c;
const consts = @import("consts.zig");
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
const state = @import("state.zig");
const WindowState = state.WindowState;
const WaylandState = state.WaylandState;

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
            if (std.mem.eql(u8, g.interface, consts.wl_compositor)) {
                ws.compositor.name = g.name;
                ws.compositor.version = g.version;
            } else if (std.mem.eql(u8, g.interface, consts.xdg_wm_base)) {
                ws.xdg_wm_base.name = g.name;
                ws.xdg_wm_base.version = g.version;
            } else if (std.mem.eql(u8, g.interface, consts.wl_seat)) {
                ws.seat.name = g.name;
                ws.seat.version = g.version;
            } else if (std.mem.eql(u8, g.interface, consts.wl_output)) {
                ws.output.name = g.name;
                ws.output.version = g.version;
            } else if (std.mem.eql(u8, g.interface, consts.zwp_linux_dmabuf_v1)) {
                ws.dmabuf.name = g.name;
                ws.dmabuf.version = g.version;
            }
        },
        .global_remove => {},
    }
}

pub fn onCompositorEvent(_: WlCompositor.Event, _: *anyopaque) !void {}

pub fn onSeatEvent(event: WlSeat.Event, s_ctx: *anyopaque) !void {
    const ws: *WaylandState = @ptrCast(@alignCast(s_ctx));
    switch (event) {
        .capabilities => |cap| {
            log.info(.platform, "Seat capes: {d}", .{cap.capes});
            ws.has_pointer = (cap.capes & WlSeatCape.pointer) != 0;
            ws.has_keyboard = (cap.capes & WlSeatCape.keyboard) != 0;
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
    const ws: *WaylandState = @ptrCast(@alignCast(s_ctx));
    switch (event) {
        .ping => |p| {
            const xdg_wm_base: *c.xdg_wm_base = @ptrCast(@alignCast(ws.xdg_wm_base.proxy.ptr));
            c.xdg_wm_base_pong(xdg_wm_base, p.serial);
        },
    }
}

pub fn onKeyboardEvent(event: WlKeyboard.Event, s_ctx: *anyopaque) !void {
    _ = s_ctx;
    switch (event) {
        .enter => |ent| log.trace(
            .platform,
            "KB Enter event serial {d}, surf {any}",
            .{ ent.serial, ent.surface },
        ),
        .leave => |l| log.trace(
            .platform,
            "KB Leave event serial {d} surf {any}",
            .{ l.serial, l.surface },
        ),
        .keymap => |km| log.trace(
            .platform,
            "KB Keymap event format {d}",
            .{km.format},
        ),
        .key => |k| log.trace(
            .platform,
            "KB Key event key {d}",
            .{k.key},
        ),
        .modifiers => |mds| log.trace(
            .platform,
            "KB Modifiers event group {d}",
            .{mds.group},
        ),
        .repeat_info => |ri| log.trace(
            .platform,
            "KB Repeat Info event rate {d}",
            .{ri.rate},
        ),
    }
}

pub fn onPointerEvent(event: WlPointer.Event, s_ctx: *anyopaque) !void {
    _ = s_ctx;
    switch (event) {
        .enter => |ent| log.trace(
            .platform,
            "PTR enter event serial {d}, surf {any}",
            .{ ent.serial, ent.surface },
        ),
        .leave => |l| log.trace(
            .platform,
            "PTR leave event serial {d} surf {any}",
            .{ l.serial, l.surface },
        ),
        .button => |b| log.trace(
            .platform,
            "PTR event button {d}",
            .{b.button},
        ),
        .frame => log.trace(
            .platform,
            "PTR frame event",
            .{},
        ),
        else => |e| {
            log.warn(.platform, "PTR event not implemented: {any}", .{e});
        },
    }
}

// MARK: Adding linux DMA-BUF support
pub fn onZwpLinuxDmabuf(_: ZwpLinuxDmabuf.Event, _: *anyopaque) !void {}

pub fn onZwpLInuxDmabufFeedback(event: ZwpLinuxDmabufFeedback.Event, s_ctx: *anyopaque) !void {
    const ws: *WaylandState = @ptrCast(@alignCast(s_ctx));
    switch (event) {
        .format_table => |ft| {
            if (ws.dmafeedback.format_table.len > 0) {
                var raw: [*]align(std.heap.pageSize()) u8 = @ptrCast(
                    @alignCast(@constCast(ws.dmafeedback.format_table.ptr)),
                );
                std.posix.munmap(raw[0..ws.dmafeedback.format_table_mapped_size]);
            }
            const mapped = try std.posix.mmap(
                null,
                ft.size,
                .{ .READ = true },
                .{ .TYPE = .PRIVATE },
                ft.fd,
                0,
            );
            _ = std.c.close(ft.fd);
            const entry_count = ft.size / @sizeOf(state.DmabufFormatEntry);
            ws.dmafeedback.format_table = std.mem.bytesAsSlice(
                state.DmabufFormatEntry,
                mapped,
            )[0..entry_count];
            ws.dmafeedback.format_table_mapped_size = ft.size;
        },
        .main_device => |md| {
            ws.dmafeedback.main_device = std.mem.readInt(u64, md.device.data[0..8], .little);
            log.info(.platform, "DmaBuf main device: {d}", .{ws.dmafeedback.main_device});
        },
        .tranche_target_device => |td| {
            ws.dmafeedback.current_tranche_device = std.mem.readInt(u64, td.device.data[0..8], .little);
        },
        .tranche_flags => |tf| {
            ws.dmafeedback.current_tranche_flags = tf.flags;
        },
        .tranche_formats => {}, // format/modifier done inside vulkan
        .tranche_done => {
            const is_scanout = (ws.dmafeedback.current_tranche_flags & 1) != 0;
            if (!ws.dmafeedback.has_scanout_tranche or is_scanout) {
                ws.dmafeedback.target_device = ws.dmafeedback.current_tranche_device;
                if (is_scanout) ws.dmafeedback.has_scanout_tranche = true;
            }
            ws.dmafeedback.current_tranche_device = 0;
            ws.dmafeedback.current_tranche_flags = 0;
        },
        .done => {
            log.info(.platform, "DmaBuf feedback done, target device: {d}", .{ws.dmafeedback.target_device});
        },
    }
}

// MARK: Window Specific Handlers
pub fn onSurfaceEvent(event: WlSurface.Event, w_ctx: *anyopaque) !void {
    const win: *WindowState = @ptrCast(@alignCast(w_ctx));
    switch (event) {
        .enter => {
            const surf: *c.wl_surface = @ptrCast(@alignCast(win.surface.proxy.ptr));
            c.wl_surface_commit(surf);
        },
        .preferred_buffer_scale => |s| {
            const surf: *c.wl_surface = @ptrCast(@alignCast(win.surface.proxy.ptr));
            c.wl_surface_set_buffer_scale(surf, s.factor);
            c.wl_surface_commit(surf);
        },
        else => |ev| {
            log.warn(.platform, "WlSurface Event {t} is not implemented", .{ev});
        },
    }
}

pub fn onXdgToplevelEvent(event: XdgToplevel.Event, w_ctx: *anyopaque) !void {
    const win: *WindowState = @ptrCast(@alignCast(w_ctx));
    switch (event) {
        .close => win.should_close = true,
        .configure => |cfg| {
            if (cfg.width > 0) win.configured_width = @intCast(cfg.width);
            if (cfg.height > 0) win.configured_height = @intCast(cfg.height);
        },
        .configure_bounds, .wm_capabilites => {},
    }
}

pub fn onXdgSurfaceEvent(event: XdgSurface.Event, w_ctx: *anyopaque) !void {
    const win: *WindowState = @ptrCast(@alignCast(w_ctx));
    switch (event) {
        .configure => |cfg| {
            win.configure_serial = cfg.serial;
            const xdg_surface: *c.xdg_surface = @ptrCast(@alignCast(win.xdg_surface.proxy.ptr));
            c.xdg_surface_ack_configure(xdg_surface, cfg.serial);
            const surf: *c.wl_surface = @ptrCast(@alignCast(win.surface.proxy.ptr));
            c.wl_surface_commit(surf);
        },
    }
}
