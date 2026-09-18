const std = @import("std");

pub const Vector2df = extern struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    pub fn format(self: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("Vector2df(x={d}, y={d})", .{ self.x, self.y });
    }
};
pub const Vector3df = extern struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    pub fn format(self: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("Vector3df(x={d}, y={d}, z={d})", .{ self.x, self.y, self.z });
    }
};
pub const Vector4df = extern struct {
    w: f32 = 0.0,
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    pub fn format(self: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("Vector4df(w={d}, x={d}, y={d}, z={d})", .{ self.w, self.x, self.y, self.z });
    }
};

pub fn Triple(T: type) type {
    return extern struct {
        items: [3]T,
        pub fn format(self: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("Triple({}, {}, {})", .{ self.items[0], self.items[1], self.items[2] });
        }
    };
}

pub const Name = extern struct {
    bytes: [16]u8 = @splat(0),
    pub fn from(src: []const u8) !Name {
        var name_bytes: [16]u8 = @splat(0);
        const len = @min(src.len, 16);
        @memcpy(name_bytes[0..len], src[0..len]);
        return .{ .bytes = name_bytes };
    }
};

// Uhhh will this work?
const MatrixError = error{ImpossibleMatmultShape};

pub fn Matrix(comptime R: usize, comptime C: usize) type {
    return struct {
        rows: [R][C]f32 = &.{},
    };
}

pub fn matmult(a: anytype, b: anytype) Matrix(@TypeOf(a).rows.len, @TypeOf(b).rows[0].len) {
    const A = @TypeOf(a);
    const B = @TypeOf(b);

    const R = A.rows.len;
    const C = A.rows[0].len;
    const N = B.rows[0].len; //Columns of b

    if (C != B.rows.len) {
        std.debug.print("Cannot multiply Matrix({},{}) by Matrix({},{})", .{ R, C, B.rows.len, N });
        return MatrixError.ImpossibleMatmultShape;
    }
    var result = Matrix(R, N){};

    for (0..R) |row| {
        for (0..N) |col| {
            for (0..C) |k| {
                result.rows[row][col] +=
                    a.rows[row][k] * b.rows[k][col];
            }
        }
    }
    return result;
}

pub const xMatrix = extern struct {
    vals: [12]f32 = &.{},
    pub fn to_4x4(self: *const @This()) Matrix(4, 4) {
        const v = self.vals;
        return Matrix(4, 4){
            .rows = .{
                .{ v[0], v[6], v[3], v[9] },
                .{ v[2], v[8], v[5], v[11] },
                .{ v[1], v[7], v[4], v[10] },
                .{ 0.0, 0.0, 0.0, 1.0 },
            },
        };
    }
};
