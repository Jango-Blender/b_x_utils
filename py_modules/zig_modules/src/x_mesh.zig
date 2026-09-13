const std = @import("std");

const OnceSetterSafeGetter = @import("meta.zig").OnceSetterSafeGetter;
const py_wr = @import("py_wrapper_funcs.zig");
const py = @import("python");
const pyb = @import("py_bindings.zig");
const pyo = pyb.object_types;

const XaReader = @import("XaReader.zig");

const structs = @import("structs.zig");
const Vector3df     = structs.Vector3df;
const Vector2df     = structs.Vector2df;
const MaterialRange = structs.MaterialRange;
const Triple        = structs.Triple;
const PhysicsSphere = structs.PhysicsSphere;

const Allocator = std.mem.Allocator;

const ParserError = error {
    NotImplemented,
    UnknownSignature,
    UnknownVertexType,
    UnsupportedBitwidth,
    UnknownMapType,
    UnknownFaceChunk,
    UnknownMeshChunk,
    UnknownPhysicsChunk,
};

const VertexBundle = struct { verts: []Vector3df, uverts: []Vector2df };
fn read_verts(arena: Allocator, fixed: *XaReader) !VertexBundle {
    var chunks: OnceSetterSafeGetter(struct {
        verts : []Vector3df,
        uverts: []Vector2df,
    }) = .empty;
    
    const bundles_n = try std.math.add(u32, try fixed.take(u32), 1);
    for (0..bundles_n) |_| {
        const vstart = fixed.r.seek;
        const vflag = try fixed.take(u32);
        const vtype = try fixed.take(u32);
        const verts_n = try std.math.add(u32, try fixed.take(u32), 1);
        // std.debug.print("Reading vertex type 0x{x} @ 0x{x}\n", .{ vtype, vstart });
        _ = vflag; //unused. dunno what it's for.
        switch (vtype & 0xFF0000) {
            0xF30000 => {
                const verts = try arena.alloc(Vector3df, verts_n);
                try fixed.readSlice(Vector3df, verts);
                try chunks.set(.verts, verts);
            },
            0xF20000 => {
                const uverts = try arena.alloc(Vector2df, verts_n);
                try fixed.readSlice(Vector2df, uverts);
                try chunks.set(.uverts, uverts);
            },
            0xB40000 => {
                try fixed.discard(4 * verts_n); //vert colors. unused?
            },
            0xA40000 => {
                try fixed.discard(verts_n * 32); //bone weights. unused?
            },
            else => {
                std.debug.print("Found an unknown vertex type 0x{x} starting @ 0x{x}\n", .{ vtype, vstart });
                return error.UnknownVertexType;
            },
        }
    }
    // std.debug.print("Finished reading verts @ 0x{x}\n", .{fixed.r.seek});
    // std.debug.print("First Vertex: {f}\n", .{try chunks.get(.verts)});
    // std.debug.print("First UVertex: {f}\n", .{try chunks.get(.verts)});
    return .{.verts = try chunks.get(.verts), .uverts = try chunks.get(.uverts)};
}


fn read_map(fixed: *XaReader, map: []u32, bitwidth: MeshMapBitwidth) !void {
    // For reading the vertexmaps to be used in the facemap.
    // Store them as u32 so it will always have enough bits to store them without needing extra logipy.
    switch (bitwidth) {
        .short => for (map) |*item| { item.* = try fixed.take(u16); },
        .long => try fixed.readSlice(u32, map),
    }
}

