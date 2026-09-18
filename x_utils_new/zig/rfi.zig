const std = @import("std");

// const py = @import("python");
// const pyb = @import("py_bindings.zig");
// const pyo = pyb.object_types;

const xReader = @import("xReader.zig").xReader;
const s = @import("structs.zig");

const print = std.debug.print;

// const Allocator = std.mem.Allocator;

pub const RFI = extern struct {
    name: s.Name,
    fn read(r: *xReader, length: u32) !void {
        _ = r;
        _ = length;
        print("Reading rfi...", .{});
    }
};

// const RFIError = error{UnknownImageFormat};

// const PixelColor = struct {
//     r: f32,
//     g: f32,
//     b: f32,
//     fn from(r: f32, g: f32, b: f32) @This() {
//         return .{ .r = r, .g = g, .b = b };
//     }
// };

// const ColorBlock = packed struct(u64) {
//     const Color = packed struct(u16) {
//         const R = u5;
//         const G = u6;
//         const B = u5;
//         b: B,
//         g: G,
//         r: R,
//     };
//     color0: Color,
//     color1: Color,
//     picked_colors: u32,
// };
// const AlphaBlock = packed struct(u64) {
//     alpha0: u8,
//     alpha1: u8,
//     picked_alphas: u48,
// };

// pub fn pixelColorFromBlockColor(bc: ColorBlock.Color) PixelColor {
//     return .from(
//         @as(f32, bc.r) / std.math.maxInt(@TypeOf(bc.b)),
//         @as(f32, bc.g) / std.math.maxInt(@TypeOf(bc.g)),
//         @as(f32, bc.b) / std.math.maxInt(@TypeOf(bc.r)),
//     );
// }

// pub fn read_bc1_py(reader: *XaReader, width: u32, height: u32) !pyo.ListObject {
//     // std.debug.print("Decompressing bc1...\n", .{});
//     const blocks_x = std.math.divCeil(u32, width, 4) catch unreachable;
//     const blocks_y = std.math.divCeil(u32, height, 4) catch unreachable;
//     const pixels_list: pyo.ListObject = try .initPlaceholders(width * height * 4); //Blender holds pixels as a flattened rgba list; [r0,g0,b0,a0,r1,g1,b1,a1,...]

//     for (0..blocks_y) |block_y_inv| { //Read the blocks upside down...
//         const block_y = blocks_y - 1 - block_y_inv;
//         for (0..blocks_x) |block_x| { //cell
//             const block_pos = block_y * width + block_x;

//             const color_block: ColorBlock = @bitCast(try reader.take(u64));
//             const color0: PixelColor = pixelColorFromBlockColor(color_block.color0);
//             const color1: PixelColor = pixelColorFromBlockColor(color_block.color1);
//             const colors: [4]PixelColor = .{
//                 color0,
//                 color1,
//                 .{
//                     .r = (2.0 * color0.r + color1.r) / 3.0,
//                     .g = (2.0 * color0.g + color1.g) / 3.0,
//                     .b = (2.0 * color0.b + color1.b) / 3.0,
//                 },
//                 .{
//                     .r = (color0.r + 2.0 * color1.r) / 3.0,
//                     .g = (color0.g + 2.0 * color1.g) / 3.0,
//                     .b = (color0.b + 2.0 * color1.b) / 3.0,
//                 },
//             };

//             var picked_colors = color_block.picked_colors;
//             for (0..4) |j_inv| {
//                 const j = 4 - 1 - j_inv;
//                 const pixel_y = block_pos * 4 + j * width;
//                 for (0..4) |i| {
//                     const pixel_pos = pixel_y + i;
//                     const pixel_index = pixel_pos * 4;
//                     const color = colors[picked_colors & 0b11];
//                     pixels_list.setUnchecked(pixel_index, try pyb.float(color.r));
//                     pixels_list.setUnchecked(pixel_index + 1, try pyb.float(color.g));
//                     pixels_list.setUnchecked(pixel_index + 2, try pyb.float(color.b));
//                     pixels_list.setUnchecked(pixel_index + 3, try pyb.float(1.0));

