const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Point = @import("core").V2;

// MARK: Data structures
pub const Triangle = struct {
    idx1: usize,
    idx2: usize,
    idx3: usize,
};
const Diagonal = struct {
    v1: usize,
    v2: usize,
};
const EdgeKey = struct {
    from: usize,
    to: usize,
};
const TurnDirection = enum {
    Left,
    Right,
    Collinear,
};
const ChainType = enum {
    Left,
    Right,
};
const VertexType = enum {
    Start, // both neighbors below, convex
    End, // both neighbors above, convex
    Split, // both neighbors below, reflex
    Merge, // both neighbors above, reflex
    Regular, // one above, one below
};

const VertexEvent = struct {
    point: Point,
    index: usize,
    vert_type: VertexType,
};
const AdjacencyList = std.AutoHashMap(usize, ArrayList(usize));
const UsedEdges = std.AutoHashMap(EdgeKey, bool);

const Edge = struct {
    p1: Point,
    p2: Point,
    helper_idx: usize,

    pub fn xAtY(self: Edge, y: f32) f32 {
        if (self.p1.y == self.p2.y) return self.p1.x;
        const t = (y - self.p1.y) / (self.p2.y - self.p1.y);
        return self.p1.x + t * (self.p2.x - self.p1.x);
    }

    pub fn compareAt(a: Edge, b: Edge, sweep_y: f32) std.math.Order {
        const x_a = a.xAtY(sweep_y);
        const x_b = b.xAtY(sweep_y);

        if (x_a < x_b) return .lt;
        if (x_a > x_b) return .gt;
        return .eq;
    }

    pub fn equals(self: Edge, other: Edge) bool {
        return self.p1.eql(other.p1) and self.p2.eql(other.p2);
    }
};

const StatusStructure = struct {
    edges: ArrayList(Edge),
    sweep_y: f32 = 0,
    allocator: Allocator,

    pub fn init(allocator: Allocator) StatusStructure {
        return .{
            .allocator = allocator,
            .edges = .empty,
        };
    }
    pub fn deinit(self: *StatusStructure) void {
        self.edges.deinit(self.allocator);
    }
    pub fn setSweepY(self: *StatusStructure, y: f32) void {
        self.sweep_y = y;
    }
    pub fn insert(self: *StatusStructure, edge: Edge) !void {
        if (self.edges.items.len == 0) return try self.edges.append(self.allocator, edge);

        for (self.edges.items, 0..) |e, index| {
            const comp = edge.compareAt(e, self.sweep_y);
            if (comp == .lt)
                return try self.edges.insert(self.allocator, index, edge);
        }

        try self.edges.append(self.allocator, edge);
    }
    pub fn remove(self: *StatusStructure, edge: Edge) void {
        for (self.edges.items, 0..) |e, i| {
            if (e.equals(edge)) {
                _ = self.edges.orderedRemove(i);
                return;
            }
        }

        std.debug.assert(false);
    }
    pub fn findEdgeLeftIndex(self: *StatusStructure, point: Point) ?usize {
        const x = point.x;
        for (self.edges.items, 0..) |*e, i| {
            const edge_x = e.xAtY(self.sweep_y);
            if (edge_x >= x) {
                if (i == 0) return null;
                return i - 1;
            }
        }
        if (self.edges.items.len > 0) {
            return self.edges.items.len - 1;
        }
        return null;
    }
    pub fn findEdgeLeft(self: *StatusStructure, point: Point) ?*Edge {
        const x = point.x;
        for (self.edges.items, 0..) |*e, i| {
            const edge_x = e.xAtY(self.sweep_y);
            if (edge_x >= x) {
                if (i == 0) return null;
                return &self.edges.items[i - 1];
            }
        }
        if (self.edges.items.len > 0) {
            return &self.edges.items[self.edges.items.len - 1];
        }
        return null;
    }
};