const MeshMapBundle = struct {
    cmpverts: u32,
    bitwidth: MeshMapBitwidth,
    materials: []MaterialRange,
    edgemap: []u32,
    uvmap: []u32,
};
const MeshMapBitwidth = enum (std.math.IntFittingRange(16, 32)) {
    short = 16,
    long = 32,
};
fn read_meshmaps(arena: Allocator, fixed: *XaReader) !MeshMapBundle {
    // Make sure it's reading the maps.
    const maps_sig = try fixed.take(u32);
    const maps_length = try fixed.take(u32);
    _ = maps_length;
    if (maps_sig != 0x3DC0) {
        return error.UnknownSignature;
    }

    var chunks: OnceSetterSafeGetter(struct {
        edgemap: []u32,
        uvmap  : []u32,
    }) = .empty;
    
    try fixed.discard(4); //null, unused?
    const cmpverts = try std.math.add(u32, try fixed.take(u32), 1);
    const materials_n = try std.math.add(u32, try fixed.take(u32), 1);
    const materials = try arena.alloc(MaterialRange, materials_n);
    try fixed.readSlice(MaterialRange, materials);

    //The values in the maps are either 16bits or 32bits based on how many cmpverts there are.
    const bitwidth: MeshMapBitwidth = if (cmpverts >= 0xFFFF) .long else .short;

    // std.debug.print("Reading edgemaps @ 0x{x}\n", .{fixed.r.seek});
    const maps_n = try std.math.add(u32, try fixed.take(u32), 1);
    for (0..maps_n) |_| {
        const vmflag = try fixed.take(u32);
        switch (vmflag & 0xFF) {
            0x1 => {
                const edgemap = try arena.alloc(u32, cmpverts);
                try read_map(fixed, edgemap, bitwidth);
                try chunks.set(.edgemap, edgemap);
            },
            0x10 => {
                const uvmap = try arena.alloc(u32, cmpverts);
                try read_map(fixed, uvmap, bitwidth);
                try chunks.set(.uvmap, uvmap);
            },
            0x2 => {
                try fixed.discard(@intFromEnum(bitwidth) / 8 * cmpverts); //Unknown map
            },
            else => {
                return error.UnknownMapType;
            },
        }
    }
    // std.debug.print("First three edgemap values: 0x{x}, 0x{x}, 0x{x}\n", .{ edgemap[0], edgemap[1], edgemap[2] });
    // std.debug.print("First three uvmap values: 0x{x}, 0x{x}, 0x{x}\n", .{ uvmap[0], uvmap[1], uvmap[2] });

    return .{
        .cmpverts = cmpverts,
        .materials = materials,
        .bitwidth = bitwidth,
        .edgemap = try chunks.get(.edgemap),
        .uvmap = try chunks.get(.uvmap),
    };
}

const FaceChunk: type = struct {
    faces_n: u32,
    faces: []Triple(u32),
    material_indices: []u8,
    ints: []u8,
    flags: []u32,
};
fn read_faces(arena: Allocator, fixed: *XaReader, meshmaps: MeshMapBundle, length: u32, is_prop: bool) !FaceChunk {
    const start = fixed.r.seek;
    try fixed.discard(4); //null
    
    const faces_n = try fixed.take(u32) + 1;
    const faces = try arena.alloc(Triple(u32), faces_n);
    // std.debug.print("Reading faces indices @ 0x{x}\n", .{fixed.r.seek});
    for (faces) |*face| {
        switch (meshmaps.bitwidth) {
            .short => {
                const indices = (try fixed.take(Triple(u16))).items;
                face.* = .{.items = .{indices[0], indices[1], indices[2]}};
            },
            .long => {
                face.* = try fixed.take(Triple(u32));
            },
        }
    }
    // std.debug.print("Reading material reminders @ 0x{x}\n", .{fixed.r.seek});
    const material_indices = try arena.alloc(u8, faces_n);
    for (0..meshmaps.materials.len) |i| { //Material Definitions.
        for (try fixed.take(u32)..try fixed.take(u32) + 1) |j| { //start, stop.
            material_indices[j] = @intCast(i);
        }
    }
    
    var chunks: OnceSetterSafeGetter(struct {
        ints : []u8,
        flags: []u32,
    }) = .empty;
    
    if (!is_prop) {
        // std.debug.print("Finished reading faces @ 0x{x}\n", .{fixed.r.seek});
        while (fixed.r.seek - start < length) {
            // const chunk_start = fixed.r.seek;
            const chunktag = try fixed.take(u32);
            const chunklength = try fixed.take(u32);
            // std.debug.print("Reading face chunk 0x{x} @ 0x{x}\n", .{ chunktag, chunk_start });
            _ = chunklength;
            switch (chunktag & 0xFF0F) {
                0x3D02 => {
                    const ints = try arena.alloc(u8, faces_n);
                    try fixed.readSlice(u8, ints);
                    try chunks.set(.ints, ints);
                },
                0x3D03 => {
                    const flags = try arena.alloc(u32, faces_n);
                    try fixed.readSlice(u32, flags);
                    try chunks.set(.flags, flags);
                },
                else => {
                    return error.UnknownFaceChunk;
                },
            }
        }
    } else {
        fixed.r.seek = start + length;
    }

    // std.debug.print("First Face Map Indices: {f}\n", .{facechunk.faces[0]});
    return .{
        .faces_n = faces_n,
        .faces = faces,
        .material_indices = material_indices,
        .ints = try chunks.get(.ints),
        .flags = try chunks.get(.flags),
    };
}