//                     picked_colors >>= 2; //Lop off the color just inspected
//                 }
//             }
//         }
//     }
//     return pixels_list;
// }

// const one_seventh: f32 = 1.0 / 7.0;
// const one_fifth: f32 = 1.0 / 5.0;
// fn interpolate_alphas(alpha0: f32, alpha1: f32) [8]f32 {
//     if (alpha0 > alpha1) {
//         return .{
//             alpha0,
//             alpha1,
//             (6.0 * alpha0 + 1.0 * alpha1) * one_seventh,
//             (5.0 * alpha0 + 2.0 * alpha1) * one_seventh,
//             (4.0 * alpha0 + 3.0 * alpha1) * one_seventh,
//             (3.0 * alpha0 + 4.0 * alpha1) * one_seventh,
//             (2.0 * alpha0 + 5.0 * alpha1) * one_seventh,
//             (1.0 * alpha0 + 6.0 * alpha1) * one_seventh,
//         };
//     } else {
//         return .{
//             alpha0,
//             alpha1,
//             (6.0 * alpha0 + 1.0 * alpha1) * one_seventh,
//             (5.0 * alpha0 + 2.0 * alpha1) * one_seventh,
//             (4.0 * alpha0 + 3.0 * alpha1) * one_seventh,
//             (3.0 * alpha0 + 4.0 * alpha1) * one_seventh,
//             1.0,
//             0.0,
//         };
//     }
// }

// pub fn read_bc4_py(reader: *XaReader, width: u32, height: u32) !pyo.ListObject {
//     // std.debug.print("Decompressing bc4...\n", .{});
//     const blocks_x = std.math.divCeil(u32, width, 4) catch unreachable;
//     const blocks_y = std.math.divCeil(u32, height, 4) catch unreachable;
//     const pixels_list: pyo.ListObject = try .initPlaceholders(width * height * 4); //Blender holds pixels as a flattened rgba list; [r0,g0,b0,a0,r1,g1,b1,a1,...]

//     for (0..blocks_y) |block_y_inv| { //Read it upside down...
//         const block_y = blocks_y - 1 - block_y_inv;
//         for (0..blocks_x) |block_x| { //cell
//             const block_pos = block_y * width + block_x;

//             const alpha_block: AlphaBlock = @bitCast(try reader.take(u64));
//             const alphas = interpolate_alphas(
//                 @as(f32, alpha_block.alpha0) / 0xFF,
//                 @as(f32, alpha_block.alpha1) / 0xFF,
//             );

//             var picked_alphas = alpha_block.picked_alphas;
//             for (0..4) |j_inv| {
//                 const j = 4 - 1 - j_inv;
//                 const pixel_y = block_pos * 4 + j * width;
//                 for (0..4) |i| {
//                     const pixel_pos = pixel_y + i;
//                     const pixel_index = pixel_pos * 4;
//                     const alpha = alphas[picked_alphas & 0b111];

//                     pixels_list.setUnchecked(pixel_index, try pyb.float(alpha));
//                     pixels_list.setUnchecked(pixel_index + 1, try pyb.float(alpha));
//                     pixels_list.setUnchecked(pixel_index + 2, try pyb.float(alpha));
//                     pixels_list.setUnchecked(pixel_index + 3, try pyb.float(1.0));

//                     picked_alphas >>= 3; //Lop off the color just inspected
//                 }
//             }
//         }
//     }
//     return pixels_list;
// }

// pub fn read_bc3_py(reader: *XaReader, width: u32, height: u32) !pyo.ListObject {
//     const blocks_x = std.math.divCeil(u32, width, 4) catch unreachable;
//     const blocks_y = std.math.divCeil(u32, height, 4) catch unreachable;
//     const pixels_list: pyo.ListObject = try .initPlaceholders(width * height * 4); //Blender holds pixels as a flattened rgba list; [r0,g0,b0,a0,r1,g1,b1,a1,...]

