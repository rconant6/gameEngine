const std = @import("std");
const Writer = std.Io.Writer;
const ast = @import("ast.zig");
const AssetDeclaration = ast.AssetDeclaration;
const AssetType = ast.AssetType;
const BaseType = ast.BaseType;
const TemplateDeclaration = ast.TemplateDeclaration;
const ComponentDeclaration = ast.ComponentDeclaration;
const Declaration = ast.Declaration;
const EntityDeclaration = ast.EntityDeclaration;
const GenericBlock = ast.GenericBlock;
const Property = ast.Property;
const SceneDeclaration = ast.SceneDeclaration;
const SceneFile = ast.SceneFile;
const SpriteBlock = ast.SpriteBlock;
const TypeAnnotation = ast.TypeAnnotation;
const Value = ast.Value;

const log = @import("debug").log;

const SceneWriteError = error{
    OutOfMemory,
    InvalidFormat,
    WriteFailed,
};
pub fn serialize(scene: *const SceneFile, w: *Writer) SceneWriteError!void {
    return for (scene.decls) |*decl| {
        try writeDeclaration(decl, w, 0);
    };
}

fn writeDeclaration(decl: *const Declaration, w: *Writer, indent: u32) SceneWriteError!void {
    return try switch (decl.*) {
        .scene => |*sd| writeScene(sd, w, indent),
        .asset => |*ad| writeAsset(ad, w, indent),
        .entity => |*ed| writeEntity(ed, w, indent),
        .template => |*td| writeTemplate(td, w, indent),
        .component => |*cd| writeComponent(cd, w, indent),
    };
}
fn writeEntity(decl: *const EntityDeclaration, w: *Writer, indent: u32) SceneWriteError!void {
    try writeIndent(w, indent);
    try w.print(
        "[{s}:entity]\n",
        .{decl.name},
    );
    for (decl.components) |*comp| {
        try writeComponent(comp, w, indent + 1);
    }
}
fn writeScene(s: *const SceneDeclaration, w: *Writer, indent: u32) SceneWriteError!void {
    try writeIndent(w, indent);
    try w.print(
        "[{s}:scene]\n",
        .{s.name},
    );
    for (s.decls) |*decl| {
        try writeDeclaration(decl, w, indent + 1);
    }
}
fn writeTemplate(t: *const TemplateDeclaration, w: *Writer, indent: u32) SceneWriteError!void {
    try writeIndent(w, indent);
    try w.print(
        "[{s}:template]\n",
        .{t.name},
    );
    for (t.components) |*comp| {
        try writeComponent(comp, w, indent + 1);
    }
}
fn writeAsset(a: *const AssetDeclaration, w: *Writer, indent: u32) SceneWriteError!void {
    try writeIndent(w, indent);
    try w.print(
        "[{s}:asset {s}]\n",
        .{ a.name, a.asset_type.toString() },
    );
    if (a.properties) |props| {
        for (props) |*prop| {
            try writeProperty(prop, w, indent + 1);
        }
    }
}
fn writeComponent(c: *const ComponentDeclaration, w: *Writer, indent: u32) SceneWriteError!void {
    try switch (c.*) {
        .generic => |*gb| writeGenericBlock(gb, w, indent),
        .sprite, .collider => |*b| writeSpriteBlock(b, w, indent),
    };
}
fn writeGenericBlock(b: *const GenericBlock, w: *Writer, indent: u32) SceneWriteError!void {
    try writeIndent(w, indent);
    try w.print("[{s}]\n", .{b.name});
    if (b.properties) |props| {
        for (props) |*prop| {
            try writeProperty(prop, w, indent + 1);
        }
    }
    if (b.nested_blocks) |nbs| {
        for (nbs) |*nb| {
            try writeGenericBlock(nb, w, indent + 1);
        }
    }
}
fn writeSpriteBlock(b: *const SpriteBlock, w: *Writer, indent: u32) SceneWriteError!void {
    try writeIndent(w, indent);
    try w.print("[{s}:{s}]\n", .{ b.name, b.shape_type });
    if (b.properties) |props| {
        for (props) |*prop| {
            try writeProperty(prop, w, indent + 1);
        }
    }
}
fn writeProperty(p: *const Property, w: *Writer, indent: u32) SceneWriteError!void {
    try writeIndent(w, indent);
    try w.print(
        "{s}:{f} ",
        .{ p.name, p.type_annotation.base_type },
    );
    try writeValue(&p.value, p.type_annotation.base_type, w);
}
fn writeValue(val: *const Value, base: BaseType, w: *Writer) SceneWriteError!void {
    try switch (base) {
        .vec2 => w.print("{{{d}, {d}}}", .{ val.vector[0], val.vector[1] }),
        .vec3 => w.print(
            "{{{d}, {d}, {d}}}",
            .{ val.vector[0], val.vector[1], val.vector[2] },
        ),
        .f32, .i32, .u32 => w.print("{d}", .{val.number}),
        .bool => w.print("{s}", .{if (val.boolean) "true" else "false"}),
        .string,
        .asset,
        => w.print("\"{s}\"", .{val.string}),
        .color => w.print("#{x:0>6}", .{val.color}),
    };
    try w.print("\n", .{});
}
fn writeIndent(w: *std.Io.Writer, indent: u32) SceneWriteError!void {
    if (indent == 0) return;
    for (0..indent) |_| {
        try w.print("{s}", .{"  "});
    }
}
