#!/bin/bash
# Vercel CLI wrapper - run Vercel commands from the frontend directory
# This wraps vercel CLI calls to execute from the monorepo root

cd "$(dirname "$0")/../.." || exit 1
bunx vercel "$@"
