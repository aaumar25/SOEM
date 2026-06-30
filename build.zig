const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const gpa = std.heap.smp_allocator;
    const soem_dep = b.dependency("upstream", .{});
    // Default parameter
    const EC_MAXECATFRAME: i64 = 1518;

    // Options
    // Configurable sizes
    const ec_bufsize = b.option(
        i64,
        "EC_BUFSIZE",
        "standard frame buffer size in bytes",
    ) orelse EC_MAXECATFRAME;

    const ec_maxbuf = b.option(
        i64,
        "EC_MAXBUF",
        "number of frame buffers per channel (tx, rx1, rx2)",
    ) orelse 16;

    const ec_maxeepbitmap = b.option(
        i64,
        "EC_MAXEEPBITMAP",
        "size of EEPROM bitmap cache",
    ) orelse 128;

    const ec_maxeepbuf = b.option(
        i64,
        "EC_MAXEEPBUF",
        "size of EEPROM cache buffer",
    ) orelse (ec_maxeepbitmap << 5);

    const ec_loggroupoffset = b.option(
        i64,
        "EC_LOGGROUPOFFSET",
        "default group size in 2^x",
    ) orelse 16;

    const ec_maxelist = b.option(
        i64,
        "EC_MAXELIST",
        "max. entries in EtherCAT error list",
    ) orelse 64;

    const ec_maxname = b.option(
        i64,
        "EC_MAXNAME",
        "max. length of readable name in slavelist and Object Description List",
    ) orelse 40;

    const ec_maxslave = b.option(
        i64,
        "EC_MAXSLAVE",
        "max. number of slaves in array",
    ) orelse 200;

    const ec_maxgroup = b.option(
        i64,
        "EC_MAXGROUP",
        "max. number of groups",
    ) orelse 2;

    const ec_maxiosegments = b.option(
        i64,
        "EC_MAXIOSEGMENTS",
        "max. number of IO segments per group",
    ) orelse 64;

    const ec_maxmbx = b.option(
        i64,
        "EC_MAXMBX",
        "max. mailbox size",
    ) orelse 1486;

    const ec_mbxpoolsize = b.option(
        i64,
        "EC_MBXPOOLSIZE",
        "number of mailboxes in pool",
    ) orelse 32;

    const ec_maxeepdo = b.option(
        i64,
        "EC_MAXEEPDO",
        "max. eeprom PDO entries",
    ) orelse 0x200;

    const ec_maxsm = b.option(
        i64,
        "EC_MAXSM",
        "max. SM used",
    ) orelse 8;

    const ec_maxfmmu = b.option(
        i64,
        "EC_MAXFMMU",
        "max. FMMU used",
    ) orelse 4;

    const ec_maxlen_adaptername = b.option(
        i64,
        "EC_MAXLEN_ADAPTERNAME",
        "max. adapter name length",
    ) orelse 128;

    const ec_max_mapt = b.option(
        i64,
        "EC_MAX_MAPT",
        "maximum number of concurrent threads in mapping",
    ) orelse 1;

    const ec_maxodlist = b.option(
        i64,
        "EC_MAXODLIST",
        "max entries in Object Description list",
    ) orelse 1024;

    const ec_maxoelist = b.option(
        i64,
        "EC_MAXOELIST",
        "max entries in Object Entry list",
    ) orelse 256;

    const ec_soe_maxname = b.option(
        i64,
        "EC_SOE_MAXNAME",
        "max. length of readable SoE name",
    ) orelse 60;

    const ec_soe_maxmapping = b.option(
        i64,
        "EC_SOE_MAXMAPPING",
        "max. number of SoE mappings",
    ) orelse 64;

    // Configurable timeouts and retries
    const ec_timeoutret = b.option(
        i64,
        "EC_TIMEOUTRET",
        "timeout value in us for tx frame to return to rx",
    ) orelse 2000;

    const ec_timeoutret3 = b.option(
        i64,
        "EC_TIMEOUTRET3",
        "timeout value in us for safe data transfer, max. triple retry",
    ) orelse (ec_timeoutret * 3);

    const ec_timeoutsafe = b.option(
        i64,
        "EC_TIMEOUTSAFE",
        "timeout value in us for return \"safe\" variant (f.e. wireless)",
    ) orelse 20000;

    const ec_timeouteep = b.option(
        i64,
        "EC_TIMEOUTEEP",
        "timeout value in us for EEPROM access",
    ) orelse 20000;

    const ec_timeouttxm = b.option(
        i64,
        "EC_TIMEOUTTXM",
        "timeout value in us for tx mailbox cycle",
    ) orelse 20000;

    const ec_timeoutrxm = b.option(
        i64,
        "EC_TIMEOUTRXM",
        "timeout value in us for rx mailbox cycle",
    ) orelse 700000;

    const ec_timeoutstate = b.option(
        i64,
        "EC_TIMEOUTSTATE",
        "timeout value in us for check statechange",
    ) orelse 2000000;

    const ec_defaultretries = b.option(
        i64,
        "EC_DEFAULTRETRIES",
        "default number of retries if wkc <= 0",
    ) orelse 3;

    // MAC addresses
    const ec_primary_mac = b.option(
        []const u8,
        "EC_PRIMARY_MAC",
        "Primary MAC address",
    ) orelse "01:01:01:01:01:01";

    const ec_secondary_mac = b.option(
        []const u8,
        "EC_SECONDARY_MAC",
        "Secondary MAC address",
    ) orelse "04:04:04:04:04:04";

    const primary_mac_word = try convertMac(gpa, ec_primary_mac);
    defer gpa.free(primary_mac_word);
    const secondary_mac_word = try convertMac(gpa, ec_secondary_mac);
    defer gpa.free(secondary_mac_word);

    // Build SOEM library
    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .sanitize_c = .off,
    });

    // This macro is added because zig cannot install config header with wide
    // char array.
    mod.addCMacro("EC_PRIMARY_MAC_ARRAY", primary_mac_word);
    mod.addCMacro("EC_SECONDARY_MAC_ARRAY", secondary_mac_word);

    // Adding source files
    mod.addCSourceFiles(.{
        .root = soem_dep.path("src"),
        .files = &.{
            "ec_base.c",
            "ec_coe.c",
            "ec_config.c",
            "ec_dc.c",
            "ec_eoe.c",
            "ec_foe.c",
            "ec_main.c",
            "ec_print.c",
            "ec_soe.c",
        },
    });

    // Including required path
    mod.addIncludePath(soem_dep.path("include"));
    mod.addIncludePath(soem_dep.path("osal"));
    const config = b.addConfigHeader(
        .{
            .include_path = "soem/ec_options.h",
        },
        .{
            .EC_BUFSIZE = ec_bufsize,
            .EC_MAXBUF = ec_maxbuf,
            .EC_MAXEEPBITMAP = ec_maxeepbitmap,
            .EC_MAXEEPBUF = ec_maxeepbuf,
            .EC_LOGGROUPOFFSET = ec_loggroupoffset,
            .EC_MAXELIST = ec_maxelist,
            .EC_MAXNAME = ec_maxname,
            .EC_MAXSLAVE = ec_maxslave,
            .EC_MAXGROUP = ec_maxgroup,
            .EC_MAXIOSEGMENTS = ec_maxiosegments,
            .EC_MAXMBX = ec_maxmbx,
            .EC_MBXPOOLSIZE = ec_mbxpoolsize,
            .EC_MAXEEPDO = ec_maxeepdo,
            .EC_MAXSM = ec_maxsm,
            .EC_MAXFMMU = ec_maxfmmu,
            .EC_MAXLEN_ADAPTERNAME = ec_maxlen_adaptername,
            .EC_MAX_MAPT = ec_max_mapt,
            .EC_MAXODLIST = ec_maxodlist,
            .EC_MAXOELIST = ec_maxoelist,
            .EC_SOE_MAXNAME = ec_soe_maxname,
            .EC_SOE_MAXMAPPING = ec_soe_maxmapping,
            .EC_TIMEOUTRET = ec_timeoutret,
            .EC_TIMEOUTRET3 = ec_timeoutret3,
            .EC_TIMEOUTSAFE = ec_timeoutsafe,
            .EC_TIMEOUTEEP = ec_timeouteep,
            .EC_TIMEOUTTXM = ec_timeouttxm,

            .EC_TIMEOUTRXM = ec_timeoutrxm,
            .EC_TIMEOUTSTATE = ec_timeoutstate,
            .EC_DEFAULTRETRIES = ec_defaultretries,
            // SOEM requires MAC in wide char array. This is addressed with
            // Macro above as zig cannot configure wide char array
            // .EC_PRIMARY_MAC_ARRAY = primary_mac_word,
            // .EC_SECONDARY_MAC_ARRAY = secondary_mac_word,
        },
    );
    mod.addConfigHeader(config);
    switch (target.result.os.tag) {
        .windows => {
            mod.addCSourceFile(.{ .file = soem_dep.path("osal/win32/osal.c") });
            mod.addCSourceFiles(.{
                .root = soem_dep.path("oshw/win32"),
                .files = &.{
                    "oshw.c",
                    "nicdrv.c",
                },
            });
            mod.addIncludePath(soem_dep.path("osal/win32"));
            mod.addIncludePath(soem_dep.path("oshw/win32"));
            mod.addIncludePath(soem_dep.path("oshw/win32/wpcap/Include"));
            if (target.result.cpu.arch == .x86) {
                mod.addLibraryPath(soem_dep.path("oshw/win32/wpcap/Lib"));
            } else if (target.result.cpu.arch == .x86_64) {
                mod.addLibraryPath(soem_dep.path("oshw/win32/wpcap/Lib/x64"));
            } else return error.UnsupportedCpuArch;
            mod.linkSystemLibrary("Packet", .{
                .needed = true,
                .preferred_link_mode = .static,
            });
            mod.linkSystemLibrary("wpcap", .{
                .needed = true,
                .preferred_link_mode = .static,
            });
            mod.linkSystemLibrary("ws2_32", .{});
            mod.linkSystemLibrary("winmm", .{});
        },
        .linux => {
            mod.addCSourceFile(.{ .file = soem_dep.path("osal/linux/osal.c") });
            mod.addCSourceFiles(.{
                .root = soem_dep.path("oshw/linux"),
                .files = &.{
                    "oshw.c",
                    "nicdrv.c",
                },
            });
            mod.addIncludePath(soem_dep.path("osal/linux"));
            mod.addIncludePath(soem_dep.path("oshw/linux"));
            mod.linkSystemLibrary("pthread", .{ .needed = true });
            mod.linkSystemLibrary("rt", .{ .needed = true });
        },
        else => return error.UnsupportedOs,
    }
    const soem = b.addLibrary(.{
        .name = "soem",
        .linkage = .static,
        .root_module = mod,
    });
    soem.installHeader(soem_dep.path("osal/osal.h"), "soem/osal.h");
    soem.installHeadersDirectory(
        soem_dep.path("include/soem"),
        "soem",
        .{
            .exclude_extensions = &.{".in"},
        },
    );
    soem.installConfigHeader(config);
    b.installArtifact(soem);
}

/// Converts "AA:BB:CC:DD:EE:FF" to "{0xAABB, 0xCCDD, 0xEEFF}".
fn convertMac(gpa: std.mem.Allocator, mac: []const u8) ![]const u8 {
    // Expected format: exactly 17 chars, "XX:XX:XX:XX:XX:XX"
    if (mac.len != 17) {
        std.log.err("MAC address must be in format XX:XX:XX:XX:XX:XX", .{});
        return error.InvalidMacAddress;
    }

    const w0 = mac[0..2]; // AA
    const w1 = mac[3..5]; // BB
    const w2 = mac[6..8]; // CC
    const w3 = mac[9..11]; // DD
    const w4 = mac[12..14]; // EE
    const w5 = mac[15..17]; // FF
    return try std.fmt.allocPrint(
        gpa,
        "{{0x{s}{s}, 0x{s}{s}, 0x{s}{s}}}",
        .{ w0, w1, w2, w3, w4, w5 },
    );
}
