const std = @import("std");
const s = @import("structs.zig");
const xReader = @import("xReader.zig").xReader;

const RFC = @import("rfc.zig").RFC;
const RFT = @import("rft.zig").RFT;
const RFI = @import("rfi.zig").RFI;

const Allocator = std.mem.Allocator;
const print = std.debug.print;

const RPKEntry = extern struct {
    offset: u32,
    size: u32,
    unk: u32,
    id: u32,
};

const ParsedEntry = union(enum) {
    rfc: RFC,
    rft: void, //RFT,
    rfi: void, //RFI,
};

const RPKError = error{
    EntryNotFound,
    UnknownSignature,
};

pub const RPK = struct {
    r: xReader,
    signature: u32,
    name: []const u8,
    arena: *std.heap.ArenaAllocator,
    allocator: std.mem.Allocator,
    lookup_table: std.StringHashMap(RPKEntry),
    data_start: u32,
    pub fn from_path(path: []const u8, buffer: []u8, arena: *std.heap.ArenaAllocator) !RPK {
        const allocator = arena.allocator(); //Hang onto this so it isnt spawning ten morbillion different allocators throughout its life.
        var r: xReader = try .from_path(path, buffer);
        const signature = try r.take(u32);
        const table_entries_n = try r.take(u32) / 0x20;
        var lookup_table = std.StringHashMap(RPKEntry).init(allocator);
        for (0..table_entries_n) |_| {
            const entry_name = try r.take(s.Name);
            const entry = try r.take(RPKEntry);
            try lookup_table.put(try allocator.dupe(u8, &entry_name.bytes), entry);
        }
        return .{
            .r = r,
            .signature = signature,
            .name = std.fs.path.basename(path),
            .arena = arena,
            .allocator = allocator,
            .lookup_table = lookup_table,
            .data_start = r.tell(),
        };
    }
    pub fn parse_entry(self: *@This(), entry_name: s.Name, is_prop: bool) !ParsedEntry {
        const entry = self.lookup_table.get(&entry_name.bytes) orelse {
            print("Entry {s} is not in RPK {s}", .{ entry_name.bytes, self.name });
            return RPKError.EntryNotFound;
        };
        const start = entry.offset + self.data_start;
        try self.r.seek_to(start);
        const signature = try self.r.take(u32);
        switch (signature & 0xFFFF0000) {
            0x3D230000 => {
                return .{ .rfc = try RFC.read(&self.r, self.allocator, entry.size, start, signature, is_prop) };
            },
            0x3EEF0000 => {
                return .{ .rft = try RFT.read(&self.r, entry.size) };
            },
            0x1D2D0000 => {
                return .{ .rfi = try RFI.read(&self.r, entry.size) };
            },
            else => {
                print("Found an unknown rpk signature 0x{x} for entry {s}", .{ signature, entry_name.bytes });
            },
        }
    }
    pub fn deinit(self: *@This()) void {
        self.r.deinit();
        self.arena.deinit();
    }
};

const BUFFER_SIZE = 64 * 1024;
pub fn main() !void {
    const path = "C:\\Program Files (x86)\\Steam\\steamapps\\common\\Exanima\\Resource.rpk";
    var buffer: [BUFFER_SIZE]u8 = undefined;
    // const arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var rpk = try RPK.from_path(path, &buffer, &arena);
    const entry_name = s.Name.from("exanima01.rfc");
    const parsed_entry = try rpk.parse_entry(try entry_name, true);
    _ = parsed_entry;
    // // print("Lookup table: {}", .{rpk.lookup_table});
    // var iter = rpk.lookup_table.iterator();

    // while (iter.next()) |entry| {
    //     print("Key: {s}\n", .{entry.key_ptr.*});
    // }
}
