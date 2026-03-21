const std = @import("std");
const ViewMap = std.StringArrayHashMapUnmanaged(RegionConfig);
const WidgetNode = @import("widgets/WidgetNode.zig");
const UIManager = @import("UIManager.zig");
const Event = @import("event.zig").Event;
const rend = @import("renderer");
const Renderer = rend.Renderer;
const RenderContext = rend.RenderContext;
const assets = @import("assets");
const Font = assets.Font;
const WidgetState = @import("widgetState.zig").WidgetState;
const db = @import("debug");
const log = db.log;

pub const Region = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};
pub const BuildFn = *const fn (std.mem.Allocator, ?*const anyopaque) *WidgetNode;

const RegionConfig = struct {
    layout: Region,
    builder: BuildFn,
    manager: UIManager,
    interactive: bool = true,
};

pub const UILayer = struct {
    views: ViewMap,
    gpa: std.mem.Allocator,

    pub fn addView(
        self: *UILayer,
        name: []const u8,
        layout: Region,
        builder: BuildFn,
        opts: struct { interactive: bool = true },
    ) void {
        self.views.put(self.gpa, name, .{
            .layout = layout,
            .builder = builder,
            .manager = UIManager.init(self.gpa),
            .interactive = opts.interactive,
        }) catch |err| {
            log.err(.ui, "Unable to add view {s}: {any}", .{ name, err });
        };
    }

    pub fn update(
        self: *UILayer,
        state: ?*const anyopaque,
        mouse_x: f32,
        mouse_y: f32,
        left_down: bool,
        left_up: bool,
    ) void {
        for (self.views.values()) |*view| {
            view.manager.rebuild();
            const root = view.builder(view.manager.allocator(), state);
            view.manager.setRoot(root);
            view.manager.layoutAt(
                view.layout.x,
                view.layout.y,
                view.layout.width,
                view.layout.height,
            );
            if (view.interactive) {
                view.manager.processInput(mouse_x, mouse_y, left_down, left_up);
            }
        }
    }

    pub fn render(self: *UILayer, renderer: *Renderer, font: *const Font, rctx: RenderContext) void {
        for (self.views.values()) |*view| {
            view.manager.render(renderer, font, rctx);
        }
    }

    pub fn getState(self: *UILayer, view_name: []const u8, widget_id: []const u8) ?*WidgetState {
        const region = self.views.get(view_name) orelse return null;
        return region.manager.getState(widget_id);
    }

    pub fn allocator(self: *const UILayer) std.mem.Allocator {
        return self.gpa;
    }
    pub fn init(alloc: std.mem.Allocator) UILayer {
        return .{
            .views = .empty,
            .gpa = alloc,
        };
    }
    pub fn deinit(self: *UILayer) void {
        for (self.views.values()) |*v| v.manager.deinit();
        self.views.deinit(self.gpa);
    }
};
