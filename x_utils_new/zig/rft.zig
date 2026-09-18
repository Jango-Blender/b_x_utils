const std = @import("std");
// // const py = @import("python");
// const pyb = @import("py_bindings.zig");
// const pyo = pyb.object_types;

const xReader = @import("xReader.zig").xReader;
const Name = @import("structs.zig").Name;

const print = std.debug.print;

pub const RFT = struct {
    name: Name,
    fn read(r: *xReader, length: u32) !void {
        _ = r;
        _ = length;
        print("Reading terrain...", .{});
    }
};

// const Allocator = std.mem.Allocator;
// const XaReader = @import("XaReader.zig");
// const OnceSetterSafeGetter = @import("meta.zig").OnceSetterSafeGetter;

// const TerrainError = error{
//     UnknownTTileChunk,
//     UnknownTerrainBlock,
//     InvalidTerrain,
//     SectorOutOfBounds,
//     TerrainTileNotFound,
// };

// const SECTOR_WIDTH = std.math.divCeil(comptime_int, 0xF1, 8) catch unreachable;

// const TSECTOR_SIZE = SECTOR_WIDTH * SECTOR_WIDTH;
// const SECTOR_FACES_N = (SECTOR_WIDTH - 1) * (SECTOR_WIDTH - 1);

// const BrushSector = struct { name: Name, map: [TSECTOR_SIZE]u8 };
// const TerrainSector = struct {
//     pos_x: u32,
//     pos_y: u32,
//     scale: f32,
//     heightmap: [TSECTOR_SIZE]f32,
//     brushes: []BrushSector,
//     holemap: [TSECTOR_SIZE]u1,
//     fn format(self: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
//         try writer.print("TerrainSector(pos_x=0x{x}, pos_y=0x{x}, scale={}, min_height={}, max_height={}, brushes_n=0x{x})\n", .{ self.pos_x, self.pos_y, self.scale, std.mem.min(f32, &self.heightmap), std.mem.max(f32, &self.heightmap), self.brushes.len });
//     }
//     fn heightmap_to_positions_py(self: @This()) !pyo.ListObject {
//         // std.debug.print("Converting heightmap to py...\n", .{});
//         const pos_offset: f32 = -self.scale * SECTOR_WIDTH / 2;
//         const vectors_list: pyo.ListObject = try .initPlaceholders(TSECTOR_SIZE);
//         const vertical_scaling: f32 = self.scale * 0.1; //Why do i need to divide the height?
//         for (0..SECTOR_WIDTH) |y_usize| {
//             const y: u16 = @intCast(y_usize);
//             const y_pos: f32 = @as(f32, y) * self.scale + pos_offset;
//             for (0..SECTOR_WIDTH) |x_usize| {
//                 const x: u16 = @intCast(x_usize);
//                 const tuple: pyo.TupleObject = try .initPlaceholders(3);
//                 tuple.setUnchecked(0, try pyb.float(@as(f32, x) * self.scale + pos_offset));
//                 tuple.setUnchecked(1, try pyb.float(y_pos));
//                 tuple.setUnchecked(2, try pyb.float(self.heightmap[y * SECTOR_WIDTH + x] * vertical_scaling));
//                 vectors_list.setUnchecked(y * SECTOR_WIDTH + x, tuple);
//             }
//         }
//         return vectors_list;
//     }
//     pub fn generate_face_indices_py(self: @This()) !pyo.ListObject {
//         // std.debug.print("Generating face indices...\n", .{});
//         _ = self;
//         const face_width = SECTOR_WIDTH - 1;
//         const faces_list: pyo.ListObject = try .initPlaceholders(face_width * face_width);
//         for (0..face_width) |y| {
//             for (0..face_width) |x| {
//                 const vertex = y * SECTOR_WIDTH + x;
//                 const tuple: pyo.TupleObject = try .initPlaceholders(4);
//                 tuple.setUnchecked(0, try pyb.long(vertex));
//                 tuple.setUnchecked(1, try pyb.long(vertex + 1));
//                 tuple.setUnchecked(2, try pyb.long(vertex + SECTOR_WIDTH + 1));
//                 tuple.setUnchecked(3, try pyb.long(vertex + SECTOR_WIDTH));
//                 faces_list.setUnchecked(y * face_width + x, tuple);
//             }
//         }
//         return faces_list;
//     }
//     pub fn convert_brushes_to_py(self: @This()) !pyo.ListObject {
//         // std.debug.print("Converting brushes to py...\n", .{});
//         const brushes_list: pyo.ListObject = try .initPlaceholders(self.brushes.len);
//         for (self.brushes, 0..self.brushes.len) |brush, i| {
//             const tuple: pyo.TupleObject = try .initPlaceholders(2);