const MotionConstraint = struct {
    type: u32,
    v1: Vector3df,
    v2: Vector3df,
    radius: f32,
    stiffness: f32,
    damping: f32,
    v3: Vector3df,
};
fn read_constraint(fixed: *XaReader) MotionConstraint {
    const constraint_type = try fixed.take(u32);
    return .{
        .type = constraint_type,
        .v1 = try fixed.take(Vector3df),
        .v2 = try fixed.take(Vector3df),
        .radius = try fixed.take(f32),
        .stiffness = try fixed.take(f32),
        .damping = try fixed.take(f32),
        .v3 = if (constraint_type & 4 != 0) try fixed.take(Vector3df) else .{.x = 0, .y = 0, .z = 0},
    };
}

const Physics = struct {
    raw_data: []u8,
    density: f32,
    spheres: []PhysicsSphere,
    motion_constraints: []MotionConstraint,
    sound: [16]u8,
};
fn read_physics(arena: Allocator, fixed: *XaReader, length: u32, is_prop: bool) !Physics {
    const start = fixed.r.seek;
    // std.debug.print("Reading physics @ 0x{x}\n", .{start - 8}); //Where the signature is at.
    if (!is_prop) {
        var chunks: OnceSetterSafeGetter(struct {
            spheres: []PhysicsSphere,
            motion_constraints: []MotionConstraint,
        }) = .empty;
        
        const raw_data = fixed.r.buffered()[0..length];
        const unk_int = try fixed.take(u32);
        _ = unk_int;
        const density = try fixed.take(f32);
        try fixed.discard(0x54); //Mostly unused data. Useless for the parser.
        while (fixed.r.seek - start < length) {
            const chunktag = try fixed.take(u32);
            const chunklength = try fixed.take(u32);
            _ = chunklength;
            switch (chunktag) {
                0xCD00 => { //Collision
                    try fixed.discard(4); //null
                    const spheres = try arena.alloc(PhysicsSphere, try fixed.take(u32));
                    try fixed.readSlice(PhysicsSphere, spheres);
                    try chunks.set(.spheres, spheres);
                },
                0xDDB0 => { //Constraints
                    const motion_constraints = try arena.alloc(MotionConstraint, try fixed.take(u32));
                    try fixed.readSlice(MotionConstraint, motion_constraints);
                    try chunks.set(.motion_constraints, motion_constraints);
                },
                0xDDB3 => { //Sound
                    return error.NotImplemented;
                },
                else => {
                    return error.UnknownPhysicsChunk;
                },
            }
        }
        return .{
            .raw_data = raw_data,
            .density = density,
            .spheres = try chunks.get(.spheres),
            .motion_constraints = try chunks.get(.motion_constraints),
            .sound = @splat(0),
        };
    } else {
        try fixed.discard(length);
        return .{
            .raw_data = &.{},
            .density = 0.0,
            .spheres = &.{},
            .motion_constraints = &.{},
            .sound = @splat(0),
        };
    }
}

const Statics = struct {
    raw_data: []u8,
    size: u32,
    spheres: []Vector3df,
};
fn read_statics(arena: Allocator, fixed: *XaReader, chunktag: u32, length: u32, is_prop: bool) !Statics {
    const start = fixed.r.seek;
    if (!is_prop) {
        const raw_data = fixed.r.buffered()[0..length];
        
        const spheres, const size = if (chunktag == 0x3D0CEC04) blk:{
            try fixed.discard(4); //Null
            const spheres = try arena.alloc(Vector3df, try fixed.take(u32));
            const size = try fixed.take(u32);
            break :blk .{spheres, size};
        } else blk:{
            const size = try fixed.take(u32);
            const spheres = try arena.alloc(Vector3df, try fixed.take(u32));
            break :blk .{spheres, size};
        };
        
        return .{
            .raw_data = raw_data,
            .size = size,
            .spheres = spheres,
        };
    } else {
        fixed.r.seek = start + length; //Since the spheres will be recreated by the exporter dont bother parsing it.
        return .{
            .raw_data = &.{},
            .size = 0,
            .spheres = &.{},
        };
    }
}