const PartitionContext = struct {
    allocator: Allocator,
    vertices: []const Point,
    events: ArrayList(VertexEvent),
    status: StatusStructure,
    diagonals: ArrayList(Diagonal),

    pub fn init(allocator: Allocator, vertices: []const Point) !PartitionContext {
        var events = try ArrayList(VertexEvent).initCapacity(allocator, vertices.len);
        const n = vertices.len;
        for (0..n) |idx| {
            const prev_idx = if (idx == 0) n - 1 else idx - 1;
            const next_idx = if (idx == n - 1) 0 else idx + 1;
            const prev = vertices[prev_idx];
            const next = vertices[next_idx];
            const v_type = classifyVertex(prev, vertices[idx], next);
            events.appendAssumeCapacity(.{
                .point = vertices[idx],
                .index = idx,
                .vert_type = v_type,
            });
        }
        std.mem.sort(VertexEvent, events.items, {}, compareEvents);

        return .{
            .allocator = allocator,
            .vertices = vertices,
            .events = events,
            .status = StatusStructure.init(allocator),
            .diagonals = .empty,
        };
    }
    pub fn deinit(self: *PartitionContext) void {
        self.status.deinit();
        self.events.deinit(self.allocator);
        self.diagonals.deinit(self.allocator);
    }
    inline fn getNextIndex(self: *const PartitionContext, idx: usize) usize {
        return (idx + 1 + self.vertices.len) % self.vertices.len;
    }
    inline fn getPrevIndex(self: *const PartitionContext, idx: usize) usize {
        return if (idx == 0) self.vertices.len - 1 else idx - 1;
    }

    pub fn partition(self: *PartitionContext) ![]Diagonal {
        for (self.events.items) |v_event| {
            self.status.setSweepY(v_event.point.y);
            switch (v_event.vert_type) {
                .Start => try handleStart(self, v_event),
                .End => try handleEnd(self, v_event),
                .Split => try handleSplit(self, v_event),
                .Merge => try handleMerge(self, v_event),
                .Regular => try handleRegular(self, v_event),
            }
        }

        // Remove duplicate diagonals
        const result = try self.diagonals.toOwnedSlice(self.allocator);
        return try removeDuplicateDiagonals(self.allocator, result);
    }
};
fn removeDuplicateDiagonals(allocator: Allocator, diagonals: []Diagonal) ![]Diagonal {
    if (diagonals.len == 0) return diagonals;

    var unique: ArrayList(Diagonal) = .empty;
    errdefer unique.deinit(allocator);

    for (diagonals) |diag| {
        var is_duplicate = false;
        for (unique.items) |existing| {
            // Check both directions since (v1, v2) == (v2, v1)
            if ((existing.v1 == diag.v1 and existing.v2 == diag.v2) or
                (existing.v1 == diag.v2 and existing.v2 == diag.v1))
            {
                is_duplicate = true;
                break;
            }
        }
        if (!is_duplicate) {
            try unique.append(allocator, diag);
        }
    }

    allocator.free(diagonals);
    return try unique.toOwnedSlice(allocator);
}

fn handleStart(self: *PartitionContext, event: VertexEvent) !void {
    const curr_index = event.index;
    const next_index = self.getNextIndex(curr_index);

    // For a start vertex, insert the edge going downward (to next in CCW order)
    const edge = Edge{
        .helper_idx = event.index,
        .p1 = self.vertices[curr_index],
        .p2 = self.vertices[next_index],
    };

    try self.status.insert(edge);
}

fn handleEnd(self: *PartitionContext, event: VertexEvent) !void {
    // Find the edge that ends at this vertex
    var found_edge: ?Edge = null;
    for (self.status.edges.items) |edge| {
        if (edge.p2.eql(event.point)) {
            found_edge = edge;
            break;
        }
    }

    if (found_edge) |edge| {
        const helper_vertex = self.events.items[edge.helper_idx];
        if (helper_vertex.vert_type == .Merge) {
            try self.diagonals.append(self.allocator, .{
                .v1 = event.index,
                .v2 = helper_vertex.index,
            });
        }
        self.status.remove(edge);
    }
}

