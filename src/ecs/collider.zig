pub const ColliderShape = union(enum) {
    circle: struct {
        radius: f32,
    },
    // Future other shapes
};

pub const Collider = struct {
    shape: ?ColliderShape,
    // layer, masks for filtering
};
