//! In-app updater for the Linux builds on GitHub Releases.
//!
//! Every push to master republishes the packages to the `latest` prerelease
//! under the same version number, so a build from that channel compares the
//! git commit it was built from (`-Dcommit`) with the release's BUILD-INFO.txt.
//! Tagged releases (`-Dchannel=vX.Y.Z`, or a distro build with only
//! `-Dversion`) compare version numbers against the newest stable release.
//! Development and CI builds never update.
//!
//! The check is one HTTPS GET of BUILD-INFO.txt (curl, no user data). An
//! update is used only after the downloaded file matches the release's
//! SHA256SUMS. Tarball installs that this user owns are replaced in place
//! with an atomic directory swap; package-manager files are never touched
//! directly: the matching package manager installs the verified package via
//! pkexec, and AUR / Gentoo users are told what to run.

const std = @import("std");
const builtin = @import("builtin");
const utils = @import("core").utils;
const build_options = @import("build_options");

pub const repository = "4cecoder/talkies";
const releases_url = "https://github.com/" ++ repository ++ "/releases";

/// Written by install-tarball.sh into `<prefix>/lib/talkies/`.
pub const tarball_marker = "install-method";
/// TALKIES_NO_UPDATE_CHECK=1 turns off every update check, automatic or not.
pub const disable_env = "TALKIES_NO_UPDATE_CHECK";

/// What this binary is (build.zig: -Dversion, -Dcommit, -Dchannel).
pub const Build = struct {
    version: []const u8,
    commit: []const u8 = "",
    /// Release label the build was made for: "latest", "vX.Y.Z", "ci-123",
    /// or empty for a distro build that only sets the version.
    channel: []const u8 = "",
};

pub fn currentBuild() Build {
    return .{ .version = build_options.version, .commit = build_options.commit, .channel = build_options.channel };
}

pub const Track = enum {
    /// The rolling `latest` prerelease, compared by commit.
    rolling,
    /// The newest tagged release, compared by version.
    stable,
};

/// The release stream a build follows; null when it cannot update.
pub fn trackOf(build: Build) ?Track {
    if (std.mem.eql(u8, build.channel, "latest")) return if (isCommit(build.commit)) .rolling else null;
    if (build.channel.len == 0) return if (parseVersion(build.version) != null) .stable else null;
    if (build.channel[0] == 'v' and parseVersion(build.channel[1..]) != null) return .stable;
    return null;
}

pub fn disabledByEnv() bool {
    const value = utils.getEnv(disable_env) orelse return false;
    return value.len > 0 and !std.mem.eql(u8, value, "0");
}

/// BUILD-INFO.txt of the release a track follows. `releases/latest/download`
/// is GitHub's redirect to the newest non-prerelease.
pub fn buildInfoUrl(track: Track) []const u8 {
    return switch (track) {
        .rolling => releases_url ++ "/download/latest/BUILD-INFO.txt",
        .stable => releases_url ++ "/latest/download/BUILD-INFO.txt",
    };
}

/// Caller owns the returned URL.
pub fn assetUrl(allocator: std.mem.Allocator, release: []const u8, name: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, releases_url ++ "/download/{s}/{s}", .{ release, name });
}

// ---------------------------------------------------------------------
// Versions and release metadata
// ---------------------------------------------------------------------

pub const Version = struct {
    major: u32,
    minor: u32,
    patch: u32,

    pub fn order(a: Version, b: Version) std.math.Order {
        if (a.major != b.major) return std.math.order(a.major, b.major);
        if (a.minor != b.minor) return std.math.order(a.minor, b.minor);
        return std.math.order(a.patch, b.patch);
    }
};

/// Strict MAJOR.MINOR.PATCH (the only form packaging accepts).
pub fn parseVersion(text: []const u8) ?Version {
    var parts = std.mem.splitScalar(u8, text, '.');
    var numbers: [3]u32 = undefined;
    for (&numbers) |*n| {
        const part = parts.next() orelse return null;
        if (part.len == 0 or part.len > 9) return null;
        for (part) |ch| if (!std.ascii.isDigit(ch)) return null;
        n.* = std.fmt.parseInt(u32, part, 10) catch return null;
    }
    if (parts.next() != null) return null;
    return .{ .major = numbers[0], .minor = numbers[1], .patch = numbers[2] };
}

/// A full 40-character lowercase git commit id.
pub fn isCommit(text: []const u8) bool {
    if (text.len != 40) return false;
    for (text) |ch| if (!std.ascii.isDigit(ch) and !(ch >= 'a' and ch <= 'f')) return false;
    return true;
}

/// A release label that is safe to put in a download URL.
fn isReleaseLabel(text: []const u8) bool {
    if (std.mem.eql(u8, text, "latest")) return true;
    return text.len > 1 and text[0] == 'v' and parseVersion(text[1..]) != null;
}

/// The fields of a release's BUILD-INFO.txt that matter here. The strings
/// point into the parsed text.
pub const Remote = struct {
    commit: []const u8,
    release: []const u8,
    app_version: []const u8,
};

/// Parse `key=value` lines as written by release.yml.
pub fn parseBuildInfo(text: []const u8) !Remote {
    var commit: ?[]const u8 = null;
    var release: ?[]const u8 = null;
    var app_version: ?[]const u8 = null;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        const eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        const key = line[0..eq];
        const value = line[eq + 1 ..];
        if (std.mem.eql(u8, key, "commit")) commit = value;
        if (std.mem.eql(u8, key, "release")) release = value;
        if (std.mem.eql(u8, key, "app_version")) app_version = value;
    }
    const remote: Remote = .{
        .commit = commit orelse return error.InvalidBuildInfo,
        .release = release orelse return error.InvalidBuildInfo,
        .app_version = app_version orelse return error.InvalidBuildInfo,
    };
    if (!isCommit(remote.commit) or !isReleaseLabel(remote.release) or parseVersion(remote.app_version) == null) {
        return error.InvalidBuildInfo;
    }
    return remote;
}

/// Whether `remote` is newer than this build on `track`. On the rolling
/// channel any other commit counts: `latest` only ever moves forward.
pub fn isUpdate(build: Build, track: Track, remote: Remote) bool {
    return switch (track) {
        .rolling => !std.mem.eql(u8, remote.commit, build.commit),
        .stable => blk: {
            const local = parseVersion(build.version) orelse break :blk false;
            const other = parseVersion(remote.app_version) orelse break :blk false;
            break :blk other.order(local) == .gt;
        },
    };
}

