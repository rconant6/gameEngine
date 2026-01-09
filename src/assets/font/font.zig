const std = @import("std");
const font_data = @import("font_data.zig");
const CmapEncoding = font_data.CmapEncoding;
const CmapFormat4Header = font_data.CmapFormat4Header;
const CmapHeader = font_data.CmapHeader;
const FilteredGlyph = font_data.FilteredGlyph;
const FontDirHeader = font_data.FontDirHeader;
const GlyfHeader = font_data.GlyfHeader;
const GlyphFlag = font_data.GlyphFlag;
const HeadTable = font_data.HeadTable;
const HheaTable = font_data.HheaTable;
const Hmetric = font_data.Hmetric;
const MaxPTable = font_data.MaxPTable;
const TableEntry = font_data.TableEntry;
const V2 = font_data.V2;

const FontReader = @import("FontReader.zig").FontReader;

fn loadFile(alloc: std.mem.Allocator, path: []const u8) ![]const u8 {
    const file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const raw_data = try alloc.alloc(u8, file_size);
    const data_read = try file.readAll(raw_data);
    std.debug.assert(data_read == file_size);

    return raw_data;
}

fn parseFontDir(reader: *FontReader) !FontDirHeader {
    const header = reader.readStruct(FontDirHeader);
    reader.rewind(getBytesOfPadding(FontDirHeader));
    return header;
}

fn parseTableEntry(reader: *FontReader) !TableEntry {
    const table_entry = reader.readStruct(TableEntry);
    reader.rewind(getBytesOfPadding(TableEntry));
    return table_entry;
}

fn parseLocaTable(reader: *FontReader, alloc: *std.mem.Allocator, entry: TableEntry, numGlyphs: u16) ![]u32 {
    reader.seek(entry.offset);

    const actual_checksum = reader.calculateChecksum(entry.offset, entry.length, false);
    if (actual_checksum != entry.checksum) return error.LocaTableCorrupted;

    var offsets = try alloc.alloc(u32, numGlyphs + 1);
    for (0..numGlyphs + 1) |i| {
        const short_offset = reader.readU16BigEndian();
        offsets[i] = @as(u32, short_offset) * 2; // Convert to actual byte offset
    }

    return offsets;
}

fn parseHeadTable(reader: *FontReader, entry: TableEntry) !HeadTable {
    reader.seek(entry.offset);

    std.debug.assert(entry.offset + entry.length <= reader.remaining());

    const head_table = reader.readStruct(HeadTable);

    const actual_checksum = reader.calculateChecksum(entry.offset, entry.length, true);
    if (actual_checksum != entry.checksum) return error.HeadTableCorrupted;
    if (head_table.magic_number != 0x5f0f3cf5) return error.InvalidTTFMagicNumber;

    reader.rewind(getBytesOfPadding(HeadTable));

    return head_table;
}

fn parseHheaTable(reader: *FontReader, entry: TableEntry) !HheaTable {
    reader.seek(entry.offset);

    std.debug.assert(entry.offset + entry.length <= reader.remaining());

    const hhea_table = reader.readStruct(HheaTable);

    const actual_checksum = reader.calculateChecksum(entry.offset, entry.length, false);
    if (actual_checksum != entry.checksum) return error.HheaTableCorrupted;

    reader.rewind(getBytesOfPadding(HheaTable));

    return hhea_table;
}

fn parseHmetrics(
    reader: *FontReader,
    metrics: *std.ArrayList(Hmetric),
    entry: TableEntry,
    number_of_glyphs: u16,
    number_of_hMetrics: u16,
) !void {
    reader.seek(entry.offset);

    std.debug.assert(entry.offset + entry.length <= reader.remaining());

    const actualChecksum = reader.calculateChecksum(entry.offset, entry.length, false);
    if (actualChecksum != entry.checksum) return error.HmtxTableCorrupted;

    for (0..number_of_hMetrics) |_| {
        const hMetric = reader.readStruct(Hmetric);
        reader.rewind(getBytesOfPadding(Hmetric));
        metrics.appendAssumeCapacity(hMetric);
    }

    const remaining_glyphs = number_of_glyphs - number_of_hMetrics;
    for (0..remaining_glyphs) |_| {
        const lsb = reader.readI16BigEndian();
        metrics.appendAssumeCapacity(Hmetric{
            .advance_width = metrics.items[number_of_hMetrics - 1].advance_width,
            .lsb = lsb,
        });
    }
}