fn handleSplit(self: *PartitionContext, event: VertexEvent) !void {
    const left_edge_idx = self.status.findEdgeLeftIndex(event.point) orelse
        return error.NoEdgeFound;

    const left_edge = self.status.edges.items[left_edge_idx];
    const helper_idx = left_edge.helper_idx;

    try self.diagonals.append(self.allocator, .{
        .v1 = event.index,
        .v2 = helper_idx,
    });

    self.status.edges.items[left_edge_idx].helper_idx = event.index;

    // Insert the edge going downward from this split vertex
    const next_index = self.getNextIndex(event.index);
    const edge = Edge{
        .p1 = self.vertices[event.index],
        .p2 = self.vertices[next_index],
        .helper_idx = event.index,
    };
    try self.status.insert(edge);
}
fn handleMerge(self: *PartitionContext, event: VertexEvent) !void {
    // Find the edge ending at this vertex
    var found_edge: ?Edge = null;
    for (self.status.edges.items) |edge| {
        if (edge.p2.eql(event.point)) {
            found_edge = edge;
            break;
        }
    }

    if (found_edge) |edge| {
        const helper_vertex = self.events.items[edge.helper_idx];
        if (helper_vertex.vert_type == .Merge) {
            try self.diagonals.append(self.allocator, .{
                .v1 = event.index,
                .v2 = edge.helper_idx,
            });
        }
        self.status.remove(edge);
    }

    if (self.status.findEdgeLeftIndex(event.point)) |left_edge_idx| {
        const left_edge = self.status.edges.items[left_edge_idx];
        const helper_vertex = self.events.items[left_edge.helper_idx];
        if (helper_vertex.vert_type == .Merge) {
            try self.diagonals.append(self.allocator, .{
                .v1 = event.index,
                .v2 = left_edge.helper_idx,
            });
        }

        self.status.edges.items[left_edge_idx].helper_idx = event.index;
    }
}
fn handleRegular(self: *PartitionContext, event: VertexEvent) !void {
    const curr_index = event.index;
    const next_index = self.getNextIndex(curr_index);
    const prev_index = self.getPrevIndex(curr_index);
    const next_vert = self.vertices[next_index];
    const prev_vert = self.vertices[prev_index];
    const curr_vert = self.vertices[curr_index];

    // Check if previous vertex is above or below
    // If prev is above, we're on the left boundary (edge comes in from above)
    // If prev is below, we're on the right boundary (edge goes out below)
    const prev_above = prev_vert.y < curr_vert.y;

    if (prev_above) {
        // Left boundary - remove incoming edge, add outgoing edge
        var found_edge: ?Edge = null;
        for (self.status.edges.items) |edge| {
            if (edge.p2.eql(event.point)) {
                found_edge = edge;
                break;
            }
        }

        if (found_edge) |edge| {
            const helper_vertex = self.events.items[edge.helper_idx];
            if (helper_vertex.vert_type == .Merge) {
                try self.diagonals.append(self.allocator, .{
                    .v1 = event.index,
                    .v2 = helper_vertex.index,
                });
            }

            self.status.remove(edge);

            // Insert new edge going down
            try self.status.insert(.{
                .p1 = curr_vert,
                .p2 = next_vert,
                .helper_idx = event.index,
            });
        }
    } else {
        // Right boundary - update helper of edge to left
        if (self.status.findEdgeLeftIndex(event.point)) |left_edge_idx| {
            const left_edge = self.status.edges.items[left_edge_idx];
            const helper_vertex = self.events.items[left_edge.helper_idx];
            if (helper_vertex.vert_type == .Merge) {
                try self.diagonals.append(self.allocator, .{
                    .v1 = event.index,
                    .v2 = helper_vertex.index,
                });
            }

            self.status.edges.items[left_edge_idx].helper_idx = event.index;
        }
        // If no edge to left, this is fine for simple convex polygons
    }
}