//             const clean_name = std.mem.sliceTo(&brush.name.bytes, 0);
//             tuple.setUnchecked(0, try pyo.UnicodeObject.from(clean_name, .cp1252));

//             const brush_weight_list: pyo.ListObject = try .initPlaceholders(TSECTOR_SIZE);
//             for (brush.map, 0..TSECTOR_SIZE) |val, j| { // Values range from [0,255]. Convert them to [0.0,1.0]
//                 brush_weight_list.setUnchecked(j, try pyb.float(@as(f32, val) / 255.0));
//             }
//             tuple.setUnchecked(1, brush_weight_list);

//             brushes_list.setUnchecked(i, tuple);
//         }
//         return brushes_list;
//     }
//     pub fn convert_holemap_to_py(self: @This()) !pyo.ListObject {
//         const hole_list: pyo.ListObject = try .initPlaceholders(TSECTOR_SIZE);
//         for (0..SECTOR_WIDTH) |y| {
//             const y_index = y * SECTOR_WIDTH;
//             for (0..SECTOR_WIDTH) |x| {
//                 const index: u16 = @intCast(y_index + x);
//                 hole_list.setUnchecked(index, try pyb.long(self.holemap[index]));
//             }
//         }
//         return hole_list;
//     }
// };

// const Brush = extern struct {
//     name: Name,
//     map: [0xF1 * 0xF1]u8,
// };
// const TTile = struct {
//     hole_flag: u32,
//     pos_x: u32,
//     pos_y: u32,
//     u3: u32,
//     heightmap: []f32,
//     brushes: []Brush,
//     holemap: [0xF1 * 0xF1]u1,
//     fn format(self: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
//         try writer.print("TTile(hole_flag=0x{x}, pos_x=0x{x}, pos_y=0x{x}, u3=0x{x}, min_height={}, max_height={}, brushes_n=0x{x})\n", .{ self.hole_flag, self.pos_x, self.pos_y, self.u3, std.mem.min(f32, &self.heightmap), std.mem.max(f32, &self.heightmap), self.brushes.len });
//     }
//     fn get_sector(self: @This(), arena: Allocator, pos_x: u32, pos_y: u32, scale: f32) !TerrainSector {
//         // std.debug.print("Getting sector (0x{x},0x{x})\n", .{ pos_x, pos_y });
//         const brushes = try arena.alloc(BrushSector, self.brushes.len);
//         //Copy the names only once.
//         for (self.brushes, brushes) |tile_brush, *sector_brush| {
//             sector_brush.name = tile_brush.name;
//         }

//         const l_pos_x = pos_x % 8; //Relative to the tile's corner
//         const l_pos_y = pos_y % 8;
//         const start_x = l_pos_x * (SECTOR_WIDTH - 1); //Positions on the grid
//         const start_y = l_pos_y * (SECTOR_WIDTH - 1);

//         var heightmap: [TSECTOR_SIZE]f32 = undefined;
//         var holemap: [TSECTOR_SIZE]u1 = undefined;
//         for (0..SECTOR_WIDTH) |y| {
//             const h_src_start = (start_y + y) * 0xF4 + start_x;
//             const dst_start = y * SECTOR_WIDTH;
//             @memcpy(heightmap[dst_start..][0..SECTOR_WIDTH], self.heightmap[h_src_start..][0..SECTOR_WIDTH]);
//             const b_src_start = (start_y + y) * 0xF1 + start_x;
//             @memcpy(holemap[dst_start..][0..SECTOR_WIDTH], self.holemap[b_src_start..][0..SECTOR_WIDTH]);
//             for (self.brushes, brushes) |tile_brush, *sector_brush| {
//                 @memcpy(sector_brush.map[dst_start..][0..SECTOR_WIDTH], tile_brush.map[b_src_start..][0..SECTOR_WIDTH]);
//             }
//         }
//         // std.debug.print("Found the sector!\n", .{});
//         return .{
//             .pos_x = pos_x,
//             .pos_y = pos_y,
//             .scale = scale,
//             .brushes = brushes,
//             .heightmap = heightmap,
//             .holemap = holemap,
//         };
//     }
// };

// fn read_ttile(arena: Allocator, fixed: *XaReader, length: u32) !TTile {
//     const start = fixed.r.seek;