// ---------------------------------------------------------------------
// SHA256SUMS
// ---------------------------------------------------------------------

/// The expected SHA-256 of `name` in `sha256sum` output ("<hex>  <name>" or
/// "<hex> *<name>"); null when it is not listed exactly once.
pub fn expectedHash(sums: []const u8, name: []const u8) ?[64]u8 {
    var found: ?[64]u8 = null;
    var lines = std.mem.splitScalar(u8, sums, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trimEnd(u8, raw, "\r");
        if (line.len < 66 or line[64] != ' ') continue;
        const file = if (line[65] == ' ' or line[65] == '*') line[66..] else continue;
        if (!std.mem.eql(u8, file, name)) continue;
        var hex: [64]u8 = undefined;
        for (line[0..64], &hex) |ch, *out| {
            out.* = std.ascii.toLower(ch);
            if (!std.ascii.isDigit(out.*) and !(out.* >= 'a' and out.* <= 'f')) return null;
        }
        if (found != null) return null;
        found = hex;
    }
    return found;
}

pub fn sha256File(path: []const u8) ![64]u8 {
    const file = try std.Io.Dir.openFileAbsolute(utils.io(), path, .{});
    defer file.close(utils.io());
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    var buffer: [256 * 1024]u8 = undefined;
    while (true) {
        const count = file.readStreaming(utils.io(), &.{&buffer}) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
        if (count == 0) break;
        hasher.update(buffer[0..count]);
    }
    var digest: [32]u8 = undefined;
    hasher.final(&digest);
    return std.fmt.bytesToHex(digest, .lower);
}

/// Refuse a file unless SHA256SUMS lists it with exactly this content.
pub fn verify(path: []const u8, sums: []const u8, name: []const u8) !void {
    const expected = expectedHash(sums, name) orelse return error.ChecksumMissing;
    const actual = try sha256File(path);
    if (!std.mem.eql(u8, &expected, &actual)) return error.ChecksumMismatch;
}

// ---------------------------------------------------------------------
// How Talkies was installed
// ---------------------------------------------------------------------

pub const PackageTool = enum {
    apt,
    dnf,
    zypper,
    pacman,

    pub fn extension(self: PackageTool) []const u8 {
        return switch (self) {
            .apt => "deb",
            .dnf, .zypper => "rpm",
            .pacman => "pkg.tar.zst",
        };
    }
};

pub const Install = union(enum) {
    /// install-tarball.sh tree; `writable` when this user can replace it.
    tarball: struct { prefix: []const u8, writable: bool },
    /// Our .deb / .rpm / Arch package, owned by that package manager.
    package: PackageTool,
    /// talkies-bin from the AUR: the AUR helper updates it.
    aur,
    /// The Talkies overlay; carries the package atom.
    gentoo: []const u8,
    /// zig-out or another source checkout.
    development,
    unknown,

    pub fn describe(self: Install) []const u8 {
        return switch (self) {
            .tarball => "tarball (install.sh)",
            .package => |tool| switch (tool) {
                .apt => "Debian package (apt)",
                .dnf => "RPM package (dnf)",
                .zypper => "RPM package (zypper)",
                .pacman => "Arch package (pacman)",
            },
            .aur => "AUR package talkies-bin",
            .gentoo => "Gentoo overlay",
            .development => "development build",
            .unknown => "unknown install",
        };
    }

    /// What to tell users whose package manager Talkies must not drive.
    pub fn manualInstructions(self: Install) ?[]const u8 {
        return switch (self) {
            .aur => "Update talkies-bin with your AUR helper (for example: yay -Syu talkies-bin).",
            .gentoo => |atom| if (std.mem.endsWith(u8, atom, "-bin"))
                "Sync the Talkies overlay, then run: emerge --ask --update app-accessibility/talkies-bin"
            else
                "Sync the Talkies overlay, then run: emerge --ask --update app-accessibility/talkies",
            .tarball, .package => null,
            .development => "This is a development build; rebuild from source to update.",
            .unknown => "Download the new package from GitHub Releases and install it the way you installed Talkies.",
        };
    }

    /// Release asset this install method needs, e.g. Talkies-Linux-latest.deb.
    pub fn assetName(self: Install, buf: []u8, release: []const u8) ?[]const u8 {
        const extension = switch (self) {
            .tarball => "tar.gz",
            .package => |tool| tool.extension(),
            else => return null,
        };
        return std.fmt.bufPrint(buf, "Talkies-Linux-{s}.{s}", .{ release, extension }) catch null;
    }
};

pub const Probe = struct {
    /// Prepended to every system path; tests point it at a temporary tree.
    root: []const u8 = "",
    /// The running binary as an absolute path on the real system.
    exe: []const u8,
    /// Confirm RPM ownership with `rpm -qf` (tests have no rpm database).
    query_rpm: bool = true,
};

const app_suffix = "/lib/talkies";

/// Work out who owns the running binary. Strings in the result point into
/// `probe.exe`.
pub fn detectInstall(allocator: std.mem.Allocator, probe: Probe) !Install {
    if (std.mem.indexOf(u8, probe.exe, "/zig-out/") != null) return .development;
    const app_dir = std.fs.path.dirname(probe.exe) orelse return .unknown;
    const prefix: ?[]const u8 = if (std.mem.endsWith(u8, app_dir, app_suffix)) app_dir[0 .. app_dir.len - app_suffix.len] else null;

    // install.sh marks its own trees, whatever the prefix.
    if (prefix) |p| {
        const marker = try rootedPath(allocator, probe.root, &.{ app_dir, "/", tarball_marker });
        defer allocator.free(marker);
        if (fileContains(allocator, marker, "tarball")) return .{ .tarball = .{ .prefix = p, .writable = try tarballWritable(allocator, probe.root, app_dir) } };
    }

    // dpkg lists every file it installed.
    const dpkg_list = try rootedPath(allocator, probe.root, &.{"/var/lib/dpkg/info/talkies.list"});
    defer allocator.free(dpkg_list);
    if (fileHasLine(allocator, dpkg_list, probe.exe)) return .{ .package = .apt };

    if (std.mem.eql(u8, app_dir, "/usr/lib/talkies")) {
        if (try findPackageDir(allocator, probe.root, "/var/lib/pacman/local")) |name| {
            return if (std.mem.eql(u8, name, "talkies-bin")) .aur else .{ .package = .pacman };
        }
    }
    if (try findPackageDir(allocator, probe.root, "/var/db/pkg/app-accessibility")) |name| {
        return .{ .gentoo = if (std.mem.eql(u8, name, "talkies-bin")) "app-accessibility/talkies-bin" else "app-accessibility/talkies" };
    }
    if (std.mem.eql(u8, app_dir, "/usr/lib/talkies") and try rpmOwns(allocator, probe)) {
        const zypper = try rootedPath(allocator, probe.root, &.{"/usr/bin/zypper"});
        defer allocator.free(zypper);
        return .{ .package = if (exists(zypper)) .zypper else .dnf };
    }

    // Tarballs installed before the marker existed: <prefix>/bin/talkies.
    if (prefix) |p| {
        if (!std.mem.eql(u8, app_dir, "/usr/lib/talkies")) {
            const link = try rootedPath(allocator, probe.root, &.{ p, "/bin/talkies" });
            defer allocator.free(link);
            if (exists(link)) return .{ .tarball = .{ .prefix = p, .writable = try tarballWritable(allocator, probe.root, app_dir) } };
        }
    }
    return .unknown;
}