fn canTriangulate(a: Point, b: Point, c: Point, chain: ChainType) bool {
    const cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
    return if (chain == .Left) cross > 0 else cross < 0;
}

fn ensureCounterClockwise(tri: *[3]Point) void {
    const a = tri[0];
    const b = tri[1];
    const c = tri[2];
    // Calculate signed area (cross product)
    const cross = (b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y);
    // If negative (clockwise), swap vertices to make counter-clockwise
    if (cross < 0) {
        const temp = tri[1];
        tri[1] = tri[2];
        tri[2] = temp;
    }
}

const TriangleIndicies = struct {
    a: usize,
    b: usize,
    c: usize,
};

// MARK: Geometry computations
fn compareEvents(context: void, a: VertexEvent, b: VertexEvent) bool {
    _ = context;
    return comparePoints(a.point, b.point) == .lt;
}

inline fn comparePoints(a: Point, b: Point) std.math.Order {
    if (a.y < b.y) return .lt;
    if (a.y > b.y) return .gt;
    if (a.x < b.x) return .lt;
    if (a.x > b.x) return .gt;

    return .eq;
}

pub fn signedArea(points: []const Point) f32 {
    var area: f32 = 0;
    const n = points.len;
    for (0..n) |i| {
        const j = (i + 1) % n;
        area += points[i].x * points[j].y;
        area -= points[j].x * points[i].y;
    }

    return area / 2.0;
}

fn isConvexAngle(prev: Point, current: Point, next: Point) bool {
    const edge1 = current.sub(prev);
    const edge2 = next.sub(current);
    const cross = edge1.x * edge2.y - edge1.y * edge2.x;
    return cross < 0;
}

fn turnDirection(a: Point, b: Point, c: Point) TurnDirection {
    const edge1 = b.sub(a);
    const edge2 = c.sub(b);

    const cross = edge1.x * edge2.y - edge1.y * edge2.x;
    if (cross > 0)
        return .Left;
    if (cross < 0)
        return .Right;

    return .Collinear;
}

// MARK: Triangulation
fn classifyVertex(prev: Point, current: Point, next: Point) VertexType {
    const prev_below = prev.y > current.y;
    const next_below = next.y > current.y;

    if (prev_below and next_below) {
        if (isConvexAngle(prev, current, next)) return .Start;
        return .Split;
    }
    if (!prev_below and !next_below) {
        if (isConvexAngle(prev, current, next)) return .End;
        return .Merge;
    }
    return .Regular;
}

pub fn triangulate(
    allocator: Allocator,
    points: []const Point,
) ![][3]Point {
    if (points.len == 0) return error.EmptyPoints;

    if (points.len < 3) return error.NotEnoughVertices;

    var ctx = try PartitionContext.init(allocator, points);
    defer ctx.deinit();

    const diagonals = try ctx.partition();
    defer allocator.free(diagonals);

    const monotone_pieces = try extractMonotonePolygons(allocator, points, diagonals);
    defer {
        for (monotone_pieces) |piece| {
            allocator.free(piece);
        }
        allocator.free(monotone_pieces);
    }

    var all_triangles: ArrayList([3]Point) = .empty;
    errdefer all_triangles.deinit(allocator);
    for (monotone_pieces) |piece| {
        const piece_triangles = try triangulateMonotone(allocator, piece);
        defer allocator.free(piece_triangles);
        try all_triangles.appendSlice(allocator, piece_triangles);
    }

    const result = try all_triangles.toOwnedSlice(allocator);

    // Ensure all triangles have counter-clockwise winding
    for (result) |*tri| {
        ensureCounterClockwise(tri);
    }

    return result;
}