//     const hole_flag = try fixed.take(u32);
//     const pos_x = try fixed.take(u32);
//     const pos_y = try fixed.take(u32);
//     const unknown = try fixed.take(u32);

//     const heightmap = try arena.alloc(f32, 0xF4 * 0xF4); //Put it in the heap, not the stack. That was causing overflow errors.
//     try fixed.readSlice(f32, heightmap);

//     var holemap: [0xF1 * 0xF1]u1 = undefined;
//     if (hole_flag & 0x200 != 0) {
//         const final_column_index = 30 * 8; //240
//         for (0..0xF1) |y| {
//             const y_pos = y * 0xF1;
//             for (0..30) |x| { //30 Full bytes to read and unpack into the holemap
//                 var byte = try fixed.take(u8);
//                 const base_index = y_pos + (x * 8);
//                 for (0..8) |i| {
//                     holemap[base_index + i] = @intCast(byte & 1);
//                     byte >>= 1;
//                 }
//             }
//             holemap[y_pos + final_column_index] = @intCast(try fixed.take(u8) & 1); //The final byte in the row. Discard the other 7 bits.
//         }
//     }

//     var chunks: OnceSetterSafeGetter(struct {
//         brushes: []Brush,
//     }) = .empty;
//     while (fixed.r.seek - start < length) {
//         const chunk_start = fixed.r.seek;
//         const signature = try fixed.take(u32);
//         const chunk_length = try fixed.take(u32);
//         _ = chunk_length;
//         switch (signature) {
//             0xBD01 => {
//                 const brushes_n = try fixed.take(u32);
//                 const brushes = try arena.alloc(Brush, brushes_n);
//                 try fixed.readSlice(Brush, brushes);
//                 try chunks.set(.brushes, brushes);
//             },
//             else => {
//                 std.debug.print("Found an unknown terrain tile chunk 0x{x} starting @ 0x{x}\n", .{ signature, chunk_start });
//                 return error.UnknownTTileChunk;
//             },
//         }
//     }
//     return .{
//         .hole_flag = hole_flag,
//         .pos_x = pos_x,
//         .pos_y = pos_y,
//         .u3 = unknown,
//         .heightmap = heightmap,
//         .brushes = try chunks.get(.brushes),
//         .holemap = holemap,
//     };
// }

// const TileCoord = struct { x: u32, y: u32 };

// const Terrain = struct {
//     arena_state: std.heap.ArenaAllocator,
//     unk: u32,
//     material: Name,
//     scale: f32,
//     dim_x: u32,
//     dim_y: u32,
//     tile_map: std.AutoHashMapUnmanaged(TileCoord, TTile),

//     fn deinit(self: *Terrain) void {
//         self.arena_state.deinit();
//     }
//     fn format(self: *const @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
//         try writer.print("Terrain(unk=0x{x}, material={s}, scale={}, dim_x=0x{x}, dim_y=0x{x}, tiles_n=0x{x})\n", .{ self.unk, std.mem.sliceTo(&self.material, 0), self.scale, self.dim_x, self.dim_y, self.tile_map.count() });
//     }
//     fn get_sector(self: *@This(), pos_x: u32, pos_y: u32) !TerrainSector {
//         if (pos_x / 8 > self.dim_x or pos_x / 8 > self.dim_y) {
//             std.debug.print("Sector (0x{x},0x{x}) is out of indexing range for terrain with dimensions (0x{x},0x{x})", .{ pos_x, pos_y, self.dim_x, self.dim_y });
//             return error.SectorOutOfBounds;
//         }
//         const ttile = self.tile_map.get(.{ .x = pos_x / 8, .y = pos_y / 8 }) orelse {
//             std.debug.print("Sector (0x{x},0x{x}) does not have a terrain tile! It would fit in tile (0x{x},0x{x})\n", .{ pos_x, pos_y, pos_x / 8, pos_y / 8 });
//             return error.TerrainTileNotFound;
//         };
//         return ttile.get_sector(self.arena_state.allocator(), pos_x, pos_y, self.scale);
//     }
//     pub fn get_brush_names_py(self: *@This()) !pyo.ListObject {
//         const arena = self.arena_state.allocator();
//         var brush_names: std.StringHashMapUnmanaged(void) = .empty;
//         defer brush_names.deinit(arena);