fn rootedPath(allocator: std.mem.Allocator, root: []const u8, parts: []const []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.appendSlice(allocator, root);
    for (parts) |part| try out.appendSlice(allocator, part);
    return out.toOwnedSlice(allocator);
}

fn exists(path: []const u8) bool {
    std.Io.Dir.cwd().access(utils.io(), path, .{}) catch return false;
    return true;
}

fn writableDir(path: []const u8) bool {
    std.Io.Dir.cwd().access(utils.io(), path, .{ .write = true }) catch return false;
    return true;
}

/// Replacing `<prefix>/lib/talkies` needs write access to it and its parent.
fn tarballWritable(allocator: std.mem.Allocator, root: []const u8, app_dir: []const u8) !bool {
    const dir = try rootedPath(allocator, root, &.{app_dir});
    defer allocator.free(dir);
    const parent = std.fs.path.dirname(dir) orelse return false;
    return writableDir(dir) and writableDir(parent);
}

fn readSmall(allocator: std.mem.Allocator, path: []const u8) ?[]u8 {
    return std.Io.Dir.cwd().readFileAlloc(utils.io(), path, allocator, .limited(1024 * 1024)) catch null;
}

fn fileContains(allocator: std.mem.Allocator, path: []const u8, needle: []const u8) bool {
    const bytes = readSmall(allocator, path) orelse return false;
    defer allocator.free(bytes);
    return std.mem.indexOf(u8, bytes, needle) != null;
}

fn fileHasLine(allocator: std.mem.Allocator, path: []const u8, line: []const u8) bool {
    const bytes = readSmall(allocator, path) orelse return false;
    defer allocator.free(bytes);
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |l| if (std.mem.eql(u8, std.mem.trimEnd(u8, l, "\r"), line)) return true;
    return false;
}

/// "talkies" or "talkies-bin" when a `<name>-<version>` entry exists in a
/// pacman or Portage database directory.
fn findPackageDir(allocator: std.mem.Allocator, root: []const u8, db: []const u8) !?[]const u8 {
    const path = try rootedPath(allocator, root, &.{db});
    defer allocator.free(path);
    var dir = std.Io.Dir.openDirAbsolute(utils.io(), path, .{ .iterate = true }) catch return null;
    defer dir.close(utils.io());
    var it = dir.iterate();
    while (it.next(utils.io()) catch return null) |entry| {
        for ([_][]const u8{ "talkies-bin", "talkies" }) |name| {
            if (entry.name.len > name.len + 1 and std.mem.startsWith(u8, entry.name, name) and
                entry.name[name.len] == '-' and std.ascii.isDigit(entry.name[name.len + 1])) return name;
        }
    }
    return null;
}

fn rpmOwns(allocator: std.mem.Allocator, probe: Probe) !bool {
    var found = false;
    for ([_][]const u8{ "/var/lib/rpm", "/usr/lib/sysimage/rpm" }) |db| {
        const path = try rootedPath(allocator, probe.root, &.{db});
        defer allocator.free(path);
        if (exists(path)) found = true;
    }
    if (!found) return false;
    if (!probe.query_rpm) return true;
    utils.runQuiet(&.{ "rpm", "-qf", "--quiet", probe.exe }) catch return false;
    return true;
}

/// The running binary (resolved), for detectInstall. Caller owns it.
pub fn currentExe(allocator: std.mem.Allocator) ![]u8 {
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const rc = std.os.linux.readlink("/proc/self/exe", &buf, buf.len);
    if (std.os.linux.errno(rc) != .SUCCESS) return error.ExecutableNotFound;
    return allocator.dupe(u8, buf[0..rc]);
}

// ---------------------------------------------------------------------
// Checking (one HTTPS GET, no user data)
// ---------------------------------------------------------------------

/// A newer release; strings are owned by `arena`.
pub const Available = struct {
    arena: std.heap.ArenaAllocator,
    remote: Remote,
    track: Track,

    pub fn deinit(self: *Available) void {
        self.arena.deinit();
    }

    /// "0.1.6", or "0.1.5 (1a2b3c4)" for the rolling channel.
    pub fn label(self: *const Available, buf: []u8) []const u8 {
        return switch (self.track) {
            .stable => self.remote.app_version,
            .rolling => std.fmt.bufPrint(buf, "{s} ({s})", .{ self.remote.app_version, self.remote.commit[0..7] }) catch self.remote.app_version,
        };
    }
};

/// curl over HTTPS only (redirects included); no cookies, headers or user data.
const curl = [_][]const u8{ "curl", "--fail", "--silent", "--show-error", "--location", "--proto", "=https", "--proto-redir", "=https" };

/// Small text file into memory. Caller owns it.
fn fetchText(allocator: std.mem.Allocator, url: []const u8) ![]u8 {
    const argv = curl ++ [_][]const u8{ "--max-time", "30", "--max-filesize", "65536", url };
    return utils.runCapture(allocator, &argv) catch return error.UpdateCheckFailed;
}

/// Null when this build is current. error.UpdatesUnavailable for builds
/// that do not follow a release channel, error.UpdatesDisabled when
/// TALKIES_NO_UPDATE_CHECK is set.
pub fn check(allocator: std.mem.Allocator, build: Build) !?Available {
    if (disabledByEnv()) return error.UpdatesDisabled;
    const track = trackOf(build) orelse return error.UpdatesUnavailable;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const text = try fetchText(arena.allocator(), buildInfoUrl(track));
    const remote = try parseBuildInfo(text);
    if (!isUpdate(build, track, remote)) {
        arena.deinit();
        return null;
    }
    return .{ .arena = arena, .remote = remote, .track = track };
}