//     for (0..blocks_y) |block_y_inv| { //Read it upside down...
//         const block_y = blocks_y - 1 - block_y_inv;
//         for (0..blocks_x) |block_x| { //cell
//             const block_pos = block_y * width + block_x;

//             const alpha_block: AlphaBlock = @bitCast(try reader.take(u64));
//             const alphas = interpolate_alphas(
//                 @as(f32, alpha_block.alpha0) / 0xFF,
//                 @as(f32, alpha_block.alpha1) / 0xFF,
//             );

//             var picked_alphas = alpha_block.picked_alphas;

//             const color_block: ColorBlock = @bitCast(try reader.take(u64));
//             const color0: PixelColor = pixelColorFromBlockColor(color_block.color0);
//             const color1: PixelColor = pixelColorFromBlockColor(color_block.color1);
//             const colors: [4]PixelColor = .{
//                 color0,
//                 color1,
//                 .{
//                     .r = (2.0 * color0.r + color1.r) / 3.0,
//                     .g = (2.0 * color0.g + color1.g) / 3.0,
//                     .b = (2.0 * color0.b + color1.b) / 3.0,
//                 },
//                 .{
//                     .r = (color0.r + 2.0 * color1.r) / 3.0,
//                     .g = (color0.g + 2.0 * color1.g) / 3.0,
//                     .b = (color0.b + 2.0 * color1.b) / 3.0,
//                 },
//             };

//             var picked_colors = color_block.picked_colors;

//             for (0..4) |j_inv| {
//                 const j = 4 - 1 - j_inv;
//                 const pixel_y = block_pos * 4 + j * width;
//                 for (0..4) |i| {
//                     const pixel_pos = pixel_y + i;
//                     const pixel_index = pixel_pos * 4;
//                     const alpha = alphas[picked_alphas & 0b111];
//                     const color = colors[picked_colors & 0b11];

//                     pixels_list.setUnchecked(pixel_index, try pyb.float(color.r));
//                     pixels_list.setUnchecked(pixel_index + 1, try pyb.float(color.g));
//                     pixels_list.setUnchecked(pixel_index + 2, try pyb.float(color.b));
//                     pixels_list.setUnchecked(pixel_index + 3, try pyb.float(alpha));

//                     picked_alphas >>= 3; //Lop off the color just inspected
//                     picked_colors >>= 2; //Lop off the color just inspected
//                 }
//             }
//         }
//     }
//     return pixels_list;
// }

// pub fn read_bc5_py(reader: *XaReader, width: u32, height: u32) !pyo.ListObject {
//     const blocks_x = std.math.divCeil(u32, width, 4) catch unreachable;
//     const blocks_y = std.math.divCeil(u32, height, 4) catch unreachable;
//     const pixels_list: pyo.ListObject = try .initPlaceholders(width * height * 4);

//     for (0..blocks_y) |block_y_inv| { //Read it upside down...
//         const block_y = blocks_y - 1 - block_y_inv;
//         for (0..blocks_x) |block_x| { //cell
//             const block_pos = block_y * width + block_x;

//             const r_block: AlphaBlock = @bitCast(try reader.take(u64));
//             const rs = interpolate_alphas(
//                 @as(f32, r_block.alpha0) / 0xFF,
//                 @as(f32, r_block.alpha1) / 0xFF,
//             );
//             const picked_rs = r_block.picked_alphas;

//             const g_block: AlphaBlock = @bitCast(try reader.take(u64));
//             const gs = interpolate_alphas(
//                 @as(f32, g_block.alpha0) / 0xFF,
//                 @as(f32, g_block.alpha1) / 0xFF,
//             );
//             const picked_gs = g_block.picked_alphas;