//         var tile_iter = self.tile_map.iterator();
//         while (tile_iter.next()) |entry| {
//             const tile = entry.value_ptr.*;
//             for (tile.brushes) |*brush| {
//                 const clean_name = std.mem.sliceTo(&brush.name.bytes, 0);
//                 try brush_names.put(arena, clean_name, {});
//             }
//         }
//         const brush_name_list: pyo.ListObject = try .initPlaceholders(brush_names.count());
//         var brush_iter = brush_names.iterator();
//         var brush_index: usize = 0;
//         while (brush_iter.next()) |entry| : (brush_index += 1) {
//             const brush_name = entry.key_ptr.*;
//             brush_name_list.setUnchecked(brush_index, try pyo.UnicodeObject.from(brush_name, .cp1252));
//         }
//         return brush_name_list;
//     }
// };

// fn read_terrain(fixed: *XaReader) !Terrain {
//     var terrain: Terrain = .{
//         .arena_state = std.heap.ArenaAllocator.init(std.heap.c_allocator),
//         .unk = try fixed.take(u32),
//         .material = try fixed.take(Name),
//         .scale = try fixed.take(f32),
//         .dim_x = try fixed.take(u32),
//         .dim_y = try fixed.take(u32),
//         .tile_map = .empty,
//     };

//     const arena = terrain.arena_state.allocator();

//     const blocks_n = try fixed.take(u32);
//     for (0..blocks_n) |_| {
//         const block_start = fixed.r.seek;
//         const block_sig = try fixed.take(u32);
//         const block_length = try fixed.take(u32);
//         switch (block_sig) {
//             0xBDAD => {
//                 const ttile = try read_ttile(arena, fixed, block_length);
//                 try terrain.tile_map.put(arena, .{ .x = ttile.pos_x, .y = ttile.pos_y }, ttile);
//             },
//             else => {
//                 std.debug.print("Found an unknown terrain block 0x{x} starting @ 0x{x}\n", .{ block_sig, block_start });
//                 return error.UnknownTTileChunk;
//             },
//         }
//     }
//     // std.debug.print("Finished reading rft...\n", .{});
//     return terrain;
// }

// var terrain_type: ?pyo.TypeObject = null;

// const TerrainObject = extern struct {
//     ob_base: py.PyObject,
//     terrain: *Terrain,
//     material: pyo.UnicodeObject,
// };

// fn terrain_dealloc(self_obj: ?*py.PyObject) callconv(.c) void {
//     const self: *TerrainObject = @ptrCast(@alignCast(self_obj));

//     self.terrain.arena_state.deinit();
//     std.heap.c_allocator.destroy(self.terrain);

//     py.Py_TYPE(self_obj).*.tp_free.?(self_obj);
// }

// fn sector_to_py(sector: TerrainSector) !pyo.TupleObject {
//     const result: pyo.TupleObject = try .initPlaceholders(4);
//     result.setUnchecked(0, try sector.heightmap_to_positions_py());
//     result.setUnchecked(1, try sector.generate_face_indices_py());
//     result.setUnchecked(2, try sector.convert_brushes_to_py());
//     result.setUnchecked(3, try sector.convert_holemap_to_py());
//     return result;
// }

// fn terrain_get_sector(self_obj: ?*py.PyObject, args: ?*py.PyObject) callconv(.c) ?*py.PyObject {
//     const self: *TerrainObject = @ptrCast(@alignCast(self_obj));

//     const terrain = self.terrain;

//     const pos_x: u32, const pos_y: u32 = blk: {
//         var pos_x_raw: c_uint = undefined;
//         var pos_y_raw: c_uint = undefined;
//         if (py.PyArg_ParseTuple(args, "II", &pos_x_raw, &pos_y_raw) == 0) return null;
//         break :blk .{ @intCast(pos_x_raw), @intCast(pos_y_raw) };
//     };

//     const sector = terrain.get_sector(pos_x, pos_y) catch {
//         return null;
//     };

//     const ret_tuple = sector_to_py(sector) catch {
//         return null;
//     };
//     return ret_tuple.toObject().ptr;
// }

// fn terrain_get_brush_names(self_obj: ?*py.PyObject, args: ?*py.PyObject) callconv(.c) ?*py.PyObject {
//     _ = args;

//     const self: *TerrainObject = @ptrCast(@alignCast(self_obj));

//     const ret_collection = self.terrain.get_brush_names_py() catch |err| {
//         std.debug.print("get_brush_names_py error: {}\n", .{err});
//         _ = py.PyErr_NoMemory();
//         return null;
//     };
//     return ret_collection.toObject().ptr;
// }