// ---------------------------------------------------------------------
// Downloading and installing
// ---------------------------------------------------------------------

/// `$XDG_CACHE_HOME/talkies/updates` (0700), emptied before each download.
/// Caller owns the returned path.
fn updatesDir(allocator: std.mem.Allocator) ![]u8 {
    const base = if (utils.getEnv("XDG_CACHE_HOME")) |cache| if (cache.len > 0)
        try std.fmt.allocPrint(allocator, "{s}/talkies/updates", .{cache})
    else
        null else null;
    const dir = base orelse blk: {
        const home = utils.getEnv("HOME") orelse return error.NoHomeDir;
        break :blk try std.fmt.allocPrint(allocator, "{s}/.cache/talkies/updates", .{home});
    };
    errdefer allocator.free(dir);
    std.Io.Dir.cwd().deleteTree(utils.io(), dir) catch {};
    try utils.ensureDir(dir);
    try chmodPrivate(allocator, dir);
    return dir;
}

fn chmodPrivate(allocator: std.mem.Allocator, path: []const u8) !void {
    const path_z = try utils.dupeZ(allocator, path);
    defer allocator.free(path_z);
    if (std.c.chmod(path_z.ptr, 0o700) != 0) return error.AccessDenied;
}

pub const Installed = struct {
    /// Binary to start for the new version.
    exe: []const u8,
};

/// Download the asset for `install`, verify it against SHA256SUMS, and
/// install it. Blocks (run it off the main loop); pkexec may show a polkit
/// prompt. Returns the binary to restart into, owned by `allocator`.
pub fn install(allocator: std.mem.Allocator, available: *const Available, method: Install) ![]u8 {
    var name_buf: [128]u8 = undefined;
    const name = method.assetName(&name_buf, available.remote.release) orelse return error.UpdateNotSupported;

    const work = try updatesDir(allocator);
    defer allocator.free(work);
    defer std.Io.Dir.cwd().deleteTree(utils.io(), work) catch {};

    const sums_url = try assetUrl(allocator, available.remote.release, "SHA256SUMS");
    defer allocator.free(sums_url);
    const sums = try fetchText(allocator, sums_url);
    defer allocator.free(sums);
    const expected = expectedHash(sums, name) orelse return error.ChecksumMissing;

    const path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ work, name });
    defer allocator.free(path);
    const url = try assetUrl(allocator, available.remote.release, name);
    defer allocator.free(url);
    utils.log("Downloading {s}", .{url});
    const argv = curl ++ [_][]const u8{ "--max-time", "1800", "--output", path, url };
    utils.runQuiet(&argv) catch return error.UpdateDownloadFailed;
    // Nothing downloaded is used before this check.
    try verify(path, sums, name);
    utils.log("Verified {s} against SHA256SUMS", .{name});

    switch (method) {
        .tarball => |t| {
            if (t.writable) {
                const extracted = try extractTarball(allocator, work, path);
                defer allocator.free(extracted);
                try replaceTarballInstall(allocator, extracted, t.prefix);
            } else {
                // A root-owned prefix (sudo ./install.sh): the verified
                // tarball's own installer, as root.
                try runAsRoot(allocator, &expected, path, root_tarball_script, &.{t.prefix});
            }
            return std.fmt.allocPrint(allocator, "{s}/bin/talkies", .{t.prefix});
        },
        .package => |tool| {
            try runAsRoot(allocator, &expected, path, packageScript(tool), &.{});
            return allocator.dupe(u8, "/usr/bin/talkies");
        },
        else => return error.UpdateNotSupported,
    }
}

/// Root copies the file into a directory only it can write, checks the hash
/// again there, and installs from that copy, so nothing this user can write
/// is trusted between verification and installation. $1 is the downloaded
/// file, $2 its SHA-256, $3 an optional prefix.
fn privilegedScript(comptime extension: []const u8, comptime action: []const u8) []const u8 {
    return "set -eu; d=$(mktemp -d); trap 'rm -rf \"$d\"' EXIT; f=\"$d/update." ++ extension ++ "\"; " ++
        "cp -- \"$1\" \"$f\"; echo \"$2  $f\" | sha256sum --check --quiet; " ++ action;
}

const root_tarball_script = privilegedScript("tar.gz", "tar -xzf \"$f\" -C \"$d\"; \"$d\"/talkies-*/install.sh --prefix \"$3\"");

pub fn packageScript(tool: PackageTool) []const u8 {
    return switch (tool) {
        .apt => privilegedScript("deb", "apt install -y \"$f\""),
        .dnf => privilegedScript("rpm", "dnf install -y \"$f\""),
        .zypper => privilegedScript("rpm", "zypper --non-interactive install --allow-unsigned-rpm \"$f\""),
        .pacman => privilegedScript("pkg.tar.zst", "pacman -U --noconfirm \"$f\""),
    };
}

/// The command shown to the user before asking for approval.
pub fn approvalCommand(tool: PackageTool) []const u8 {
    return switch (tool) {
        .apt => "pkexec apt install ./Talkies-Linux-<release>.deb",
        .dnf => "pkexec dnf install ./Talkies-Linux-<release>.rpm",
        .zypper => "pkexec zypper install --allow-unsigned-rpm ./Talkies-Linux-<release>.rpm",
        .pacman => "pkexec pacman -U ./Talkies-Linux-<release>.pkg.tar.zst",
    };
}

fn runAsRoot(allocator: std.mem.Allocator, hash: []const u8, file: []const u8, script: []const u8, extra: []const []const u8) !void {
    var argv: std.ArrayList([]const u8) = .empty;
    defer argv.deinit(allocator);
    try argv.appendSlice(allocator, &.{ "pkexec", "/bin/sh", "-c", script, "talkies-update", file, hash });
    try argv.appendSlice(allocator, extra);
    var child = std.process.spawn(utils.io(), .{ .argv = argv.items, .stdin = .ignore }) catch return error.PkexecUnavailable;
    const term = try child.wait(utils.io());
    if (!term.success()) return error.InstallFailed;
}

/// Unpack a verified tarball into `work`; returns its talkies-<version>/ dir.
fn extractTarball(allocator: std.mem.Allocator, work: []const u8, archive: []const u8) ![]u8 {
    const into = try std.fmt.allocPrint(allocator, "{s}/tree", .{work});
    defer allocator.free(into);
    try utils.ensureDir(into);
    utils.runQuiet(&.{ "tar", "-xzf", archive, "-C", into, "--no-same-owner" }) catch return error.InvalidUpdateArchive;
    var dir = try std.Io.Dir.openDirAbsolute(utils.io(), into, .{ .iterate = true });
    defer dir.close(utils.io());
    var it = dir.iterate();
    while (try it.next(utils.io())) |entry| {
        if (entry.kind == .directory and std.mem.startsWith(u8, entry.name, "talkies-")) {
            return std.fmt.allocPrint(allocator, "{s}/{s}", .{ into, entry.name });
        }
    }
    return error.InvalidUpdateArchive;
}

/// Swap `<prefix>/lib/talkies` for the extracted tree's `usr/lib/talkies` in
/// one rename, then refresh the desktop entry, icons and helper scripts.
/// A failure before the swap leaves the installed version untouched.
pub fn replaceTarballInstall(allocator: std.mem.Allocator, extracted: []const u8, prefix: []const u8) !void {
    const app = try std.fmt.allocPrintSentinel(allocator, "{s}/lib/talkies", .{prefix}, 0);
    defer allocator.free(app);
    const staging = try std.fmt.allocPrintSentinel(allocator, "{s}/lib/.talkies-update", .{prefix}, 0);
    defer allocator.free(staging);
    const source = try std.fmt.allocPrint(allocator, "{s}/usr/lib/talkies", .{extracted});
    defer allocator.free(source);

    std.Io.Dir.cwd().deleteTree(utils.io(), staging) catch {};
    // Same filesystem as the install, so the swap below is a rename.
    utils.runQuiet(&.{ "cp", "-a", "--", source, staging }) catch return error.InstallFailed;
    errdefer std.Io.Dir.cwd().deleteTree(utils.io(), staging) catch {};
    const marker = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ staging, tarball_marker });
    defer allocator.free(marker);
    try std.Io.Dir.cwd().writeFile(utils.io(), .{ .sub_path = marker, .data = "tarball\n" });
    // The new binary must start (its libraries resolve via $ORIGIN).
    const staged_exe = try std.fmt.allocPrint(allocator, "{s}/talkies", .{staging});
    defer allocator.free(staged_exe);
    utils.runQuiet(&.{ staged_exe, "--version" }) catch return error.InvalidUpdateArchive;

    try exchangeDirs(staging, app);
    // `staging` now holds the previous version.
    std.Io.Dir.cwd().deleteTree(utils.io(), staging) catch |err| utils.logError("Could not remove the previous version: {}", .{err});

    const share_source = try std.fmt.allocPrint(allocator, "{s}/usr/share/.", .{extracted});
    defer allocator.free(share_source);
    const share = try std.fmt.allocPrint(allocator, "{s}/share", .{prefix});
    defer allocator.free(share);
    try utils.ensureDir(share);
    utils.runQuiet(&.{ "cp", "-a", "--", share_source, share }) catch |err| utils.logError("Could not refresh the menu entry and icons: {}", .{err});
    pinDesktopExec(allocator, prefix) catch |err| utils.logError("Could not update the desktop entry: {}", .{err});
}

/// Atomically exchange two directories (renameat2 RENAME_EXCHANGE); on
/// filesystems without it, two renames.
fn exchangeDirs(a: [:0]const u8, b: [:0]const u8) !void {
    const linux = std.os.linux;
    const rc = linux.renameat2(linux.AT.FDCWD, a.ptr, linux.AT.FDCWD, b.ptr, .{ .EXCHANGE = true });
    switch (linux.errno(rc)) {
        .SUCCESS => return,
        .INVAL, .NOSYS => {},
        else => return error.InstallFailed,
    }
    var old_buf: [std.fs.max_path_bytes]u8 = undefined;
    const old = try std.fmt.bufPrintSentinel(&old_buf, "{s}.old", .{a}, 0);
    if (linux.errno(linux.rename(b.ptr, old.ptr)) != .SUCCESS) return error.InstallFailed;
    if (linux.errno(linux.rename(a.ptr, b.ptr)) != .SUCCESS) {
        _ = linux.rename(old.ptr, b.ptr);
        return error.InstallFailed;
    }
    if (linux.errno(linux.rename(old.ptr, a.ptr)) != .SUCCESS) return error.InstallFailed;
}

/// install.sh points the menu entry at `<prefix>/bin/talkies`; keep it so.
fn pinDesktopExec(allocator: std.mem.Allocator, prefix: []const u8) !void {
    const path = try std.fmt.allocPrint(allocator, "{s}/share/applications/app.talkies.Talkies.desktop", .{prefix});
    defer allocator.free(path);
    const bytes = readSmall(allocator, path) orelse return;
    defer allocator.free(bytes);
    const pinned = try std.fmt.allocPrint(allocator, "Exec={s}/bin/talkies ", .{prefix});
    defer allocator.free(pinned);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    var first = true;
    while (lines.next()) |line| {
        if (!first) try out.append(allocator, '\n');
        first = false;
        if (std.mem.startsWith(u8, line, "Exec=talkies ")) {
            try out.appendSlice(allocator, pinned);
            try out.appendSlice(allocator, line["Exec=talkies ".len..]);
        } else {
            try out.appendSlice(allocator, line);
        }
    }
    try std.Io.Dir.cwd().writeFile(utils.io(), .{ .sub_path = path, .data = out.items });
}

// ---------------------------------------------------------------------
// Restarting
// ---------------------------------------------------------------------

/// The systemd unit running this process, from /proc/self/cgroup
/// ("0::/user.slice/.../app.slice/talkies.service"); null for scopes.
pub fn systemdUnit(cgroup: []const u8) ?[]const u8 {
    var lines = std.mem.splitScalar(u8, cgroup, '\n');
    while (lines.next()) |line| {
        if (!std.mem.startsWith(u8, line, "0::")) continue;
        const unit = std.fs.path.basename(line[3..]);
        if (std.mem.endsWith(u8, unit, ".service") and !std.mem.startsWith(u8, unit, "user@")) return unit;
    }
    return null;
}

extern "c" fn execv(path: [*:0]const u8, argv: [*:null]const ?[*:0]const u8) c_int;