fn parseMaxpTable(reader: *FontReader, entry: TableEntry) !MaxPTable {
    reader.seek(entry.offset);

    std.debug.assert(entry.offset + entry.length <= reader.remaining());

    const actual_checksum = reader.calculateChecksum(entry.offset, entry.length, false);
    if (actual_checksum != entry.checksum) return error.MaxPTableCorrupted;

    const maxp_table = reader.readStruct(MaxPTable);
    reader.rewind(getBytesOfPadding(MaxPTable));

    return maxp_table;
}

fn parseCmapTable(reader: *FontReader, entry: TableEntry) !CmapFormat4Header {
    reader.seek(entry.offset);

    std.debug.assert(entry.offset + entry.length <= reader.remaining());

    const actual_checksum = reader.calculateChecksum(entry.offset, entry.length, false);
    if (actual_checksum != entry.checksum) return error.CmapTableCorrupted;

    const cmap_header = reader.readStruct(CmapHeader);
    reader.rewind(getBytesOfPadding(CmapHeader));

    const cmap_encoding = find_encoding: {
        var fallback: ?CmapEncoding = null;
        for (0..cmap_header.num_tables) |_| {
            const encoding = reader.readStruct(CmapEncoding);
            reader.rewind(getBytesOfPadding(CmapEncoding));
            if (encoding.platform_id == 3 and encoding.encoding_id == 1) {
                break :find_encoding encoding; // Prefer this
            }
            if (encoding.platform_id == 0 and encoding.encoding_id == 3) {
                fallback = encoding; // But accept this
            }
        }
        break :find_encoding fallback orelse return error.NoValidCmapEncoding;
    };

    reader.seek(entry.offset + cmap_encoding.offset);

    const cmap_format4_header = reader.readStruct(CmapFormat4Header);
    reader.rewind(getBytesOfPadding(CmapFormat4Header));

    return cmap_format4_header;
}

fn parseCmapFormatData(
    reader: *FontReader,
    map: *std.AutoHashMap(u32, u16),
    alloc: std.mem.Allocator,
    header: CmapFormat4Header,
) !void {
    const num_segments: u16 = header.seg_countx2 / 2;

    var end_counts = try alloc.alloc(u16, num_segments);
    var start_counts = try alloc.alloc(u16, num_segments);
    var id_deltas = try alloc.alloc(u16, num_segments);
    var id_range_offsets = try alloc.alloc(u16, num_segments);
    for (0..num_segments) |segment| {
        end_counts[segment] = reader.readU16BigEndian();
    }
    const pad = reader.readU16BigEndian();
    std.debug.assert(pad == 0);
    for (0..num_segments) |segment| {
        start_counts[segment] = reader.readU16BigEndian();
    }
    for (0..num_segments) |segment| {
        id_deltas[segment] = reader.readU16BigEndian();
    }
    for (0..num_segments) |segment| {
        id_range_offsets[segment] = reader.readU16BigEndian();
    }

    const glyph_array_size = header.length - (14 + num_segments * 2 * 4 + 2); // header, data, pad
    const glyphs = glyph_array_size / 2;
    var glyph_id_array = try alloc.alloc(u16, glyphs);
    for (0..glyphs) |glyph_id| {
        glyph_id_array[glyph_id] = reader.readU16BigEndian();
    }

    for (0..0x10000) |char| {
        var segment: usize = 0;
        while (segment < num_segments) : (segment += 1) {
            const start = start_counts[segment];
            const end = end_counts[segment];
            if (start <= char and char <= end) break;
        }

        if (segment >= num_segments) {
            continue;
        }

        var glyph_index: u16 = 0;
        if (id_range_offsets[segment] == 0) {
            glyph_index = @as(u16, @intCast(char)) +% id_deltas[segment];
        } else {
            const array_index = (id_range_offsets[segment] / 2) + (char - start_counts[segment]) - (num_segments - segment);

            if (array_index < glyph_id_array.len) {
                const glyph_id = glyph_id_array[array_index];
                glyph_index = glyph_id +% id_deltas[segment];
            }
        }

        try map.put(@as(u32, @intCast(char)), glyph_index);
    }
}

fn parseGlyph(
    reader: *FontReader,
    alloc: std.mem.Allocator, // main engine allocator
    temp_arena: std.mem.Allocator, // temp arena
    header: GlyfHeader,
    units_per_em: u16,
) !FilteredGlyph {
    const number_of_contours: u16 = if (header.number_of_contours < 0) 0 else @intCast(header.number_of_contours);
    if (header.number_of_contours > 0) {
        var contour_end_pts = try temp_arena.alloc(u16, number_of_contours);
        for (0..number_of_contours) |i| {
            contour_end_pts[i] = reader.readU16BigEndian();
        }

        const total_points = contour_end_pts[number_of_contours - 1] + 1;

        const instruction_len = reader.readU16BigEndian();
        reader.skip(instruction_len);

        var flags = try temp_arena.alloc(GlyphFlag, total_points);
        var flag_index: usize = 0;

        while (flag_index < total_points) {
            const rawFlag = reader.readU8();
            const flag: GlyphFlag = @bitCast(rawFlag);
            flags[flag_index] = flag;
            flag_index += 1;

            if (flag.repeat != 0) {
                const repeat_count = reader.readU8();
                for (0..repeat_count) |_| {
                    if (flag_index >= total_points) break;
                    flags[flag_index] = flag;
                    flag_index += 1;
                }
            }
        }

        var x_coords = try temp_arena.alloc(i32, total_points);
        var y_coords = try temp_arena.alloc(i32, total_points);

        // Parse X coordinates
        for (0..total_points) |i| {
            if (flags[i].xShort == 1) {
                const delta = reader.readU8();
                x_coords[i] = if (flags[i].x_same_or_pos == 1) @as(i32, delta) else -@as(i32, delta);
            } else if (flags[i].x_same_or_pos == 1) {
                x_coords[i] = 0; // Same as previous
            } else {
                x_coords[i] = reader.readI16BigEndian();
            }
        }

        // Parse Y coordinates
        for (0..total_points) |i| {
            if (flags[i].yShort == 1) {
                const delta = reader.readU8();
                y_coords[i] = if (flags[i].y_same_or_pos == 1) @as(i32, delta) else -@as(i32, delta);
            } else if (flags[i].y_same_or_pos == 1) {
                y_coords[i] = 0; // Same as previous
            } else {
                y_coords[i] = reader.readI16BigEndian();
            }
        }

        var absX: i32 = 0;
        var absY: i32 = 0;
        var filtered_contour_end_pts = try std.ArrayList(u16).initCapacity(alloc, contour_end_pts.len);
        errdefer filtered_contour_end_pts.deinit(alloc);
        var filtered_points = try std.ArrayList(V2).initCapacity(alloc, total_points);
        errdefer filtered_points.deinit(alloc);
        var filtered_point_count: u16 = 0;
        var filtered_index: usize = 0;
        for (0..total_points) |i| {
            absX += x_coords[i];
            absY += y_coords[i];

            if (flags[i].on_curve == 1) {
                const fx: f32 = @floatFromInt(absX);
                const fy: f32 = @floatFromInt(absY);
                const fEm: f32 = @floatFromInt(units_per_em);

                const normX = fx / fEm;
                const normY = fy / fEm;

                filtered_points.appendAssumeCapacity(V2{ .x = normX, .y = normY });
                filtered_point_count += 1;
                filtered_index += 1;
            }

            for (contour_end_pts) |endPt| {
                if (i == endPt) {
                    filtered_contour_end_pts.appendAssumeCapacity(filtered_point_count - 1);
                    break; // Only match once per point
                }
            }
        }

        const points_slice = try filtered_points.toOwnedSlice(alloc);
        const contour_slice = try filtered_contour_end_pts.toOwnedSlice(alloc);
        return FilteredGlyph{
            .points = points_slice,
            .contour_ends = contour_slice,
            .contour_count = number_of_contours,
            .total_points = filtered_point_count,
        };
    }
    return FilteredGlyph{};
}

