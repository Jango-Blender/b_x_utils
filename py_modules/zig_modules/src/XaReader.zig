/// A convenience wrapper over Io.Reader with specialized little endian methods.
const XaReader = @This();

const std = @import("std");
const Io = std.Io;

r: std.Io.Reader,

pub fn discard(self: *XaReader, length: u32) Io.Reader.Error!void {
    try self.r.discardAll(length);
}
pub fn fixed(buf: []u8) XaReader {
    return .{ .r = .fixed(buf) };
}
pub fn take(self: *XaReader, T: type) Io.Reader.Error!T {
    return switch (@typeInfo(T)) {
        .int => try self.r.takeInt(T, .little),
        .float => @bitCast(try self.r.takeInt(@Int(.unsigned, @bitSizeOf(T)), .little)),
        .@"struct" => try self.r.takeStruct(T, .little),
        else => @compileError("unsupported"),
    };
}
pub fn readSlice(self: *XaReader, T: type, slice: []T) Io.Reader.Error!void {
    // try self.r.readSliceAll(std.mem.sliceAsBytes(slice));
    try self.r.readSliceEndian(T, slice, .little);
}
