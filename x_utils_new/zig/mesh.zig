const std = @import("std");
const s = @import("structs.zig");

const xReader = @import("xReader.zig").xReader;
const Allocator = std.mem.Allocator;

const print = std.debug.print;

const MeshError = error{
    NotImplemented,
    UnknownSignature,
    UnknownVertexType,
    UnsupportedBitwidth,
    UnknownMapType,
    UnknownFaceChunk,
    UnknownMeshChunk,
    UnknownPhysicsChunk,
};

const Statics = struct {
    sphere_size: u32 = 0,
    spheres: []s.Vector3df = &.{},
    fn read(r: *xReader, allocator: Allocator, chunktag: u32, length: u32, is_prop: bool) !Statics {
        const start = r.tell();
        if (!is_prop) {
            // std.debug.print("Reading statics @ 0x{x}\n", .{fixed.r.seek});
            const spheres, const size = if (chunktag == 0x3D0CEC04) blk: {
                try r.discard(4); //Null
                const spheres = try allocator.alloc(s.Vector3df, try r.take(u32));
                const size = try r.take(u32);
                try r.readSlice(s.Vector3df, spheres);
                break :blk .{ spheres, size };
            } else blk: {
                const size = try r.take(u32);
                const spheres = try allocator.alloc(s.Vector3df, try r.take(u32));
                try r.readSlice(s.Vector3df, spheres);
                break :blk .{ spheres, size };
            };
            // std.debug.print("Stopped reading statics @ 0x{x}\n", .{fixed.r.seek});
            return .{
                .size = size,
                .spheres = spheres,
            };
        } else {
            r.seek_to(start + length); //Since the spheres will be recreated by the exporter dont bother parsing it.
            return .{
                .raw_data = &.{},
                .size = 0,
                .spheres = &.{},
            };
        }
    }
};

const PhysicsSpheres = struct {
    spheres: []s.Vector4df = &.{},
};

const MotionConstraints = struct {
    constraints: []MotionConstraint = &.{},
};

const MotionConstraint = struct {
    type: u32 = 0,
    v1: s.Vector3df = .{},
    v2: s.Vector3df = .{},
    radius: f32 = 0.0,
    stiffness: f32 = 0.0,
    damping: f32 = 0.0,
    v3: s.Vector3df = .{},
    fn read(r: *xReader) !MotionConstraint {
        const constraint_type = try r.take(u32);
        return .{
            .type = constraint_type,
            .v1 = try r.take(s.Vector3df),
            .v2 = try r.take(s.Vector3df),
            .radius = try r.take(f32),
            .stiffness = try r.take(f32),
            .damping = try r.take(f32),
            .v3 = if (constraint_type & 4 != 0) try r.take(s.Vector3df) else .{},
        };
    }
};

const PhysicsSound = extern struct {
    flag: u32 = 0,
    unk1: u32 = 0,
    unk2: u32 = 0,
    float_0: f32 = 0.0,
    float_1: f32 = 0.0,
    name: s.Name = .{},
    float_2: f32 = 0.0, //Speed?
    float_3: f32 = 0.0, //Pitch?
};

const PhysicsChunk = union(enum) {
    spheres: PhysicsSpheres,
    constraints: MotionConstraints,
    sound: PhysicsSound,
};

const Physics = struct {
    unk_int: u32 = 0,
    density: f32 = 0.0,
    chunks: []PhysicsChunk = &.{},
    fn read(r: *xReader, allocator: Allocator, length: u32) !Physics {
        const start = r.tell();
        const unk_int = try r.take(u32);
        const density = try r.take(f32);
        try r.discard(0x54); //Mostly unused data. Useless for the parser.
        var chunks = std.ArrayList(PhysicsChunk).init(allocator);
        defer chunks.deinit();
        while (r.tell() - start < length) {
            const chunktag = try r.take(u32);
            const chunklength = try r.take(u32);
            _ = chunklength;
            switch (chunktag) {
                0xCD00 => {
                    try r.discard(4); //null
                    const spheres = try allocator.alloc(s.Vector4df, try r.take(u32));
                    try r.readSlice(s.Vector4df, spheres);
                    try chunks.append(.{ .spheres = .{ .spheres = spheres } });
                },
                0xDDB0 => {
                    const motion_constraints = try allocator.alloc(MotionConstraint, try r.take(u32));
                    for (motion_constraints) |*constraint| { //Sometimes the constraints have more data: a third vector.
                        constraint.* = try MotionConstraint.read(r);
                    }
                    try chunks.append(.{ .constraints = .{ .constraints = motion_constraints } });
                },
            }
        }
        return .{
            .unk_int = unk_int,
            .density = density,
            .chunks = try chunks.toOwnedSlice(),
        };
    }
};