fn triangulateMonotone(
    allocator: Allocator,
    vertices: []const Point,
) ![][3]Point {
    var stack: ArrayList(usize) = .empty;
    defer stack.deinit(allocator);

    var chains = try allocator.alloc(ChainType, vertices.len);
    defer allocator.free(chains);

    var min: f32 = vertices[0].y;
    var max: f32 = vertices[0].y;
    var minIndex: usize = 0;
    var maxIndex: usize = 0;
    for (vertices, 0..) |vert, i| {
        if (vert.y <= min) {
            if (vert.y == min) {
                if (vert.x < vertices[minIndex].x) {
                    min = vert.y;
                    minIndex = i;
                }
            }
            min = vert.y;
            minIndex = i;
        }
        if (vert.y >= max) {
            if (vert.y == max) {
                if (vert.x > vertices[maxIndex].x) {
                    max = vert.y;
                    maxIndex = i;
                }
            }
            max = vert.y;
            maxIndex = i;
        }
    }

    var i = minIndex;
    while (i != maxIndex) {
        chains[i] = .Left;
        i = (i + 1) % vertices.len;
    }
    i = minIndex;
    while (i != maxIndex) {
        chains[i] = .Right;
        i = if (i == 0) vertices.len - 1 else i - 1;
    }

    chains[minIndex] = .Left;
    chains[maxIndex] = .Right;

    const len = vertices.len;
    var sorted_indices = try allocator.alloc(usize, len);
    defer allocator.free(sorted_indices);
    for (0..len) |idx| sorted_indices[idx] = idx;
    const SortCtx = struct { vertices: []const Point };
    const cmp = struct {
        fn f(ctx: SortCtx, a: usize, b: usize) bool {
            return comparePoints(ctx.vertices[a], ctx.vertices[b]) == .lt;
        }
    }.f;

    std.mem.sort(usize, sorted_indices, SortCtx{ .vertices = vertices }, cmp);
    var triangles: ArrayList([3]Point) = .empty;
    try stack.append(allocator, sorted_indices[0]);
    try stack.append(allocator, sorted_indices[1]);

    for (2..len - 1) |idx| {
        const current_idx = sorted_indices[idx];
        const current_point = vertices[current_idx];

        if (chains[current_idx] == chains[stack.getLast()]) {
            while (stack.items.len >= 2) {
                const top_idx = stack.items[stack.items.len - 1];
                const second_idx = stack.items[stack.items.len - 2];

                if (canTriangulate(vertices[second_idx], vertices[top_idx], current_point, chains[top_idx])) {
                    _ = stack.pop();
                    try triangles.append(allocator, [3]Point{
                        vertices[second_idx],
                        vertices[top_idx],
                        current_point,
                    });
                } else break;
            }
            try stack.append(allocator, current_idx);
        } else {
            while (stack.items.len > 1) {
                const top_idx = stack.pop().?;
                const next_idx = stack.items[stack.items.len - 1];
                try triangles.append(allocator, [3]Point{
                    vertices[top_idx],
                    vertices[next_idx],
                    current_point,
                });
            }
            _ = stack.pop();
            try stack.append(allocator, sorted_indices[idx - 1]);
            try stack.append(allocator, current_idx);
        }
    }

    const last_vertex = sorted_indices[len - 1];
    while (stack.items.len > 1) {
        const top_idx = stack.pop().?;
        const next_idx = stack.items[stack.items.len - 1];
        try triangles.append(allocator, [3]Point{
            vertices[top_idx],
            vertices[next_idx],
            vertices[last_vertex],
        });
    }

    return try triangles.toOwnedSlice(allocator);
}

fn sortNeighborsByAngle(
    center_idx: usize,
    neighbors: *ArrayList(usize),
    vertices: []const Point,
) void {
    const SortContext = struct {
        center_idx: usize,
        vertices: []const Point,
    };

    const compareByAngle = struct {
        fn cmp(ctx: SortContext, a_idx: usize, b_idx: usize) bool {
            const center = ctx.vertices[ctx.center_idx];
            const a = ctx.vertices[a_idx];
            const b = ctx.vertices[b_idx];

            const angle_a = std.math.atan2(a.y - center.y, a.x - center.x);
            const angle_b = std.math.atan2(b.y - center.y, b.x - center.x);

            return angle_a < angle_b;
        }
    }.cmp;

    std.mem.sort(usize, neighbors.items, SortContext{
        .center_idx = center_idx,
        .vertices = vertices,
    }, compareByAngle);
}

