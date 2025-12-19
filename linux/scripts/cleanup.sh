#!/bin/bash
# Cleanup script for stuck Talkies processes

echo "Cleaning up stuck Talkies processes..."

# Kill any stuck arecord processes
if pgrep -f "arecord.*talkies-recording" > /dev/null; then
    echo "Killing stuck arecord processes..."
    pkill -f "arecord.*talkies-recording"
    sleep 1
fi

# Kill any talkies daemon processes
if pgrep -f "zig-out/bin/talkies" > /dev/null; then
    echo "Killing stuck talkies daemon..."
    pkill -f "zig-out/bin/talkies"
    sleep 1
fi

# Check if port 6789 is still in use
if lsof -i :6789 > /dev/null 2>&1 || ss -tulpn 2>/dev/null | grep -q 6789; then
    echo "Port 6789 still in use, attempting to free it..."
    fuser -k 6789/tcp 2>/dev/null
    sleep 1
fi

echo "Cleanup complete!"
echo ""
echo "Port status:"
ss -tulpn 2>/dev/null | grep 6789 || echo "  Port 6789 is free"
echo ""
echo "Running talkies processes:"
ps aux | grep -E "talkies|arecord.*talkies" | grep -v grep | grep -v cleanup.sh || echo "  None"