const Softbody = struct {
    data: []u8 = &.{},
    fn read(r: *xReader, allocator: Allocator, length: u32) !Softbody {
        return .{ .data = r.read_raw(allocator, length) };
    }
};

const MeshChunk = union(enum) {
    statics: Statics,
    physics: Physics,
    softbody: Softbody,
};

const VertexData = struct {
    vertices: []s.Vector3df = &.{},
    uverts: []s.Vector2df = &.{},
};
fn read_verts(r: *xReader, allocator: Allocator) !VertexData {
    var vertdata: VertexData = undefined;

    const vert_arrays_n = try r.take(u32) + 1;
    for (0..vert_arrays_n) |_| {
        const vstart = r.tell();
        const vflag = try r.take(u32);
        const vtype = try r.take(u32);
        const verts_n = try r.take(u32) + 1;
        _ = vflag;
        switch (vtype & 0xFF0000) {
            0xF30000 => {
                vertdata.vertices = try allocator.alloc(s.Vector3df, verts_n);
                try r.readSlice(s.Vector3df, vertdata.vertices);
            },
            0xF20000 => {
                vertdata.uverts = try allocator.alloc(s.Vector2df, verts_n);
                try r.readSlice(s.Vector2df, vertdata.uverts);
            },
            0xB40000 => {
                try r.discard(4 * verts_n);
            },
            0xA40000 => {
                try r.discard(32 * verts_n);
            },
            else => {
                print("Found an unknown vertex type 0x{x} starting @ 0x{x}\n", .{ vtype, vstart });
                return MeshError.UnknownVertexType;
            },
        }
    }
    return vertdata;
}

const MaterialRange = struct {
    ignored: u32 = 0,
    start: u32 = 0,
    stop: u32 = 0,
    name: s.Name = .{},
    pub fn format(self: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("MaterialRange(name={s}, start=0x{x}, stop=0x{x})", .{ std.mem.sliceTo(&self.name, 0), self.start, self.stop });
    }
};

const MeshMapBitwidth = enum(std.math.IntFittingRange(16, 32)) {
    short = 16,
    long = 32,
};

const MeshMapData = struct {
    cmpverts: u32 = 0,
    bitwidth: MeshMapBitwidth = .short,
    material_ranges: []MaterialRange = &.{},
    edgemap: []u32 = &.{},
    uvmap: []u32 = &.{},
};

fn read_map(r: *xReader, map: []u32, bitwidth: MeshMapBitwidth) !void {
    // For reading the vertexmaps to be used in the facemap.
    // Store them as u32 so it will always have enough bits to store them without needing extra logipy.
    switch (bitwidth) {
        .short => for (map) |*item| {
            item.* = try r.take(u16);
        },
        .long => try r.readSlice(u32, map),
    }
}

fn read_meshmaps(r: *xReader, allocator: Allocator) !MeshMapData {
    var mmd: MeshMapData = undefined;

    const maps_sig = try r.take(u32);
    const maps_length = try r.take(u32);
    _ = maps_length;
    if (maps_sig != 0x3DC0) {
        return MeshError.UnknownSignature;
    }

    try r.discard(4); //null, unused?

    mmd.cmpverts = try r.take(u32) + 1;
    mmd.material_ranges = try allocator.alloc(MaterialRange, try r.take(u32) + 1);
    try r.readSlice(MaterialRange, mmd.material_ranges);

    //The values in the maps are either 16bits or 32bits based on how many cmpverts there are.
    mmd.bitwidth = if (mmd.cmpverts >= 0xFFFF) .long else .short;

    for (0..try r.take(u32) + 1) |_| {
        const vmflag = try r.take(u32);
        switch (vmflag & 0xFF) {
            0x1 => {
                mmd.edgemap = try allocator.alloc(u32, mmd.cmpverts);
                try read_map(r, mmd.edgemap, mmd.bitwidth);
            },
            0x10 => {
                mmd.uvmap = try allocator.alloc(u32, mmd.cmpverts);
                try read_map(r, mmd.uvmap, mmd.bitwidth);
            },
            0x2 => {
                try r.discard(@intFromEnum(mmd.bitwidth) / 8 * mmd.cmpverts); //Unknown map
            },
            else => {
                print("found an unknown vertex map type 0x{x} @ 0x{x}\n", .{ vmflag, r.tell() });
                return MeshError.UnknownMapType;
            },
        }
    }
    return mmd;
}

