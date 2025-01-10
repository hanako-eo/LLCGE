pub fn Lazy(comptime T: type, comptime f: fn () T) type {
    return struct {
        inner: ?T,

        const Self = @This();

        pub fn init() Self {
            return Self{ .inner = null };
        }

        pub fn get(self: *Self) *T {
            if (self.inner == null) {
                self.inner = f();
            }

            return &self.inner.?;
        }

        pub fn get_const(self: *Self) *const T {
            return self.get();
        }
    };
}
