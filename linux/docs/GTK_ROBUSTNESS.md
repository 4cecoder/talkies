# GTK Robustness and Error Handling

## Overview

This document describes the robustness improvements made to the GTK status window implementation to prevent crashes and ensure stable operation across all GTK4-compatible systems.

## Problem Statement

The original implementation suffered from GTK assertion failures when widgets were accessed after being destroyed:

```
(process:16714): GLib-GObject-CRITICAL **: invalid unclassed pointer in cast to 'GtkLabel'
(process:16714): Gtk-CRITICAL **: gtk_label_set_text: assertion 'GTK_IS_LABEL (self)' failed
```

**Root Cause**: When the GTK window was closed (programmatically or by user), all child widgets were destroyed by GTK, but the `DaemonStatusWindow` struct retained dangling pointers to freed memory. Subsequent attempts to update the status resulted in accessing invalid memory.

## Solution

### 1. Widget Validity Tracking

Added a `widgets_valid` flag to track whether widgets are still accessible:

```c
struct DaemonStatusWindow {
    // ... widget pointers ...

    int initialized;
    int widgets_valid;  // Set to 0 when widgets are destroyed
};
```

### 2. Destruction Signal Handler

Connected to the window's `destroy` signal to mark widgets as invalid:

```c
g_signal_connect(win->window, "destroy", G_CALLBACK(on_window_destroy), win);

static void on_window_destroy(GtkWidget *widget, gpointer user_data) {
    DaemonStatusWindow *win = (DaemonStatusWindow*)user_data;
    if (win) {
        win->widgets_valid = 0;
        win->initialized = 0;
        fprintf(stderr, "[GTK] Window destroyed - all widgets invalidated\n");
    }
}
```

### 3. GTK Type Validation Helpers

Added helper functions that use GTK's built-in type checking macros:

```c
// Validate a widget is still a valid GTK widget
static int is_valid_widget(GtkWidget *widget) {
    return widget != NULL && GTK_IS_WIDGET(widget);
}

// Validate label widget before accessing
static int is_valid_label(GtkWidget *label) {
    return is_valid_widget(label) && GTK_IS_LABEL(label);
}

// Validate text buffer before accessing
static int is_valid_text_buffer(GtkTextBuffer *buffer) {
    return buffer != NULL && GTK_IS_TEXT_BUFFER(buffer);
}

// Validate check button before accessing
static int is_valid_check_button(GtkWidget *check) {
    return is_valid_widget(check) && GTK_IS_CHECK_BUTTON(check);
}
```

### 4. Defensive Widget Access

Every function that accesses widgets now performs multiple validation checks:

```c
void daemon_status_window_set_state(DaemonStatusWindow *win, const char *state) {
    // Check struct validity
    if (!win || !win->initialized || !win->widgets_valid || !state) return;

    // Check widget is still a valid GTK label
    if (!is_valid_label(win->state_label)) return;

    // Safe to access widget
    gtk_label_set_text(GTK_LABEL(win->state_label), buf);
}
```

### 5. Creation-Time Validation

Validate all widgets are properly created before marking window as initialized:

```c
// Validate all critical widgets were created
if (!is_valid_label(win->state_label) || !is_valid_label(win->model_label) ||
    // ... check all widgets ...
    !is_valid_label(win->avg_duration_label)) {

    fprintf(stderr, "[GTK] Fatal: Widget creation validation failed\n");
    gtk_window_destroy(GTK_WINDOW(win->window));
    g_free(win);
    return NULL;
}

win->initialized = 1;
win->widgets_valid = 1;
```

## Safety Guarantees

### 1. No Dangling Pointer Access
- All widget accesses are guarded by `widgets_valid` flag
- Window destruction automatically invalidates all widgets
- Attempting to access widgets after destruction silently fails (no crash)

### 2. Type Safety
- GTK's type system is used to validate pointers before casting
- `GTK_IS_WIDGET()`, `GTK_IS_LABEL()`, etc. macros check GObject type
- Invalid or freed pointers fail type checks and are rejected

### 3. Graceful Degradation
- If GTK backend is unavailable, window creation returns NULL
- If any widget creation fails, entire window is cleaned up
- If window is destroyed, updates are silently ignored (daemon continues)

### 4. Thread Safety Notes
- All GTK calls must happen on the main thread (GTK is not thread-safe)
- The daemon's main loop calls GTK functions, NOT the WebSocket thread
- `daemon_status_gtk_process_events()` processes events without blocking

## Testing

### Manual Testing
1. Start daemon with GTK window enabled
2. Trigger recordings to update status
3. Close window with X button
4. Continue triggering recordings
5. Verify: No crashes, no GTK errors in console

### Expected Behavior
- **Before Fix**: GTK assertion failures flood console, potential crashes
- **After Fix**: Clean shutdown message, daemon continues without errors

### Error Detection
```bash
# Run daemon and watch for GTK errors
./zig-out/bin/talkies daemon 2>&1 | grep -i "gtk\|critical\|warning"
```

Should only see:
- Initial GTK initialization messages
- `[GTK] Window destroyed` when closing window
- NO "invalid unclassed pointer" or assertion failures

## Performance Impact

- **Minimal**: Each widget access adds 2-3 pointer checks (nanoseconds)
- **Memory**: Added 4 bytes per window instance (`widgets_valid` flag)
- **Startup**: No change - validation happens during creation only

## Future Improvements

1. **Log Interception**: Capture stdout/stderr and route to GUI log viewer
2. **Error Statistics**: Track and display widget validation failure counts
3. **Automatic Recovery**: Recreate window if destroyed accidentally
4. **Thread-Safe Updates**: Use GLib's idle callbacks for cross-thread updates

## Related Issues

- **talkies-0f2**: Fix GTK widget dangling pointer crashes (P0) ✓ FIXED
- **talkies-v1u**: Add log interception to route stdout/stderr to status GUI (P1)
- **talkies-i2u**: Implement daemon status GUI with live logs and error indicators (P1)

## References

- [GTK4 Documentation](https://docs.gtk.org/gtk4/)
- [GObject Type System](https://docs.gtk.org/gobject/)
- [GTK Widget Lifecycle](https://docs.gtk.org/gtk4/class.Widget.html#lifecycle)