fn read_faces(r: *xReader, allocator: Allocator, mesh: Mesh, vd: VertexData, mmd: MeshMapData, length: u32, is_prop: bool) !void {
    const start = r.tell();
    try r.discard(4); //null

    const faces_n = try r.take(u32) + 1;
    mesh.face_vert_indices = try allocator.alloc(u32, faces_n * 3); // LOOOOOOPS
    mesh.loop_uvs = try allocator.alloc(s.Vector2df, faces_n * 3);
    const FACE_DATA_TYPE = if (mmd.cmpverts >= 0xFFFF) s.Triple(u32) else s.Triple(u16);
    for (0..faces_n) |i| {
        const face = try r.take(FACE_DATA_TYPE);
        const face_base_index = i * 3;
        for (face.items, 0..) |m_index, j| {
            const loop_index = face_base_index + j;
            mesh.face_vert_indices[loop_index] = mmd.edgemap[m_index];
            mesh.loop_uvs[loop_index] = vd.uverts[mmd.uvmap[m_index]];
        }
    }
    mesh.material_indices = try allocator.alloc(u8, faces_n);
    for (0..mmd.material_ranges.len) |i| {
        for (try r.take(u32)..try r.take(u32)) |j| {
            mesh.material_indices[j] = @intCast(i);
        }
    }

    if (!is_prop) {
        while (r.tell() - start < length) {
            const chunktag = try r.take(u32);
            const chunklength = try r.take(u32);
            _ = chunklength;
            switch (chunktag & 0xFF0F) {
                0x3D02 => {
                    mesh.ints = try allocator.alloc(u8, faces_n);
                    try r.readSlice(u8, mesh.ints);
                },
                0x3D03 => {
                    mesh.flags = try allocator.alloc(u32, faces_n);
                    try r.readSlice(u32, mesh.flags);
                },
                else => {
                    print("Found an unknown face chunk, 0x{x}", .{chunktag});
                    return MeshError.UnknownFaceChunk;
                },
            }
        }
    } else {
        r.seek_to(start + length);
    }
}

pub const Mesh = struct {
    vertices: []s.Vector3df = &.{},
    face_vert_indices: []u32 = &.{},
    loop_uvs: []s.Vector2df = &.{},
    material_indices: []u16 = &.{},
    material_names: []s.Name = &.{},
    faceints: ?[]u8 = null,
    faceflags: ?[]u32 = null,
    chunks: []MeshChunk = &.{},
    pub fn read(r: *xReader, allocator: Allocator, length: u32, start: u32, is_prop: bool) !Mesh {
        var mesh: Mesh = undefined;
        try r.discard(4); //geomflag
        const vd = try read_verts(r, allocator);
        mesh.vertices = vd.vertices;

        const mmd = try read_meshmaps(r, allocator);
        mesh.material_names = try allocator.alloc(s.Name, mmd.material_ranges.len);
        for (mmd.material_ranges, 0..) |mat_range, i| {
            mesh.material_names[i] = mat_range.name;
        }

        var chunks = std.ArrayList(MeshChunk).init(allocator);
        defer chunks.deinit();
        while (r.tell() - start < length) {
            const chunktag = try r.take(u32);
            const chunklength = try r.take(u32);
            switch (chunktag & 0xFFFFFF00) {
                0x00003D00 => read_faces(r, allocator, mesh, vd, mmd, chunklength, is_prop),
                0x3DD0B000 => chunks.append(.{ .physics = try Physics.read(r, allocator, chunklength) }),
                0x3D0CEC00 => chunks.append(.{ .statics = try Statics.read(r, allocator, chunktag, chunklength, is_prop) }),
                0x3DD0C000 => chunks.append(.{ .softbody = try Softbody.read(r, allocator, length) }),
                else => {
                    std.debug.print("Found an unknown mesh chunk 0x{x} @ 0x{x} from the start.\n", .{ chunktag, r.tell() });
                    return error.UnknownMeshChunk;
                },
            }
        }
        mesh.chunks = chunks.toOwnedSlice();
        return mesh;
    }
};