fn buildAdjacencyGraph(
    allocator: Allocator,
    vertices: []const Point,
    diagonals: []const Diagonal,
) !AdjacencyList {
    var adjacency = AdjacencyList.init(allocator);
    errdefer adjacency.deinit();

    const n = vertices.len;

    for (0..n) |i| {
        try adjacency.put(i, .empty);
    }

    for (0..n) |i| {
        const next = (i + 1) % n;
        try adjacency.getPtr(i).?.append(allocator, next);
        try adjacency.getPtr(next).?.append(allocator, i);
    }

    for (diagonals) |diag| {
        try adjacency.getPtr(diag.v1).?.append(allocator, diag.v2);
        try adjacency.getPtr(diag.v2).?.append(allocator, diag.v1);
    }

    for (0..n) |i| {
        const neighbors = adjacency.getPtr(i).?;
        sortNeighborsByAngle(i, neighbors, vertices);
    }

    return adjacency;
}

fn extractCycle(
    allocator: Allocator,
    adjacency: *AdjacencyList,
    used_edges: *UsedEdges,
    start_vertex: usize,
    n_vertices: usize,
) ![]usize {
    var polygon: ArrayList(usize) = try .initCapacity(allocator, 2 * n_vertices);
    errdefer polygon.deinit(allocator);

    var current = start_vertex;
    var cycle_closed = false;

    while (true) {
        polygon.appendAssumeCapacity(current);
        const neighbors = adjacency.get(current) orelse return error.NoNeighbors;

        const next = findFirstUnusedEdge(current, neighbors.items, used_edges) orelse break;
        try used_edges.put(.{ .from = current, .to = next }, true);
        try used_edges.put(.{ .from = next, .to = current }, true);
        current = next;

        if (current == start_vertex) {
            cycle_closed = true;
            break;
        }
        if (polygon.items.len > 2 * n_vertices) return error.InfiniteLoop;
    }

    // If the cycle didn't close, return empty cycle (will be filtered out)
    if (!cycle_closed) {
        polygon.clearRetainingCapacity();
    }

    return try polygon.toOwnedSlice(allocator);
}

fn findFirstUnusedEdge(
    current: usize,
    neighbors: []usize,
    used_edges: *UsedEdges,
) ?usize {
    for (neighbors) |neighbor_idx| {
        const edge_key: EdgeKey = .{ .from = current, .to = neighbor_idx };
        if (!used_edges.contains(edge_key)) {
            return neighbor_idx;
        }
    }
    return null;
}

fn extractMonotonePolygons(
    allocator: Allocator,
    vertices: []const Point,
    diagonals: []const Diagonal,
) ![][]Point {
    var adjacency = try buildAdjacencyGraph(allocator, vertices, diagonals);
    defer {
        var it = adjacency.valueIterator();
        while (it.next()) |list| {
            list.deinit(allocator);
        }
        adjacency.deinit();
    }

    var used_edges = UsedEdges.init(allocator);
    defer used_edges.deinit();

    var polygons: ArrayList([]Point) = .empty;
    errdefer {
        for (polygons.items) |poly| {
            allocator.free(poly);
        }
        polygons.deinit(allocator);
    }

    const n = vertices.len;
    for (0..n) |start_vertex| {
        while (true) {
            const cycle_indices = try extractCycle(
                allocator,
                &adjacency,
                &used_edges,
                start_vertex,
                n,
            );

            if (cycle_indices.len < 3) {
                allocator.free(cycle_indices);
                break;
            }

            const cycle_points = try allocator.alloc(Point, cycle_indices.len);
            for (cycle_indices, 0..) |idx, i| {
                cycle_points[i] = vertices[idx];
            }
            allocator.free(cycle_indices);

            try polygons.append(allocator, cycle_points);
        }
    }

    return try polygons.toOwnedSlice(allocator);
}
