pub const ColliderShape = union(enum) {
    circle: struct {
        radius: f32,
    },
    rectangle: struct {
        half_w: f32,
        half_h: f32,
    },
    // Future other shapes
};

pub const Collider = struct {
    shape: ?ColliderShape,
    // layer, masks for filtering
};
