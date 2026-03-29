const std = @import("std");
const Canvas = @import("Canvas.zig");
const Color = @import("renderer").Color;
const ToolCommand = @import("commands.zig").ToolCommand;
const ToolKind = @import("tool.zig").Tool;
const PencilTool = @import("tools/PencilTool.zig");
const EraserTool = @import("tools/EraserTool.zig");
const FillTool = @import("tools/FillTool.zig");
const LineTool = @import("tools/LineTool.zig");
const PickerTool = @import("tools/PickerTool.zig");
const RenderContext = @import("renderer").RenderContext;

pub const ToolFns = struct {
    beginFn: *const fn (canvas: *Canvas, x: usize, y: usize, color: Color) void,
    updateFn: *const fn (canvas: *Canvas, x: usize, y: usize, color: Color) void,
    commitFn: *const fn (canvas: *Canvas) ?ToolCommand,
    previewFn: *const fn (canvas: *Canvas, ctx: RenderContext) void,
    cancelFn: *const fn (canvas: *Canvas) void,
};

pub const ToolDispatcher = struct {
    tools: std.EnumArray(ToolKind, ToolFns),

    pub fn init() ToolDispatcher {
        var self: ToolDispatcher = .{
            .tools = std.EnumArray(ToolKind, ToolFns).initUndefined(),
        };
        self.tools.set(.pencil, PencilTool.fns());
        self.tools.set(.erase, EraserTool.fns());
        self.tools.set(.fill, FillTool.fns());
        self.tools.set(.line, LineTool.fns());
        self.tools.set(.picker, PickerTool.fns());

        return self;
    }

    pub fn begin(
        self: ToolDispatcher,
        kind: ToolKind,
        canvas: *Canvas,
        x: usize,
        y: usize,
        color: Color,
    ) void {
        self.tools.get(kind).beginFn(canvas, x, y, color);
    }
    pub fn update(
        self: ToolDispatcher,
        kind: ToolKind,
        canvas: *Canvas,
        x: usize,
        y: usize,
        color: Color,
    ) void {
        self.tools.get(kind).updateFn(canvas, x, y, color);
    }
    pub fn commit(
        self: ToolDispatcher,
        kind: ToolKind,
        canvas: *Canvas,
    ) ?ToolCommand {
        return self.tools.get(kind).commitFn(canvas);
    }
    pub fn preview(
        self: ToolDispatcher,
        kind: ToolKind,
        canvas: *Canvas,
        ctx: RenderContext,
    ) void {
        self.tools.get(kind).previewFn(canvas, ctx);
    }
    pub fn cancel(self: ToolDispatcher, kind: ToolKind, canvas: *Canvas) void {
        self.tools.get(kind).cancelFn(canvas);
    }
};