/// Start the new daemon: through systemd when a user unit runs it (the
/// restart job outlives this process), otherwise by exec'ing `exe`.
pub fn relaunchDaemon(allocator: std.mem.Allocator, exe: []const u8) !void {
    if (utils.getEnv("INVOCATION_ID") != null) {
        if (readSmall(allocator, "/proc/self/cgroup")) |cgroup| {
            defer allocator.free(cgroup);
            if (systemdUnit(cgroup)) |unit| {
                utils.runQuiet(&.{ "systemctl", "--user", "--no-block", "restart", unit }) catch |err| {
                    utils.logError("systemctl restart {s} failed: {}", .{ unit, err });
                    return err;
                };
                return;
            }
        }
    }
    // Sockets and device fds must not leak into the new image (the
    // WebSocket port would stay bound).
    const linux = std.os.linux;
    if (linux.errno(linux.close_range(3, std.math.maxInt(linux.fd_t), .{ .UNSHARE = false, .CLOEXEC = true })) != .SUCCESS) {
        var fd: i32 = 3;
        while (fd < 1024) : (fd += 1) _ = linux.fcntl(fd, linux.F.SETFD, linux.FD_CLOEXEC);
    }
    const exe_z = try utils.dupeZ(allocator, exe);
    defer allocator.free(exe_z);
    const argv = [_:null]?[*:0]const u8{ "talkies", "daemon" };
    _ = execv(exe_z.ptr, &argv);
    return error.RelaunchFailed;
}

// ---------------------------------------------------------------------
// Tests (no network; temporary trees stand in for the system)
// ---------------------------------------------------------------------

/// `unit` repeated `n` times, at compile time.
fn repeat(comptime unit: []const u8, comptime n: usize) *const [unit.len * n]u8 {
    const result = comptime blk: {
        var out: [unit.len * n]u8 = undefined;
        for (0..n) |i| @memcpy(out[i * unit.len ..][0..unit.len], unit);
        break :blk out;
    };
    return &result;
}

const commit_a = "1dbce8618b4a2c0f3e5d7a9b1c2d3e4f5a6b7c8d";
const commit_b = "df29b6f0a1b2c3d4e5f60718293a4b5c6d7e8f90";

test "version parsing and ordering" {
    try std.testing.expectEqual(Version{ .major = 0, .minor = 1, .patch = 5 }, parseVersion("0.1.5").?);
    for ([_][]const u8{ "", "1", "1.2", "1.2.3.4", "v1.2.3", "1.2.x", "1..3", "1.2.3-rc1", "dev" }) |bad| {
        try std.testing.expect(parseVersion(bad) == null);
    }
    try std.testing.expectEqual(std.math.Order.gt, parseVersion("0.2.0").?.order(parseVersion("0.1.9").?));
    try std.testing.expectEqual(std.math.Order.gt, parseVersion("0.1.10").?.order(parseVersion("0.1.9").?));
    try std.testing.expectEqual(std.math.Order.eq, parseVersion("1.0.0").?.order(parseVersion("1.0.0").?));
    try std.testing.expectEqual(std.math.Order.lt, parseVersion("1.0.0").?.order(parseVersion("2.0.0").?));
}

test "release track follows the build channel" {
    try std.testing.expectEqual(Track.rolling, trackOf(.{ .version = "0.1.5", .commit = commit_a, .channel = "latest" }).?);
    try std.testing.expectEqual(Track.stable, trackOf(.{ .version = "0.1.5", .channel = "v0.1.5" }).?);
    // Distro builds (Gentoo from source) set only the version.
    try std.testing.expectEqual(Track.stable, trackOf(.{ .version = "0.1.5" }).?);
    try std.testing.expect(trackOf(.{ .version = "dev" }) == null);
    try std.testing.expect(trackOf(.{ .version = "0.1.5", .commit = commit_a, .channel = "ci-123" }) == null);
    // A rolling build without its commit cannot tell whether it is current.
    try std.testing.expect(trackOf(.{ .version = "0.1.5", .channel = "latest" }) == null);
}

test "BUILD-INFO.txt parsing" {
    const text = "commit=" ++ commit_b ++ "\nref=refs/heads/master\nrelease=latest\napp_version=0.1.5\n" ++
        "platforms=macOS,windows-x64,linux-x86_64 (tar.gz, deb, rpm, Arch)\n";
    const remote = try parseBuildInfo(text);
    try std.testing.expectEqualStrings(commit_b, remote.commit);
    try std.testing.expectEqualStrings("latest", remote.release);
    try std.testing.expectEqualStrings("0.1.5", remote.app_version);

    try std.testing.expectError(error.InvalidBuildInfo, parseBuildInfo("release=latest\napp_version=0.1.5\n"));
    try std.testing.expectError(error.InvalidBuildInfo, parseBuildInfo("commit=xyz\nrelease=latest\napp_version=0.1.5\n"));
    // The release label ends up in a URL: nothing but latest or vX.Y.Z.
    try std.testing.expectError(error.InvalidBuildInfo, parseBuildInfo("commit=" ++ commit_b ++ "\nrelease=../../evil\napp_version=0.1.5\n"));
    try std.testing.expectError(error.InvalidBuildInfo, parseBuildInfo("<html>Not Found</html>"));
}

test "update decision: commit on the rolling channel, version on stable" {
    const rolling: Build = .{ .version = "0.1.5", .commit = commit_a, .channel = "latest" };
    try std.testing.expect(isUpdate(rolling, .rolling, .{ .commit = commit_b, .release = "latest", .app_version = "0.1.5" }));
    try std.testing.expect(!isUpdate(rolling, .rolling, .{ .commit = commit_a, .release = "latest", .app_version = "0.1.5" }));

    const stable: Build = .{ .version = "0.1.5", .channel = "v0.1.5" };
    try std.testing.expect(isUpdate(stable, .stable, .{ .commit = commit_b, .release = "v0.1.6", .app_version = "0.1.6" }));
    try std.testing.expect(!isUpdate(stable, .stable, .{ .commit = commit_b, .release = "v0.1.5", .app_version = "0.1.5" }));
    try std.testing.expect(!isUpdate(stable, .stable, .{ .commit = commit_b, .release = "v0.1.4", .app_version = "0.1.4" }));
}

