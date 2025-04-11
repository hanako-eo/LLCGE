pub fn binary_search(comptime T: type, arr: []const T, x: T) ?T {
    return binary_search_inner(T, arr, 0, arr.len, x);
}

fn binary_search_inner(comptime T: type, arr: []const T, low: usize, high: usize, x: T) ?T {
    var lo = low;
    var hi = high;

    while (lo <= hi) {
        const mid = lo + (hi - lo) / 2;

        if (arr[mid] == x)
            return mid;

        if (arr[mid] < x) {
            lo = mid + 1;
        } else {
            hi = mid - 1;
        }
    }

    return null;
}
