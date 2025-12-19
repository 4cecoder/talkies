#!/bin/bash
# Script to run .NET Windows tests on macOS using Docker
# This enables local testing without needing a Windows environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Parse command line arguments
COMMAND="${1:-test}"
BUILD_CACHE="${BUILD_CACHE:-true}"

print_usage() {
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  test      Run tests (default)"
    echo "  build     Build the project"
    echo "  restore   Restore dependencies"
    echo "  shell     Open interactive shell in container"
    echo "  clean     Remove Docker images and containers"
    echo "  help      Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  BUILD_CACHE   Use Docker build cache (default: true)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Run tests"
    echo "  $0 build              # Build project"
    echo "  $0 shell              # Open shell"
    echo "  BUILD_CACHE=false $0  # Rebuild without cache"
}

# Check if Docker is installed and running
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Error: Docker is not installed${NC}"
        echo "Please install Docker Desktop from https://www.docker.com/products/docker-desktop"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        echo -e "${RED}Error: Docker daemon is not running${NC}"
        echo "Please start Docker Desktop"
        exit 1
    fi
}

# Run tests
run_tests() {
    echo -e "${BLUE}Running .NET tests in Docker...${NC}"

    BUILD_FLAGS=""
    if [ "$BUILD_CACHE" = "false" ]; then
        BUILD_FLAGS="--no-cache"
    fi

    # Create TestResults directory if it doesn't exist
    mkdir -p TestResults

    # Build and run tests
    docker-compose build $BUILD_FLAGS test
    docker-compose run --rm test

    echo ""
    echo -e "${GREEN}Tests completed!${NC}"

    # Show test results if they exist
    if [ -d "TestResults" ] && [ "$(ls -A TestResults)" ]; then
        echo -e "${BLUE}Test results saved to: ${SCRIPT_DIR}/TestResults${NC}"
    fi
}

# Build project
build_project() {
    echo -e "${BLUE}Building .NET project in Docker...${NC}"

    BUILD_FLAGS=""
    if [ "$BUILD_CACHE" = "false" ]; then
        BUILD_FLAGS="--no-cache"
    fi

    docker-compose build $BUILD_FLAGS build
    docker-compose run --rm build

    echo -e "${GREEN}Build completed!${NC}"
}

# Restore dependencies
restore_deps() {
    echo -e "${BLUE}Restoring .NET dependencies in Docker...${NC}"

    BUILD_FLAGS=""
    if [ "$BUILD_CACHE" = "false" ]; then
        BUILD_FLAGS="--no-cache"
    fi

    docker-compose build $BUILD_FLAGS restore
    docker-compose run --rm restore

    echo -e "${GREEN}Dependencies restored!${NC}"
}

# Open interactive shell
open_shell() {
    echo -e "${BLUE}Opening interactive shell in Docker container...${NC}"
    echo -e "${YELLOW}Tip: You can run 'dotnet test' or 'dotnet build' manually${NC}"

    docker-compose build shell
    docker-compose run --rm shell
}

# Clean up Docker resources
clean_docker() {
    echo -e "${YELLOW}Cleaning up Docker resources...${NC}"

    docker-compose down --rmi all --volumes --remove-orphans

    echo -e "${GREEN}Cleanup completed!${NC}"
}

# Main script logic
check_docker

case "$COMMAND" in
    test)
        run_tests
        ;;
    build)
        build_project
        ;;
    restore)
        restore_deps
        ;;
    shell)
        open_shell
        ;;
    clean)
        clean_docker
        ;;
    help|--help|-h)
        print_usage
        ;;
    *)
        echo -e "${RED}Error: Unknown command '$COMMAND'${NC}"
        echo ""
        print_usage
        exit 1
        ;;
esac
