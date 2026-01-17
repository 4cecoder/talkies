#!/usr/bin/env bash
#
# GTK Robustness Test Script
# Tests the daemon status window for crashes and assertion failures
#

set -euo pipefail

echo "🧪 GTK Robustness Test Suite"
echo "=============================="
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper: Print test result
test_result() {
    local name="$1"
    local status="$2"
    local details="${3:-}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✓${NC} $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $name"
        if [ -n "$details" ]; then
            echo "  → $details"
        fi
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test 1: Build with no warnings
echo "Test 1: Clean Build"
echo "-------------------"
if zig build 2>&1 | grep -qi "error"; then
    test_result "Clean build" "FAIL" "Build errors detected"
else
    test_result "Clean build" "PASS"
fi
echo

# Test 2: Binary exists and is executable
echo "Test 2: Binary Check"
echo "-------------------"
if [ -x "zig-out/bin/talkies" ]; then
    test_result "Binary exists and is executable" "PASS"
else
    test_result "Binary exists and is executable" "FAIL" "Binary not found or not executable"
fi
echo

# Test 3: Help command works (basic sanity)
echo "Test 3: Basic Sanity"
echo "-------------------"
if ./zig-out/bin/talkies help >/dev/null 2>&1; then
    test_result "Help command executes" "PASS"
else
    test_result "Help command executes" "FAIL"
fi
echo

# Test 4: Config validation
echo "Test 4: Config Validation"
echo "-------------------------"
if ./zig-out/bin/talkies config >/dev/null 2>&1; then
    test_result "Config loads successfully" "PASS"
else
    test_result "Config loads successfully" "FAIL"
fi
echo

# Test 5: GTK Initialization (headless check)
echo "Test 5: GTK Backend Detection"
echo "-----------------------------"
output=$(timeout 2s ./zig-out/bin/talkies daemon 2>&1 || true)
if echo "$output" | grep -q "\[GTK\] Initializing GTK4"; then
    test_result "GTK initialization starts" "PASS"
else
    test_result "GTK initialization starts" "FAIL" "GTK init message not found"
fi
echo

# Test 6: No GTK Assertion Failures (most important!)
echo "Test 6: GTK Assertion Check"
echo "---------------------------"
if echo "$output" | grep -qi "invalid unclassed pointer\|assertion.*failed"; then
    test_result "No GTK assertion failures" "FAIL" "GTK errors detected in output"
    echo
    echo "  Errors found:"
    echo "$output" | grep -i "invalid unclassed pointer\|assertion.*failed" | head -5 | sed 's/^/    /'
else
    test_result "No GTK assertion failures" "PASS"
fi
echo

# Test 7: Window Creation Validation
echo "Test 7: Window Creation"
echo "----------------------"
if echo "$output" | grep -q "Window created successfully"; then
    test_result "Status window created" "PASS"
else
    # Might be headless - check for appropriate fallback message
    if echo "$output" | grep -q "continuing without GUI\|headless mode"; then
        test_result "Status window created" "PASS" "Running in headless mode (expected in CI/headless)"
    else
        test_result "Status window created" "FAIL" "Window creation unclear"
    fi
fi
echo

# Summary
echo "=============================="
echo "📊 Test Summary"
echo "=============================="
echo "Total Tests: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi
