const std = @import("std");
const types = @import("types.zig");
const Hue = types.Hue;
const Tone = types.Tone;
const Saturation = types.Saturation;
const Temperature = types.Temperature;
const Family = types.Family;
const TaggedColor = types.TaggedColor;
const Color = @import("Color.zig").Color;
pub const Colors = @import("Colors.zig");

pub const ColorLibrary = struct {
    // NOTE: do i really want this exposed?
    pub fn getAllColors() []const TaggedColor {
        return &entries;
    }
    pub fn getHue(h: Hue) []const TaggedColor {
        return hue_buckets[@intFromEnum(h)];
    }
    pub fn getTone(t: Tone) []const TaggedColor {
        return tone_buckets[@intFromEnum(t)];
    }
    pub fn getSat(s: Saturation) []const TaggedColor {
        return sat_buckets[@intFromEnum(s)];
    }
    pub fn getTemp(t: Temperature) []const TaggedColor {
        return temp_buckets[@intFromEnum(t)];
    }
    pub fn getHueTone(h: Hue, t: Tone) []const TaggedColor {
        const hue_colors = getHue(h);

        var start: usize = 0;
        var found = false;
        var end: usize = 0;

        for (hue_colors, 0..) |entry, i| {
            if (entry.tone == t) {
                if (!found) {
                    start = i;
                    found = true;
                }
                end = i + 1;
            } else if (found) {
                break;
            }
        }
        return if (found) hue_colors[start..end] else &[_]TaggedColor{};
    }
    pub fn getHueToneSat(h: Hue, t: Tone, s: Saturation) []const TaggedColor {
        const hue_tones = getHueTone(h, t);

        var start: usize = 0;
        var found = false;
        var end: usize = 0;

        for (hue_tones, 0..) |entry, i| {
            if (entry.saturation == s) {
                if (!found) {
                    start = i;
                    found = true;
                }
                end = i + 1;
            } else if (found) {
                break;
            }
        }
        return if (found) hue_tones[start..end] else &[_]TaggedColor{};
    }

    pub fn findByName(name: []const u8) ?TaggedColor {
        for (entries) |entry| {
            if (std.ascii.eqlIgnoreCase(name, entry.name)) return entry;
        }
        return null;
    }
    pub fn findByColor(c: Color) ?TaggedColor {
        for (entries) |entry| {
            const entry_rgba = entry.color.rgba;
            if (entry_rgba.r == c.rgba.r and
                entry_rgba.g == c.rgba.g and
                entry_rgba.b == c.rgba.b and
                entry_rgba.a == c.rgba.a)
                return entry;
        }
        return null;
    }

    pub fn getColorCount() usize {
        return entries.len;
    }
    pub fn getHueCount(h: Hue) usize {
        return hue_buckets[@intFromEnum(h)].len;
    }
    pub fn getToneCount(t: Tone) usize {
        return tone_buckets[@intFromEnum(t)].len;
    }
    pub fn getSatCount(s: Saturation) usize {
        return sat_buckets[@intFromEnum(s)].len;
    }
    pub fn getTempCount(t: Temperature) usize {
        return temp_buckets[@intFromEnum(t)].len;
    }

    const count = blk: {
        @setEvalBranchQuota(2000);
        var c = 0;
        for (@typeInfo(Colors).@"struct".decls) |decl| {
            if (@TypeOf(@field(Colors, decl.name)) == Color) c += 1;
        }
        break :blk c;
    };
    const entries: [count]TaggedColor = blk: {
        @setEvalBranchQuota(30000);
        var data: [count]TaggedColor = undefined;
        var i = 0;
        for (@typeInfo(Colors).@"struct".decls) |decl| {
            const val = @field(Colors, decl.name);
            if (@TypeOf(val) == Color) {
                data[i] = TaggedColor.from(val, decl.name);
                i += 1;
            }
        }
        break :blk data;
    };
    pub const hue_buckets = createBuckets(Hue, "hue", entries_by_hue);
    pub const tone_buckets = createBuckets(Tone, "tone", entries_by_tone);
    pub const sat_buckets = createBuckets(Saturation, "saturation", entries_by_sat);
    pub const temp_buckets = createBuckets(Temperature, "temp", entries_by_temp);
    fn createBuckets(
        comptime Tag: type,
        comptime field: []const u8,
        comptime sorted_data: anytype,
    ) [std.enums.values(Tag).len][]const TaggedColor {
        @setEvalBranchQuota(50000);
        const T = TaggedColor;
        const len = std.enums.values(Tag).len;
        var buckets: [len][]const T = undefined;

        for (std.enums.values(Tag)) |t| {
            var start: usize = 0;
            var found = false;
            var end: usize = 0;

            for (sorted_data, 0..) |entry, i| {
                if (@field(entry, field) == t) {
                    if (!found) {
                        start = i;
                        found = true;
                    }
                    end = i + 1;
                }
            }
            buckets[@intFromEnum(t)] = if (found) sorted_data[start..end] else &[_]T{};
        }
        return buckets;
    }

    pub const entries_by_hue = bakeSorted(hueFirst);
    pub const entries_by_tone = bakeSorted(toneFirst);
    pub const entries_by_sat = bakeSorted(satFirst);
    pub const entries_by_temp = bakeSorted(tempFirst);
    fn bakeSorted(comptime func: anytype) [count]TaggedColor {
        @setEvalBranchQuota(200000);
        var data: [count]TaggedColor = undefined;
        @memcpy(&data, &entries);
        std.mem.sort(TaggedColor, &data, {}, func);
        return data;
    }
    // MARK: Sorting functions for bucketizing
    // NOTE: The Rainbow (Main Discovery)
    fn hueFirst(_: void, a: TaggedColor, b: TaggedColor) bool {
        if (a.hue != b.hue) return @intFromEnum(a.hue) < @intFromEnum(b.hue);
        if (a.tone != b.tone) return @intFromEnum(a.tone) < @intFromEnum(b.tone);
        return @intFromEnum(a.saturation) < @intFromEnum(b.saturation);
    }

    // NOTE: The Value Scale (For Shading/Contrast)
    fn toneFirst(_: void, a: TaggedColor, b: TaggedColor) bool {
        if (a.tone != b.tone) return @intFromEnum(a.tone) < @intFromEnum(b.tone);
        if (a.hue != b.hue) return @intFromEnum(a.hue) < @intFromEnum(b.hue);
        return @intFromEnum(a.saturation) < @intFromEnum(b.saturation);
    }

    // NOTE: The Glow/Vibe (For Accents)
    fn satFirst(_: void, a: TaggedColor, b: TaggedColor) bool {
        if (a.saturation != b.saturation) return @intFromEnum(a.saturation) < @intFromEnum(b.saturation);
        if (a.tone != b.tone) return @intFromEnum(a.tone) < @intFromEnum(b.tone); // Keep light-to-dark gradient
        return @intFromEnum(a.hue) < @intFromEnum(b.hue);
    }

    // NOTE: The Mood (For World-Building)
    fn tempFirst(_: void, a: TaggedColor, b: TaggedColor) bool {
        if (a.temp != b.temp) return @intFromEnum(a.temp) < @intFromEnum(b.temp);
        if (a.hue != b.hue) return @intFromEnum(a.hue) < @intFromEnum(b.hue); // Group reds with reds
        return @intFromEnum(a.tone) < @intFromEnum(b.tone);
    }
};