// const terrain_type_members = [_]py.PyMemberDef{
//     .{
//         .name = "material",
//         .type = py.Py_T_OBJECT_EX,
//         .offset = @offsetOf(TerrainObject, "material"),
//         .flags = 0,
//         .doc = "Terrain material",
//     },
//     .{},
// };

// const terrain_type_methods = [_]py.PyMethodDef{
//     .{
//         .ml_name = "get_sector",
//         .ml_meth = terrain_get_sector,
//         .ml_flags = py.METH_VARARGS,
//         .ml_doc = "Get a terrain sector.",
//     },
//     .{
//         .ml_name = "get_brushes",
//         .ml_meth = terrain_get_brush_names,
//         .ml_flags = py.METH_VARARGS,
//         .ml_doc = "Get brush names.",
//     },
//     std.mem.zeroes(py.PyMethodDef),
// };

// const terrain_type_slots = [_]py.PyType_Slot{
//     .{
//         .slot = py.Py_tp_dealloc,
//         .pfunc = @ptrCast(@constCast(&terrain_dealloc)),
//     },
//     .{
//         .slot = py.Py_tp_methods,
//         .pfunc = @ptrCast(@constCast(&terrain_type_methods)),
//     },
//     .{
//         .slot = py.Py_tp_members,
//         .pfunc = @ptrCast(@constCast(&terrain_type_members)),
//     },
//     std.mem.zeroes(py.PyType_Slot),
// };

// var terrain_type_spec = py.PyType_Spec{
//     .name = "x_rft_zig.Terrain",
//     .basicsize = @sizeOf(TerrainObject),
//     .itemsize = 0,
//     .flags = py.Py_TPFLAGS_DEFAULT,
//     .slots = @ptrCast(@constCast(&terrain_type_slots)),
// };

// fn parse_terrain_py(self: ?*py.PyObject, args: ?*py.PyObject) callconv(.c) ?*py.PyObject {
//     _ = self;

//     //Read the args, check the format, fill in the zig ids with the unpacked result.
//     const bytestream: []u8 = blk: {
//         var bytestream_raw: [*]u8 = undefined;
//         var bytestream_len_raw: py.Py_ssize_t = undefined;
//         if (py.PyArg_ParseTuple(args, "y#", &bytestream_raw, &bytestream_len_raw) == 0) return null; // Python exception already set
//         break :blk bytestream_raw[0..@intCast(bytestream_len_raw)];
//     };

//     var fixed: XaReader = .fixed(bytestream);

//     const terrain_ptr = std.heap.c_allocator.create(Terrain) catch {
//         return null;
//     };
//     errdefer std.heap.c_allocator.destroy(terrain_ptr);

//     terrain_ptr.* = read_terrain(&fixed) catch {
//         return null;
//     };

//     const py_type = if (terrain_type) |tt| tt.ptr else return null;

//     const py_obj = py.PyType_GenericAlloc(py_type, 0) orelse return null;

//     const obj: *TerrainObject = @ptrCast(@alignCast(py_obj));
//     obj.terrain = terrain_ptr;
//     const material = std.mem.sliceTo(&terrain_ptr.material.bytes, 0);
//     obj.material = pyo.UnicodeObject.from(material, .cp1252) catch return null;

//     return py_obj;
// }

// var methods = [_]py.PyMethodDef{
//     .{
//         .ml_name = "parse_terrain",
//         .ml_meth = parse_terrain_py,
//         .ml_flags = py.METH_VARARGS,
//         .ml_doc = "Parse a RFT",
//     },
//     std.mem.zeroes(py.PyMethodDef),
// };

// var module = py.PyModuleDef{
//     .m_base = .{},
//     .m_name = "x_rft_zig",
//     .m_doc = "Zig RFT parser",
//     .m_size = -1,
//     .m_methods = &methods,
// };

// export fn PyInit_x_rft_zig() callconv(.c) ?*py.PyObject {
//     const mod = py.PyModule_Create(&module) orelse return null;

//     //the PyMethodDef goes into the PyType_Slot which go into the PyType_Spec which goes into this
//     const type_obj = pyo.TypeObject.fromSpec(&terrain_type_spec) catch |err| switch (err) {
//         error.Failed => {
//             py.Py_DECREF(mod);
//             return null;
//         },
//     };

//     terrain_type = type_obj;

//     if (py.PyModule_AddObject(mod, "Terrain", type_obj.toObject().ptr) < 0) {
//         py.Py_DECREF(type_obj.toObject().ptr);
//         py.Py_DECREF(mod);
//         return null;
//     }

//     return mod;
// }
