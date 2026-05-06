pub const WlFixed = packed struct {
    frac: u8,
    integer: i24,

    pub fn toF32(self: WlFixed) f32 {
        _ = self;
        return 0.0;
    }
    pub fn fromF32(f: f32) WlFixed {
        _ = f;
        return .{ .frac = 0, .integer = 0 };
    }
};

pub const ObjIdAllocator = struct {
    next: u32 = 2,

    pub fn alloc(self: *ObjIdAllocator) u32 {
        const id = self.next;
        self.next += 1;
        return id;
    }
};

pub fn parse(comptime T: type, data: []const u8, offset: *usize) !T {
    _ = data;
    _ = offset;
    return error.NotImplmented_ProtocolParse;
}

pub fn emit(comptime T: type, obj_id: u32, opcode: u16, val: T, buf: []u8) usize {
    _ = obj_id;
    _ = opcode;
    _ = val;
    _ = buf;
}
