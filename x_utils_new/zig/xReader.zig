/// A convenience wrapper over Io.Reader with specialized little endian methods.
const std = @import("std");
const Io = std.Io;
const File = Io.File;
const Dir = Io.Dir;
const Reader = Io.Reader;

const print = std.debug.print;

const BUFFER_SIZE = 64 * 1024;

pub const xReader = struct {
    io: Io,
    file: File,
    r: File.Reader,
    pub fn from_path(path: []const u8, buffer: []u8) !xReader {
        var threaded: Io.Threaded = .init_single_threaded;
        const io = threaded.io();
        const file = try Dir.openFile(
            Dir.cwd(),
            io,
            path,
            .{ .mode = .read_only },
        );
        return .{
            .io = io,
            .file = file,
            .r = file.reader(io, buffer),
        };
    }
    pub fn discard(self: *@This(), length: u32) Reader.Error!void {
        try self.r.interface.discardAll(length);
    }
    pub fn take(self: *@This(), T: type) Reader.Error!T {
        return switch (@typeInfo(T)) {
            .int => try self.r.interface.takeInt(T, .little),
            .float => @bitCast(try self.r.interface.takeInt(@Int(.unsigned, @bitSizeOf(T)), .little)),
            .@"struct" => try self.r.interface.takeStruct(T, .little),
            else => @compileError("unsupported"),
        };
    }
    pub fn readSlice(self: *@This(), T: type, slice: []T) Reader.Error!void {
        try self.r.interface.readSliceEndian(T, slice, .little);
    }
    pub fn tell(self: @This()) u32 {
        return @intCast(self.r.interface.seek);
    }
    pub fn seek_to(self: *@This(), offset: u32) !void {
        try self.r.seekTo(offset);
    }
    pub fn read_raw(self: *@This(), allocator: std.mem.Allocator, length: u32) ![]u8 {
        const data = try allocator.alloc(u8, length);
        try self.readSlice(u8, data);
        return data;
    }
    fn format(self: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("xReader(file={})", .{self.file});
    }
    pub fn deinit(self: *@This()) void {
        self.file.close(self.io);
    }
};

pub fn main() !void {
    const path = "C:\\Program Files (x86)\\Steam\\steamapps\\common\\Exanima\\Resource.rpk";
    var buffer: [BUFFER_SIZE]u8 = undefined;
    var reader = try xReader.from_path(path, &buffer);
    print("Signature: 0x{x}\nTable Length: 0x{x}", .{ try reader.take(u32), try reader.take(u32) });
}
