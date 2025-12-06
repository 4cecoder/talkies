#!/bin/bash
# Run script for Whisper CLI

# Install dependencies with uv
uv sync

# Run the CLI
uv run whisper-cli "$@"