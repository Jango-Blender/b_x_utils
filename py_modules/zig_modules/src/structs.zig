const std = @import("std");

pub const Vector2df = extern struct {
    x: f32,
    y: f32,
    pub fn format(self: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("Vector2df(x={d}, y={d})", .{ self.x, self.y });
    }
};
pub const Vector3df = extern struct {
    x: f32,
    y: f32,
    z: f32,
    pub fn format(self: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("Vector3df(x={d}, y={d}, z={d})", .{ self.x, self.y, self.z });
    }
};
pub const Vector4df = extern struct {
    w: f32,
    x: f32,
    y: f32,
    z: f32,
    pub fn format(self: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("Vector4df(w={d}, x={d}, y={d}, z={d})", .{ self.w, self.x, self.y, self.z });
    }
};

pub fn Triple(T: type) type {
    return extern struct {
        items: [3]T,
        pub fn format(self: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("u16({}, {}, {})", .{ self.items[0], self.items[1], self.items[2] });
        }
    };
}

pub const Name = extern struct {
    bytes: [16]u8,
};

pub const MaterialRange = extern struct {
    ignored: u32,
    start: u32,
    stop: u32,
    name: Name,
    pub fn format(self: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("MaterialRef(name={s}, start=0x{x}, stop=0x{x})", .{ std.mem.sliceTo(&self.name, 0), self.start, self.stop });
    }
};

pub const PhysicsSphere = extern struct {
    pos: Vector3df,
    size: f32,
};