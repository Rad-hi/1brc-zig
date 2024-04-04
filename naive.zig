const std = @import("std");
const fs = std.fs;
const print = std.debug.print;

const MIN: u2 = 0;
const MAX: u2 = 1;
const CNT: u2 = 2;
const SUM: u2 = 3;

var default_arr = [_]f32{99.0, -99.0, 0.0, 0.0};


pub fn main() !void {
    const start_ts = std.time.timestamp();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try fs.cwd().openFile("test.txt", .{});
    // const file = try fs.cwd().openFile("measurements.txt", .{});
    defer file.close();

    // Wrap the file reader in a buffered reader.
    // Since it's usually faster to read a bunch of bytes at once.
    var buf_reader = std.io.bufferedReader(file.reader());
    const reader = buf_reader.reader();

    var line = std.ArrayList(u8).init(allocator);
    defer line.deinit();

    var db = std.StringArrayHashMap([4]f32).init(allocator);
    defer db.deinit();

    const writer = line.writer();
    var line_no: usize = 1;
    while (reader.streamUntilDelimiter(writer, '\n', null)) : (line_no += 1) {
        // Clear the line so we can reuse it.
        defer line.clearRetainingCapacity();

        // create an iterator over the split function
        var it = std.mem.split(u8, line.items, ";");

        // I know i'll only get two values, so I am iterating manually
        var city = it.next().?;
        var value = try std.fmt.parseFloat(f32, it.next().?);

        print("{s} -- {}\n", .{city, value});

        // Ref: https://devlog.hexops.com/2022/zig-hashmaps-explained/#get-a-value-insert-if-not-exist
        var vals = try db.getOrPut(city);
        if (!vals.found_existing) {
            vals.value_ptr.* = default_arr;
        }

        if (vals.value_ptr.*[MIN] > value) {
            vals.value_ptr.*[MIN] = value;
        }
        if (vals.value_ptr.*[MAX] < value) {
            vals.value_ptr.*[MAX] = value;
        }
        vals.value_ptr.*[CNT] += 1;
        vals.value_ptr.*[SUM] += value;

        if (vals.found_existing) {
            print("{s}{any} \n", .{city, vals.value_ptr.*});
        }


    } else |err| switch (err) {
        error.EndOfStream => {}, // Continue on
        else => return err, // Propagate error
    }

    print("{}\n", .{line_no});

    // print the results
    // TODO: missing the sorting of the entries
    print("{s}", .{"{"});
    var db_iterator = db.iterator();
    while (db_iterator.next()) |entry| {
        const city = entry.key_ptr.*;
        const vals = entry.value_ptr.*;
        print("{s}={}/{}/{}, ", .{ city, vals[MIN], vals[SUM] / vals[CNT], vals[MAX] });
    }
    print("{s}\n\n", .{"}"});

    const took = std.time.timestamp() - start_ts;

    print("1brc-zig took: {} s\n", .{took});
}
