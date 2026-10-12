#ifndef TALKIES_LOOP_GLIB_H
#define TALKIES_LOOP_GLIB_H

// Minimal event-loop surface over GLib's default main context, so the Zig
// app can block on real events (fds, timers, GTK input) instead of polling.
// All functions must be called from the main thread.

// Return non-zero to keep the source, zero to remove it.
typedef int (*TalkiesLoopFn)(void *user_data);

// Call fn whenever fd becomes readable (or hangs up). Returns a source id.
unsigned talkies_loop_watch_fd(int fd, TalkiesLoopFn fn, void *user_data);
// Call fn after interval_ms, repeatedly while it returns non-zero.
unsigned talkies_loop_timeout(unsigned interval_ms, TalkiesLoopFn fn, void *user_data);
void talkies_loop_remove(unsigned source_id);
// Run one iteration; blocks until an event arrives when may_block != 0.
void talkies_loop_iterate(int may_block);

#endif