test "SHA256SUMS lookup" {
    const hash_a = repeat("a", 64);
    const hash_b = repeat("0123456789abcdef", 4);
    const sums = hash_a ++ "  Talkies-Linux-latest.tar.gz\n" ++
        hash_b ++ " *Talkies-Linux-latest.deb\r\n" ++
        "short  Talkies-Linux-latest.rpm\n";
    try std.testing.expectEqualStrings(hash_a, &expectedHash(sums, "Talkies-Linux-latest.tar.gz").?);
    try std.testing.expectEqualStrings(hash_b, &expectedHash(sums, "Talkies-Linux-latest.deb").?);
    try std.testing.expect(expectedHash(sums, "Talkies-Linux-latest.rpm") == null);
    try std.testing.expect(expectedHash(sums, "Talkies-Linux-latest") == null);
    // Uppercase hex is normalized; non-hex is refused.
    try std.testing.expectEqualStrings(hash_a, &expectedHash(repeat("A", 64) ++ "  x.deb\n", "x.deb").?);
    try std.testing.expect(expectedHash(repeat("g", 64) ++ "  x.deb\n", "x.deb") == null);
    // A name listed twice is ambiguous.
    try std.testing.expect(expectedHash(hash_a ++ "  x.deb\n" ++ hash_b ++ "  x.deb\n", "x.deb") == null);
}

const TmpTree = struct {
    tmp: std.testing.TmpDir,
    root: [:0]u8,

    fn init() !TmpTree {
        var tmp = std.testing.tmpDir(.{});
        errdefer tmp.cleanup();
        return .{ .tmp = tmp, .root = try tmp.dir.realPathFileAlloc(utils.io(), ".", std.testing.allocator) };
    }

    fn deinit(self: *TmpTree) void {
        std.testing.allocator.free(self.root);
        self.tmp.cleanup();
    }

    fn path(self: *TmpTree, rel: []const u8) ![]u8 {
        return std.fmt.allocPrint(std.testing.allocator, "{s}{s}", .{ self.root, rel });
    }

    fn file(self: *TmpTree, rel: []const u8, data: []const u8) !void {
        const full = try self.path(rel);
        defer std.testing.allocator.free(full);
        try utils.ensureDir(std.fs.path.dirname(full).?);
        try std.Io.Dir.cwd().writeFile(utils.io(), .{ .sub_path = full, .data = data });
    }

    fn dir(self: *TmpTree, rel: []const u8) !void {
        const full = try self.path(rel);
        defer std.testing.allocator.free(full);
        try utils.ensureDir(full);
    }

    fn detect(self: *TmpTree, exe: []const u8) !Install {
        return detectInstall(std.testing.allocator, .{ .root = self.root, .exe = exe, .query_rpm = false });
    }
};

test "install method: tarball marker, legacy tarball, development, unknown" {
    var t = try TmpTree.init();
    defer t.deinit();
    try t.file("/home/u/.local/lib/talkies/install-method", "tarball\n");
    try t.file("/home/u/.local/lib/talkies/talkies", "");
    const marked = try t.detect("/home/u/.local/lib/talkies/talkies");
    try std.testing.expectEqualStrings("/home/u/.local", marked.tarball.prefix);
    try std.testing.expect(marked.tarball.writable);

    // Installed before install.sh wrote the marker.
    try t.file("/usr/local/lib/talkies/talkies", "");
    try t.file("/usr/local/bin/talkies", "");
    try std.testing.expectEqualStrings("/usr/local", (try t.detect("/usr/local/lib/talkies/talkies")).tarball.prefix);

    try std.testing.expect(try t.detect("/src/talkies/linux/zig-out/bin/talkies") == .development);
    try std.testing.expect(try t.detect("/usr/lib/talkies/talkies") == .unknown);
}

test "install method: package managers own /usr/lib/talkies" {
    {
        var t = try TmpTree.init();
        defer t.deinit();
        try t.file("/var/lib/dpkg/info/talkies.list", "/.\n/usr/bin/talkies\n/usr/lib/talkies/talkies\n");
        const found = try t.detect("/usr/lib/talkies/talkies");
        try std.testing.expectEqual(PackageTool.apt, found.package);
        // A tarball elsewhere on the same machine is still a tarball.
        try t.file("/opt/x/lib/talkies/install-method", "tarball\n");
        try std.testing.expect(try t.detect("/opt/x/lib/talkies/talkies") == .tarball);
    }
    {
        var t = try TmpTree.init();
        defer t.deinit();
        try t.dir("/var/lib/pacman/local/talkies-0.1.5-1");
        try t.dir("/var/lib/pacman/local/talkative-1.0-1");
        try std.testing.expectEqual(PackageTool.pacman, (try t.detect("/usr/lib/talkies/talkies")).package);
    }
    {
        var t = try TmpTree.init();
        defer t.deinit();
        try t.dir("/var/lib/pacman/local/talkies-bin-0.1.5-1");
        try std.testing.expect(try t.detect("/usr/lib/talkies/talkies") == .aur);
    }
    {
        var t = try TmpTree.init();
        defer t.deinit();
        try t.dir("/var/db/pkg/app-accessibility/talkies-bin-0.1.5");
        try std.testing.expectEqualStrings("app-accessibility/talkies-bin", (try t.detect("/opt/talkies/talkies")).gentoo);
    }
    {
        var t = try TmpTree.init();
        defer t.deinit();
        try t.dir("/usr/lib/sysimage/rpm");
        try std.testing.expectEqual(PackageTool.dnf, (try t.detect("/usr/lib/talkies/talkies")).package);
        try t.file("/usr/bin/zypper", "");
        try std.testing.expectEqual(PackageTool.zypper, (try t.detect("/usr/lib/talkies/talkies")).package);
    }
}

