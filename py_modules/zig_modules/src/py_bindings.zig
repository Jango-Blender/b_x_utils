const std = @import("std");
const py = @import("python");

pub const OOM = error {OutOfMemory};
pub const OOR = error {OutOfRange};
pub const GenericError = error {Failed};

/// Eases metaprogramming by collapsing object wrappers and raw pointers alike into the same type.
/// Used here to smoothen the use case where you have a *py.BlahObject and there is no BlahObject wrapper.
fn rawPtr(raw_or_wrapper: anytype) *py.PyObject {
    return if (isRawType(@TypeOf(raw_or_wrapper))) raw_or_wrapper else raw_or_wrapper.toObject().ptr;
}

inline fn isRawType(Self: type) bool {
    return Self == *py.PyObject or Self == [*c]py.PyObject;
}
inline fn isObjectType(Self: type) bool {
    comptime {
        for (@typeInfo(object_types).@"opaque".decls) |decl| {
            if (@field(object_types, decl.name) == Self) return true;
        }
        return false;
    }
}

/// Namespace for object type wrappers. Can iterate the decls in here for metaprogramming.
/// Wrappers have:
///   `ptr` field - a plain pointer to the concrete Python type.
///   `toObject` method - upcasts to the basic wrapped type. follow with .ptr to get the basic raw ptr for c interop.
pub const object_types = opaque {
    // namespace
    pub const Object = extern struct {
        ptr: *py.PyObject,
        pub fn toObject(self: object_types.Object) object_types.Object {
            return .{.ptr = @ptrCast(self.ptr)};
        }
    };
    pub const TypeObject = extern struct {
        ptr: *py.PyTypeObject,
        pub fn toObject(self: object_types.TypeObject) object_types.Object {
            return .{.ptr = @ptrCast(self.ptr)};
        }
        
        pub fn fromSpec(spec: *py.PyType_Spec) GenericError!object_types.TypeObject {
            const res = py.PyType_FromSpec(spec) orelse return error.Failed;
            return .{.ptr = @ptrCast(res)};
        }
    };
    pub const ListObject = extern struct {
        ptr: *py.PyListObject,
        pub fn toObject(self: object_types.ListObject) object_types.Object {
            return .{.ptr = @ptrCast(self.ptr)};
        }
        
        pub fn initPlaceholders(len: usize) OOM!object_types.ListObject {
            const ptr = py.PyList_New(@intCast(len)) orelse return error.OutOfMemory;
            return .{.ptr = @ptrCast(ptr)};
        }
        
        pub fn setUnchecked(self: object_types.ListObject, item_i: usize, item: anytype) void {
            _ = py.PyTuple_SetItem(self.toObject().ptr, @intCast(item_i), rawPtr(item));
        }
        
        pub fn set(self: object_types.ListObject, item_i: usize, item: anytype) OOR!void {
            if (py.PyList_SetItem(self.toObject().ptr, @intCast(item_i), rawPtr(item)) != 0) return error.OutOfRange;
        }
    };
    pub const TupleObject = extern struct {
        ptr: *py.PyTupleObject,
        pub fn toObject(self: object_types.TupleObject) object_types.Object {
            return .{.ptr = @ptrCast(self.ptr)};
        }
        
        pub fn initPlaceholders(len: usize) OOM!object_types.TupleObject {
            const ptr = py.PyTuple_New(@intCast(len)) orelse return error.OutOfMemory;
            return .{.ptr = @ptrCast(ptr)};
        }
        
        pub fn setUnchecked(self: object_types.TupleObject, item_i: usize, item: anytype) void {
            _ = py.PyTuple_SetItem(self.toObject().ptr, @intCast(item_i), rawPtr(item));
        }
        
        pub fn set(self: object_types.TupleObject, item_i: usize, item: anytype) OOR!void {
            if (py.PyTuple_SetItem(self.toObject().ptr, @intCast(item_i), rawPtr(item)) != 0) return error.OutOfRange;
        }
    };
    pub const FloatObject = extern struct {
        ptr: *py.PyFloatObject,
        pub fn toObject(self: object_types.FloatObject) object_types.Object {
            return .{.ptr = @ptrCast(self.ptr)};
        }
        
        pub fn from(value: f64) OOM!object_types.FloatObject {
            const ptr = py.PyFloat_FromDouble(value) orelse return error.OutOfMemory;
            return .{.ptr = @ptrCast(ptr)};
        }
    };
    pub const LongObject = extern struct {
        ptr: *py.PyLongObject,
        pub fn toObject(self: object_types.LongObject) object_types.Object {
            return .{.ptr = @ptrCast(self.ptr)};
        }
        
        
        fn sortedLongLongAndLongByBitwidth(signedness: std.builtin.Signedness) struct {Longest: type, Shortest: type} {
            // Bless C for not defining these types relative to each other. So look at whether or not longlong is longer than long.
            const ll, const l = switch (signedness) {
                .signed   => .{c_longlong , c_long },
                .unsigned => .{c_ulonglong, c_ulong},
            };
            return if (@bitSizeOf(ll) > @bitSizeOf(l))
                 .{.Longest = ll, .Shortest = l }
            else .{.Longest = l , .Shortest = ll};
        }
        pub fn from(value: anytype) OOM!object_types.LongObject {
            const preferFn = comptime @"fn":{
                if (@TypeOf(value) == comptime_int) return .from(@as(std.math.IntFittingRange(value, value), value));
                const ll_and_l = sortedLongLongAndLongByBitwidth(@typeInfo(@TypeOf(value)).int.signedness);
                const prefer_type: type = switch (@TypeOf(value)) {
                    usize, isize => |T| T,
                    else => if (@bitSizeOf(@TypeOf(value)) <= @bitSizeOf(ll_and_l.Shortest)) ll_and_l.Shortest else ll_and_l.Longest,
                };
                
                break :@"fn" switch (prefer_type) {
                    usize       => py.PyLong_FromSize_t,
                    isize       => py.PyLong_FromSsize_t,
                    c_long      => py.PyLong_FromLong,
                    c_ulong     => py.PyLong_FromUnsignedLong,
                    c_longlong  => py.PyLong_FromLongLong,
                    c_ulonglong => py.PyLong_FromUnsignedLongLong,
                    else => unreachable,
                };
            };
            const ptr = preferFn(value) orelse return error.OutOfMemory;
            return .{.ptr = @ptrCast(ptr)};
        }
    };
    pub const UnicodeObject = extern struct {
        ptr: *py.PyUnicodeObject,
        pub fn toObject(self: object_types.UnicodeObject) object_types.Object {
            return .{.ptr = @alignCast(@ptrCast(self.ptr))};
        }
        
        pub const Encoding = enum {
            ascii,
            cp1252, // This matches the one used by Exanima strings.
            utf8,
        };
        pub fn from(buffer: []const u8, encoding: Encoding) GenericError!object_types.UnicodeObject {
            const ptr = py.PyUnicode_Decode(buffer.ptr, @intCast(buffer.len), @tagName(encoding), null) orelse return error.Failed;
            return .{.ptr = @ptrCast(ptr)};
        }
    };
};

pub fn float(value: f64) OOM!object_types.FloatObject {
    return try .from(value);
}

pub fn long(value: anytype) OOM!object_types.LongObject {
    return try .from(value);
}