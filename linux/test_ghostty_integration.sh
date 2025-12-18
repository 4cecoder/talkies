#!/bin/bash
# Test script for Ghostty integration modules

set -e  # Exit on error

echo "Testing Ghostty Integration Modules"
echo "===================================="
echo

# Test 1: Runtime module
echo "Test 1: Runtime abstraction..."
zig test src/runtime.zig
echo "  ✓ Runtime tests passed"
echo

# Test 2: Platform detection
echo "Test 2: Platform protocol detection..."
zig test src/ui/platform.zig
echo "  ✓ Platform tests passed"
echo

# Test 3: Build system integration
echo "Test 3: Build system with GTK detection..."
zig build --summary all
echo "  ✓ Build tests passed"
echo

# Test 4: Main project tests
echo "Test 4: Main project tests..."
zig build test
echo "  ✓ Main tests passed"
echo

echo "===================================="
echo "All tests passed!"
echo
echo "GTK version module (src/ui/gtk_version.zig) can only be tested"
echo "as part of the full build due to complex GTK C dependencies."
echo "It is tested when you run 'zig build test'."