const SoftBody = struct {data: []u8};
const MeshResult: type = struct {
    vertexbundle: VertexBundle,
    meshmaps: MeshMapBundle,
    facechunk: FaceChunk,
    physics: Physics,
    statics: Statics,
    softbody: SoftBody,
};
fn parse_mesh(arena: Allocator, data: []u8, is_prop: bool) !MeshResult {
    var fixed: XaReader = .fixed(data);
    try fixed.discard(4); //geomflag

    const vertexbundle: VertexBundle = try read_verts(arena, &fixed);
    const meshmaps: MeshMapBundle = try read_meshmaps(arena, &fixed);
    
    var chunks: OnceSetterSafeGetter(struct {
        facechunk: FaceChunk,
        physics  : Physics  ,
        statics  : Statics  ,
        softbody : SoftBody ,
    }) = .empty;
    
    while (fixed.r.buffered().len > 0) {
        const chunktag = try fixed.take(u32);
        const chunklength = try fixed.take(u32);
        switch (chunktag & 0xFFFFFF00) {
            0x3D00 => try chunks.set(.facechunk, try read_faces(arena, &fixed, meshmaps, chunklength, is_prop)),
            0x3DD0B000 => try chunks.set(.physics, try read_physics(arena, &fixed, chunklength, is_prop)),
            0x3D0CEC00 => try chunks.set(.statics, try read_statics(arena, &fixed, chunktag, chunklength, is_prop)),
            0x3DD0C000 => { //Softbody
                const sb: SoftBody = .{ .data = fixed.r.buffered()[0..chunklength] };
                try fixed.discard(chunklength);
                try chunks.set(.softbody, sb);
            },
            else => return error.UnknownMeshChunk,
        }
    }
    return .{
        .vertexbundle = vertexbundle,
        .meshmaps     = meshmaps,
        .facechunk    = try chunks.get(.facechunk),
        .physics      = try chunks.get(.physics),
        .statics      = try chunks.get(.statics),
        .softbody     = try chunks.get(.softbody),
    };
}

const FaceChunkObjects = struct {
    face_vert_indices: pyo.ListObject,
    loop_uvs: pyo.ListObject,
    material_indices: pyo.ListObject,
    faceints: pyo.ListObject,
    faceflags: pyo.ListObject,
};
fn facechunk_to_py(vertexbundle: VertexBundle, meshmaps: MeshMapBundle, facechunk: FaceChunk, is_prop: bool) !FaceChunkObjects {
    const uverts: []Vector2df = vertexbundle.uverts;
    const edgemap: []u32 = meshmaps.edgemap;
    const uvmap: []u32 = meshmaps.uvmap;
    const faces: []Triple(u32) = facechunk.faces;

    const face_vert_indices_list: pyo.ListObject = try .initPlaceholders(faces.len);
    const loop_uvs_list: pyo.ListObject = try .initPlaceholders(faces.len * 3 * 2); //for use in bpy.types.Mesh.loops.foreach_set ; Need to hold the uvs for each loop.
    for (faces, 0..) |face, i| {
        const tuple: pyo.TupleObject = try .initPlaceholders(3);
        tuple.setUnchecked(0, try pyb.long(edgemap[face.items[2]]));
        tuple.setUnchecked(1, try pyb.long(edgemap[face.items[1]]));
        tuple.setUnchecked(2, try pyb.long(edgemap[face.items[0]]));
        face_vert_indices_list.setUnchecked(i, tuple);
        const base_index = i * 6; //For the uv indexing
        for ([3]u32{ face.items[2], face.items[1], face.items[0] }, 0..) |index, j| {
            const uv = uverts[uvmap[index]];
            loop_uvs_list.setUnchecked(base_index + j * 2    , try pyb.float(uv.x));
            loop_uvs_list.setUnchecked(base_index + j * 2 + 1, try pyb.float(uv.y));
        }
    }
    const material_indices_list: pyo.ListObject = try .initPlaceholders(facechunk.material_indices.len);
    for (facechunk.material_indices, 0..) |mat_i, i| {
        material_indices_list.setUnchecked(i, try pyb.long(mat_i));
    }

    const faceints_list : pyo.ListObject = try .initPlaceholders(facechunk.ints.len);
    const faceflags_list: pyo.ListObject = try .initPlaceholders(facechunk.flags.len);
    if (!is_prop) {
        for (facechunk.ints, 0..) |fi, i| {
            faceints_list.setUnchecked(i, try pyb.long(fi));
        }
        for (facechunk.flags, 0..) |ff, i| {
            faceflags_list.setUnchecked(i, try pyb.long(ff));
        }
    }
    return .{
        .face_vert_indices = face_vert_indices_list,
        .loop_uvs = loop_uvs_list,
        .material_indices = material_indices_list,
        .faceints = faceints_list,
        .faceflags = faceflags_list,
    };
}