test "release assets and privileged commands per install method" {
    var buf: [128]u8 = undefined;
    const tarball: Install = .{ .tarball = .{ .prefix = "/home/u/.local", .writable = true } };
    try std.testing.expectEqualStrings("Talkies-Linux-latest.tar.gz", tarball.assetName(&buf, "latest").?);
    try std.testing.expectEqualStrings("Talkies-Linux-v0.1.6.deb", (Install{ .package = .apt }).assetName(&buf, "v0.1.6").?);
    try std.testing.expectEqualStrings("Talkies-Linux-latest.rpm", (Install{ .package = .zypper }).assetName(&buf, "latest").?);
    try std.testing.expectEqualStrings("Talkies-Linux-latest.pkg.tar.zst", (Install{ .package = .pacman }).assetName(&buf, "latest").?);
    try std.testing.expect((Install{ .gentoo = "app-accessibility/talkies" }).assetName(&buf, "latest") == null);
    try std.testing.expect((Install{ .aur = {} }).assetName(&buf, "latest") == null);
    try std.testing.expect((Install{ .aur = {} }).manualInstructions() != null);

    // Root re-verifies its own copy before the package manager sees it.
    const apt = packageScript(.apt);
    try std.testing.expect(std.mem.indexOf(u8, apt, "sha256sum --check") != null);
    try std.testing.expect(std.mem.indexOf(u8, apt, "sha256sum --check").? < std.mem.indexOf(u8, apt, "apt install -y \"$f\"").?);
    try std.testing.expect(std.mem.indexOf(u8, packageScript(.pacman), "pacman -U --noconfirm \"$f\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, packageScript(.zypper), "--allow-unsigned-rpm") != null);
}

test "verification refuses a file whose hash does not match" {
    var t = try TmpTree.init();
    defer t.deinit();
    try t.file("/Talkies-Linux-latest.deb", "abc");
    const path = try t.path("/Talkies-Linux-latest.deb");
    defer std.testing.allocator.free(path);
    const abc = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
    try verify(path, abc ++ "  Talkies-Linux-latest.deb\n", "Talkies-Linux-latest.deb");
    try std.testing.expectError(error.ChecksumMismatch, verify(path, repeat("f", 64) ++ "  Talkies-Linux-latest.deb\n", "Talkies-Linux-latest.deb"));
    try std.testing.expectError(error.ChecksumMissing, verify(path, abc ++ "  other.deb\n", "Talkies-Linux-latest.deb"));
}

test "systemd unit from /proc/self/cgroup" {
    try std.testing.expectEqualStrings("talkies.service", systemdUnit("0::/user.slice/user-1000.slice/user@1000.service/app.slice/talkies.service\n").?);
    try std.testing.expect(systemdUnit("0::/user.slice/user-1000.slice/user@1000.service/app.slice/app-gnome-talkies-4242.scope\n") == null);
    try std.testing.expect(systemdUnit("0::/user.slice/user-1000.slice/user@1000.service\n") == null);
    try std.testing.expect(systemdUnit("12:pids:/user.slice\n") == null);
}

test "tarball update swaps the app directory and keeps the menu entry pinned" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    // cp and the staged binary run as child processes.
    utils.setIoAllocator(std.testing.allocator);
    defer utils.setIoAllocator(.failing);
    var t = try TmpTree.init();
    defer t.deinit();
    try t.file("/prefix/lib/talkies/talkies", "#!/bin/sh\necho talkies 0.1.4\n");
    try t.file("/prefix/lib/talkies/obsolete.so", "old");
    try t.file("/prefix/lib/talkies/install-method", "tarball\n");
    try t.file("/prefix/share/applications/app.talkies.Talkies.desktop", "[Desktop Entry]\nExec=/x/bin/talkies daemon\n");
    try t.file("/new/talkies-0.1.5/usr/lib/talkies/talkies", "#!/bin/sh\necho talkies 0.1.5\n");
    try t.file("/new/talkies-0.1.5/usr/lib/talkies/lib/libtalkies-ui.so.1", "new");
    try t.file("/new/talkies-0.1.5/usr/share/applications/app.talkies.Talkies.desktop", "[Desktop Entry]\nName=Talkies\nExec=talkies daemon\n");
    const new_exe = try t.path("/new/talkies-0.1.5/usr/lib/talkies/talkies");
    defer std.testing.allocator.free(new_exe);
    const new_exe_z = try utils.dupeZ(std.testing.allocator, new_exe);
    defer std.testing.allocator.free(new_exe_z);
    try std.testing.expectEqual(@as(c_int, 0), std.c.chmod(new_exe_z.ptr, 0o755));

    const extracted = try t.path("/new/talkies-0.1.5");
    defer std.testing.allocator.free(extracted);
    const prefix = try t.path("/prefix");
    defer std.testing.allocator.free(prefix);
    try replaceTarballInstall(std.testing.allocator, extracted, prefix);

    for ([_][]const u8{ "/prefix/lib/talkies/talkies", "/prefix/lib/talkies/lib/libtalkies-ui.so.1", "/prefix/lib/talkies/install-method" }) |rel| {
        const p = try t.path(rel);
        defer std.testing.allocator.free(p);
        try std.testing.expect(exists(p));
    }
    for ([_][]const u8{ "/prefix/lib/talkies/obsolete.so", "/prefix/lib/.talkies-update" }) |rel| {
        const p = try t.path(rel);
        defer std.testing.allocator.free(p);
        try std.testing.expect(!exists(p));
    }
    const desktop_path = try t.path("/prefix/share/applications/app.talkies.Talkies.desktop");
    defer std.testing.allocator.free(desktop_path);
    const desktop = readSmall(std.testing.allocator, desktop_path).?;
    defer std.testing.allocator.free(desktop);
    const expected = try std.fmt.allocPrint(std.testing.allocator, "[Desktop Entry]\nName=Talkies\nExec={s}/bin/talkies daemon\n", .{prefix});
    defer std.testing.allocator.free(expected);
    try std.testing.expectEqualStrings(expected, desktop);
}

test "a staged tree whose binary does not run leaves the install untouched" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    // cp and the staged binary run as child processes.
    utils.setIoAllocator(std.testing.allocator);
    defer utils.setIoAllocator(.failing);
    var t = try TmpTree.init();
    defer t.deinit();
    try t.file("/prefix/lib/talkies/talkies", "#!/bin/sh\necho talkies 0.1.4\n");
    // Not executable: --version fails.
    try t.file("/new/talkies-0.1.5/usr/lib/talkies/talkies", "broken");
    const extracted = try t.path("/new/talkies-0.1.5");
    defer std.testing.allocator.free(extracted);
    const prefix = try t.path("/prefix");
    defer std.testing.allocator.free(prefix);
    try std.testing.expectError(error.InvalidUpdateArchive, replaceTarballInstall(std.testing.allocator, extracted, prefix));
    const old = try t.path("/prefix/lib/talkies/talkies");
    defer std.testing.allocator.free(old);
    const bytes = readSmall(std.testing.allocator, old).?;
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqualStrings("#!/bin/sh\necho talkies 0.1.4\n", bytes);
    const staging = try t.path("/prefix/lib/.talkies-update");
    defer std.testing.allocator.free(staging);
    try std.testing.expect(!exists(staging));
}
