const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

/// Simple WebSocket server for Talkies daemon using posix sockets
/// Handles text messages only, no binary support needed
pub const Server = struct {
    allocator: std.mem.Allocator,
    socket_fd: posix.socket_t,
    clients: std.ArrayList(*Client),
    running: bool,

    pub const Client = struct {
        socket_fd: posix.socket_t,
        allocator: std.mem.Allocator,

        pub fn init(socket_fd: posix.socket_t, allocator: std.mem.Allocator) !*Client {
            const client = try allocator.create(Client);
            client.* = .{
                .socket_fd = socket_fd,
                .allocator = allocator,
            };
            return client;
        }

        pub fn deinit(self: *Client) void {
            posix.close(self.socket_fd);
            self.allocator.destroy(self);
        }

        pub fn send(self: *Client, message: []const u8) !void {
            // Simple WebSocket frame: FIN=1, opcode=1 (text), no mask
            var frame: std.ArrayList(u8) = .{};
            defer frame.deinit(self.allocator);

            // Frame header
            try frame.append(self.allocator, 0x81); // FIN=1, opcode=1 (text)

            // Payload length
            if (message.len < 126) {
                try frame.append(self.allocator, @intCast(message.len));
            } else if (message.len < 65536) {
                try frame.append(self.allocator, 126);
                try frame.append(self.allocator, @intCast(message.len >> 8));
                try frame.append(self.allocator, @intCast(message.len & 0xFF));
            } else {
                return error.MessageTooLarge;
            }

            // Payload
            try frame.appendSlice(self.allocator, message);

            // Send frame
            _ = try posix.write(self.socket_fd, frame.items);
        }

        pub fn receive(self: *Client, buffer: []u8) ![]const u8 {
            // Read frame header
            var header: [2]u8 = undefined;
            const n = try posix.read(self.socket_fd, &header);
            if (n < 2) return error.ConnectionClosed;

            const opcode = header[0] & 0x0F;
            if (opcode == 0x08) return error.ConnectionClosed; // Close frame

            var len: usize = header[1] & 0x7F;
            const masked = (header[1] & 0x80) != 0;

            // Extended payload length
            if (len == 126) {
                var len_bytes: [2]u8 = undefined;
                _ = try posix.read(self.socket_fd, &len_bytes);
                len = (@as(usize, len_bytes[0]) << 8) | @as(usize, len_bytes[1]);
            }

            // Masking key (clients always mask)
            var mask: [4]u8 = undefined;
            if (masked) {
                _ = try posix.read(self.socket_fd, &mask);
            }

            // Payload
            if (len > buffer.len) return error.BufferTooSmall;
            const payload = buffer[0..len];
            _ = try posix.read(self.socket_fd, payload);

            // Unmask
            if (masked) {
                for (payload, 0..) |*byte, i| {
                    byte.* ^= mask[i % 4];
                }
            }

            return payload;
        }
    };

    pub fn init(allocator: std.mem.Allocator, port: u16) !Server {
        // Create TCP socket
        const sock = try posix.socket(posix.AF.INET, posix.SOCK.STREAM, 0);
        errdefer posix.close(sock);

        // Set SO_REUSEADDR and SO_REUSEPORT for rapid restart
        try posix.setsockopt(
            sock,
            posix.SOL.SOCKET,
            posix.SO.REUSEADDR,
            &std.mem.toBytes(@as(c_int, 1)),
        );
        try posix.setsockopt(
            sock,
            posix.SOL.SOCKET,
            posix.SO.REUSEPORT,
            &std.mem.toBytes(@as(c_int, 1)),
        );

        // Bind to address
        const addr = posix.sockaddr.in{
            .family = posix.AF.INET,
            .port = std.mem.nativeToBig(u16, port),
            .addr = 0x0100007F, // 127.0.0.1 in network byte order
            .zero = [_]u8{0} ** 8,
        };
        const sockaddr = @as(*const posix.sockaddr, @ptrCast(&addr));
        try posix.bind(sock, sockaddr, @sizeOf(posix.sockaddr.in));

        // Listen
        try posix.listen(sock, 128);

        return Server{
            .allocator = allocator,
            .socket_fd = sock,
            .clients = .{},
            .running = false,
        };
    }

    pub fn deinit(self: *Server) void {
        for (self.clients.items) |client| {
            client.deinit();
        }
        self.clients.deinit(self.allocator);
        posix.close(self.socket_fd);
    }

    pub fn start(self: *Server, comptime onMessage: anytype, context: anytype) !void {
        self.running = true;
        std.debug.print("WebSocket server listening on ws://127.0.0.1:6789\n", .{});

        while (self.running) {
            // Accept connection
            var client_addr: posix.sockaddr.in = undefined;
            var addr_len: posix.socklen_t = @sizeOf(posix.sockaddr.in);

            // Use direct syscall to work around error set mismatch
            const rc = linux.accept4(@intCast(self.socket_fd), @ptrCast(&client_addr), &addr_len, 0);
            const client_sock: posix.socket_t = if (rc < 0) {
                std.debug.print("Accept error: {d}\n", .{-rc});
                posix.nanosleep(0, 100 * std.time.ns_per_ms);
                continue;
            } else @intCast(rc);

            // Handle WebSocket handshake
            self.handleHandshake(client_sock) catch |err| {
                std.debug.print("Handshake error: {}\n", .{err});
                posix.close(client_sock);
                continue;
            };

            // Add client
            const client = try Client.init(client_sock, self.allocator);
            try self.clients.append(self.allocator, client);
            std.debug.print("Client connected (total: {})\n", .{self.clients.items.len});

            // Handle incoming messages in a loop for this client
            while (true) {
                var message_buf: [4096]u8 = undefined;
                const message = client.receive(&message_buf) catch |err| {
                    std.debug.print("Client disconnected: {}\n", .{err});
                    // Remove client from list
                    var i: usize = 0;
                    while (i < self.clients.items.len) {
                        if (self.clients.items[i] == client) {
                            client.deinit();
                            _ = self.clients.orderedRemove(i);
                            std.debug.print("Client removed (total: {})\n", .{self.clients.items.len});
                            break;
                        }
                        i += 1;
                    }
                    break; // Exit client message loop
                };

                // Call message handler
                onMessage(self.allocator, message, context) catch |err| {
                    std.debug.print("Message handler error: {}\n", .{err});
                };
            }
        }
    }

    fn handleHandshake(self: *Server, socket_fd: posix.socket_t) !void {
        _ = self;
        var buffer: [4096]u8 = undefined;
        const n = try posix.read(socket_fd, &buffer);
        const request = buffer[0..n];

        // Extract Sec-WebSocket-Key
        const key_header = "Sec-WebSocket-Key: ";
        const key_start = std.mem.indexOf(u8, request, key_header) orelse return error.InvalidHandshake;
        const key_value_start = key_start + key_header.len;
        const key_end = std.mem.indexOfPos(u8, request, key_value_start, "\r\n") orelse return error.InvalidHandshake;
        const client_key = request[key_value_start..key_end];

        // Compute accept key
        const magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
        var combined_buf: [256]u8 = undefined;
        const combined_str = try std.fmt.bufPrint(&combined_buf, "{s}{s}", .{ client_key, magic });

        // SHA1 hash
        var sha1_digest: [20]u8 = undefined;
        std.crypto.hash.Sha1.hash(combined_str, &sha1_digest, .{});

        // Base64 encode
        const base64_encoder = std.base64.standard.Encoder;
        var accept_key: [29]u8 = undefined;
        _ = base64_encoder.encode(&accept_key, &sha1_digest);

        // Send handshake response (use stack buffer for fixed-size response)
        var response_buf: [512]u8 = undefined;
        const response = try std.fmt.bufPrint(&response_buf,
            "HTTP/1.1 101 Switching Protocols\r\n" ++
                "Upgrade: websocket\r\n" ++
                "Connection: Upgrade\r\n" ++
                "Sec-WebSocket-Accept: {s}\r\n" ++
                "\r\n",
            .{accept_key[0..28]},
        );

        _ = try posix.write(socket_fd, response);
    }

    pub fn broadcast(self: *Server, message: []const u8) !void {
        var i: usize = 0;
        while (i < self.clients.items.len) {
            const client = self.clients.items[i];
            client.send(message) catch {
                // Client disconnected, remove it
                client.deinit();
                _ = self.clients.orderedRemove(i);
                std.debug.print("Client disconnected (total: {})\n", .{self.clients.items.len});
                continue;
            };
            i += 1;
        }
    }
};