fn meshresult_to_py(mr: MeshResult, is_prop: bool) !pyo.TupleObject {
    const result: pyo.TupleObject = try .initPlaceholders(7);
    const p_verts = try py_wr.vector3df_slice_to_python(mr.vertexbundle.verts);
    const material_names: pyo.TupleObject = try .initPlaceholders(mr.meshmaps.materials.len);
    for (mr.meshmaps.materials, 0..) |mat, i| {
        material_names.setUnchecked(i, try pyo.UnicodeObject.from(&mat.name.bytes, .cp1252));
    }
    const p_fc = try facechunk_to_py(mr.vertexbundle, mr.meshmaps, mr.facechunk, is_prop);
    
    result.setUnchecked(0, p_verts);
    result.setUnchecked(1, p_fc.face_vert_indices);
    result.setUnchecked(2, p_fc.loop_uvs);
    result.setUnchecked(3, p_fc.material_indices);
    result.setUnchecked(4, material_names);
    result.setUnchecked(5, p_fc.faceints);
    result.setUnchecked(6, p_fc.faceflags);
    return result;
}

//Wrapper for the zig function. Converts py objects to zig objects and vice versa when needed.
export fn parse_mesh_py(self: ?*py.PyObject, args: ?*py.PyObject) callconv(.c) ?*py.PyObject {
    _ = self;
    
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    
    const bytestream, const is_prop = blk:{
        //Read the args, check the format, fill in the zig ids with the unpacked result.
        var bytestream_raw: [*]u8 = undefined;
        var bytestream_len_raw: py.Py_ssize_t = undefined;
        var is_prop_raw: c_int = undefined;
        if (py.PyArg_ParseTuple(args, "y#p", &bytestream_raw, &bytestream_len_raw, &is_prop_raw) == 0) return null; // Python exception already set
        const bytestream = bytestream_raw[0..@intCast(bytestream_len_raw)];
        const is_prop = is_prop_raw != 0;
        break :blk .{bytestream, is_prop};
    };

    const mesh_result: MeshResult = parse_mesh(arena.allocator(), bytestream, is_prop) catch |err| {
        std.debug.print("parse_mesh failed: {}\n", .{err});
        return null;
    };

    const ret_object = meshresult_to_py(mesh_result, is_prop) catch {
        return null;
    };
    return ret_object.toObject().ptr;
}

var methods = [_]py.PyMethodDef{
    .{
        .ml_name = "parse_mesh",
        .ml_meth = parse_mesh_py,
        .ml_flags = py.METH_VARARGS,
        .ml_doc = "Parse a RFC mesh",
    },
    std.mem.zeroes(py.PyMethodDef),
};

var module = py.PyModuleDef{
    .m_base = .{},
    .m_name = "x_mesh_zig",
    .m_doc = "Zig mesh parser",
    .m_size = -1,
    .m_methods = &methods,
};

export fn PyInit_x_mesh_zig() callconv(.c) ?*py.PyObject {
    return py.PyModule_Create(&module);
}