pub const Font = struct {
    alloc: std.mem.Allocator,
    units_per_em: u16 = undefined, // from head

    // from hhea table
    ascender: i16 = undefined,
    descender: i16 = undefined,
    line_gap: i16 = undefined,

    char_to_glyph: std.AutoHashMap(u32, u16) = undefined, // from cmap
    glyph_advance_width: std.ArrayList(Hmetric) = undefined, // horizontal spacing data
    glyph_shapes: std.AutoHashMap(u16, FilteredGlyph) = undefined, // data for shapes of glyphs
    glyph_triangles: std.AutoHashMap(u16, [][3]usize),

    pub fn init(alloc: std.mem.Allocator, path: []const u8) !Font {
        var arena = std.heap.ArenaAllocator.init(alloc);
        defer arena.deinit();

        var temp_alloc = arena.allocator();
        var table_directory = std.AutoArrayHashMap(u32, TableEntry).init(temp_alloc);

        const raw_data = try loadFile(temp_alloc, path);

        var reader = FontReader{ .data = raw_data };

        const font_dir_header = try parseFontDir(&reader);
        const number_tables = font_dir_header.num_tables;
        for (0..number_tables) |_| {
            const table_entry = try parseTableEntry(&reader);
            try table_directory.put(table_entry.tag, table_entry);
        }

        const head_entry = getTable(&table_directory, "head") orelse return error.HeadTableNotFound;
        const head_table = try parseHeadTable(&reader, head_entry);
        const index_to_loc = head_table.index_to_loc_format;
        const units_per_em = head_table.units_per_em;
        _ = index_to_loc;

        const maxp_entry = getTable(&table_directory, "maxp") orelse return error.MaxpTableNotFound;
        const maxp_table = try parseMaxpTable(&reader, maxp_entry);
        const number_glyphs = maxp_table.num_glyphs;

        const hhea_entry = getTable(&table_directory, "hhea") orelse return error.HheaTableNotFound;
        const hhea_table = try parseHheaTable(&reader, hhea_entry);
        const number_hMetrics = hhea_table.number_hMetrics;

        const hmtx_entry = getTable(&table_directory, "hmtx") orelse return error.HmtxTableNotFound;
        var hMetrics = try std.ArrayList(Hmetric).initCapacity(alloc, number_glyphs);
        errdefer hMetrics.deinit(alloc);
        try parseHmetrics(&reader, &hMetrics, hmtx_entry, number_glyphs, number_hMetrics);

        const cmap_entry = getTable(&table_directory, "cmap") orelse return error.CmapTableNotFound;
        const cmap_format4_header = try parseCmapTable(&reader, cmap_entry);
        var map_indicies = std.AutoHashMap(u32, u16).init(alloc);
        errdefer map_indicies.deinit();
        try parseCmapFormatData(&reader, &map_indicies, temp_alloc, cmap_format4_header);

        const glyph_entry = getTable(&table_directory, "glyf") orelse return error.GlyfTableNotFound;

        const loca_entry = getTable(&table_directory, "loca") orelse return error.LocaTableNotFound;
        const offsets = try parseLocaTable(&reader, &temp_alloc, loca_entry, number_glyphs);

        var glyphs = std.AutoHashMap(u16, FilteredGlyph).init(alloc);
        errdefer glyphs.deinit();
        for (0..number_glyphs) |glyphIndex| {
            const start = offsets[glyphIndex];
            const end = offsets[glyphIndex + 1];
            if (start == end) continue; // Skip empty glyphs

            reader.seek(glyph_entry.offset + start);
            const header = reader.readStruct(GlyfHeader);
            reader.rewind(getBytesOfPadding(GlyfHeader));

            const glyph_data = try parseGlyph(&reader, alloc, temp_alloc, header, units_per_em);
            try glyphs.put(@intCast(glyphIndex), glyph_data);
        }

        return Font{
            .alloc = alloc,
            .units_per_em = units_per_em,
            .ascender = hhea_table.ascender,
            .descender = hhea_table.descender,
            .line_gap = hhea_table.line_gap,
            .char_to_glyph = map_indicies,
            .glyph_advance_width = hMetrics,
            .glyph_shapes = glyphs,
            .glyph_triangles = std.AutoHashMap(u16, [][3]usize).init(alloc),
        };
    }

    pub fn deinit(self: *Font) void {
        self.glyph_advance_width.deinit(self.alloc);
        self.char_to_glyph.deinit();
        var iter = self.glyph_shapes.iterator();
        while (iter.next()) |entry| {
            const glyph = entry.value_ptr.*;
            self.alloc.free(glyph.points);
            self.alloc.free(glyph.contour_ends);
        }
        self.glyph_shapes.deinit();
        var tri_iter = self.glyph_triangles.iterator();
        while (tri_iter.next()) |entry| {
            self.alloc.free(entry.value_ptr.*);
        }
        self.glyph_triangles.deinit();
    }
};

// MARK: Helpers
fn getBytesOfPadding(comptime T: type) usize {
    return switch (T) {
        HheaTable => 96 / 8,
        CmapFormat4Header => 16 / 8,
        HeadTable => 80 / 8,
        FontDirHeader => 32 / 8,
        GlyfHeader => 48 / 8,
        else => 0,
    };
}

fn getTable(tables: *const std.AutoArrayHashMap(u32, TableEntry), name: []const u8) ?TableEntry {
    const tag = std.mem.readInt(u32, name[0..4], .big);
    return tables.get(tag);
}

fn printData(comptime T: type, value: T, label: []const u8) void {
    std.debug.print("{s}\n", .{label});
    inline for (@typeInfo(T).@"struct".fields) |field| {
        std.debug.print("{s}: {any}\n", .{ field.name, @field(value, field.name) });
    }
}