//             for (0..4) |j_inv| {
//                 const j = 4 - 1 - j_inv;
//                 const pixel_y = block_pos * 4 + j * width;
//                 for (0..4) |i| {
//                     const pixel_pos = pixel_y + i;
//                     const pixel_index = pixel_pos * 4;
//                     const r = rs[picked_rs & 0b111];
//                     const g = gs[picked_gs & 0b111];

//                     pixels_list.setUnchecked(pixel_index, try pyb.float(r));
//                     pixels_list.setUnchecked(pixel_index + 1, try pyb.float(g));
//                     pixels_list.setUnchecked(pixel_index + 2, try pyb.float(0.0));
//                     pixels_list.setUnchecked(pixel_index + 3, try pyb.float(1.0));
//                 }
//             }
//         }
//     }
//     return pixels_list;
// }

// pub fn read_pixels_py(reader: *XaReader, format: u32, width: u32, height: u32) !pyo.ListObject {
//     //this sucks. figure out the proper way of doing this.
//     switch (format) {
//         0x813BC600, 0x0100C600, 0x01004200 => {
//             return try read_bc1_py(reader, width, height);
//         },
//         0x817BE608, 0x827BA408 => {
//             return try read_bc3_py(reader, width, height);
//         },
//         0x823BC600, 0x813B4200, 0x01006208 => {
//             return try read_bc4_py(reader, width, height);
//         },
//         0x927B8400 => {
//             return try read_bc5_py(reader, width, height);
//         },
//         else => {
//             std.debug.print("Found an unknown image format 0x{x}\n", .{format});
//             return error.UnknownImageFormat;
//         },
//     }
// }

// pub fn read_image_py(reader: *XaReader) !pyo.TupleObject {
//     const width = try reader.take(u32);
//     const height = try reader.take(u32);
//     const single = try reader.take(u32);
//     const options = try reader.take(u32);
//     const flags = try reader.take(u32);
//     const run_flags = try reader.take(u32);
//     const size = try reader.take(u32);
//     _ = single; //Do something with these later...
//     _ = flags;
//     _ = run_flags;
//     _ = size;
//     const tuple: pyo.TupleObject = try .initPlaceholders(3);
//     tuple.setUnchecked(0, try pyb.long(width));
//     tuple.setUnchecked(1, try pyb.long(height));
//     const pixels = try read_pixels_py(reader, options, width, height);
//     tuple.setUnchecked(2, pixels);
//     return tuple;
// }

// pub fn py_meth_read_image(self: ?*py.PyObject, args: ?*py.PyObject) callconv(.c) ?*py.PyObject {
//     _ = self;

//     const bytestream = blk: {
//         var ptr: [*]u8 = undefined;
//         var len: py.Py_ssize_t = undefined;

//         //Read the args, check the format, fill in the zig ids with the unpacked result.
//         if (py.PyArg_ParseTuple(args, "y#", &ptr, &len) == 0) {
//             return null; // Python exception already set
//         }
//         break :blk ptr[0..@intCast(len)];
//     };
//     var reader: XaReader = .fixed(bytestream);

//     const ret_image = read_image_py(&reader) catch {
//         return null;
//     };
//     return ret_image.toObject().ptr;
// }

// var methods = [_]py.PyMethodDef{
//     .{
//         .ml_name = "parse_rfi",
//         .ml_meth = py_meth_read_image,
//         .ml_flags = py.METH_VARARGS,
//         .ml_doc = "Parse a RFC mesh",
//     },
//     std.mem.zeroes(py.PyMethodDef),
// };

// var module = py.PyModuleDef{
//     .m_base = .{},
//     .m_name = "x_rfi_zig",
//     .m_doc = "Zig RFI parser",
//     .m_size = -1,
//     .m_methods = &methods,
// };

// export fn PyInit_x_rfi_zig() callconv(.c) ?*py.PyObject {
//     return py.PyModule_Create(&module);
// }
