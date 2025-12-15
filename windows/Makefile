# Makefile for Windows .NET Docker testing
# Provides simple 'make test' interface for Docker testing

.PHONY: help test build restore shell clean check-docker

# Default target
.DEFAULT_GOAL := help

help: ## Show this help message
	@echo "Windows .NET Docker Testing - Available Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make test       # Run all tests"
	@echo "  make build      # Build the project"
	@echo "  make shell      # Open interactive shell"

check-docker:
	@if ! command -v docker &> /dev/null; then \
		echo "Error: Docker is not installed"; \
		echo "Please install Docker Desktop from https://www.docker.com/products/docker-desktop"; \
		exit 1; \
	fi
	@if ! docker info &> /dev/null; then \
		echo "Error: Docker daemon is not running"; \
		echo "Please start Docker Desktop"; \
		exit 1; \
	fi

test: check-docker ## Run tests in Docker
	@./test-docker.sh test

build: check-docker ## Build the project in Docker
	@./test-docker.sh build

restore: check-docker ## Restore NuGet dependencies
	@./test-docker.sh restore

shell: check-docker ## Open interactive shell in Docker container
	@./test-docker.sh shell

clean: ## Clean up Docker resources
	@./test-docker.sh clean

rebuild: clean build test ## Clean, rebuild, and test

# Advanced targets
test-verbose: check-docker ## Run tests with verbose output
	@docker-compose run --rm test dotnet test --logger "console;verbosity=detailed" --verbosity detailed

test-watch: check-docker ## Run tests in watch mode (requires manual Ctrl+C to stop)
	@echo "Starting test watch mode (Ctrl+C to stop)..."
	@docker-compose run --rm shell dotnet watch test

coverage: check-docker ## Run tests with code coverage
	@docker-compose run --rm test dotnet test /p:CollectCoverage=true /p:CoverageReporter=cobertura

# Docker compose shortcuts
up: check-docker ## Start all services
	@docker-compose up

down: ## Stop all services
	@docker-compose down

logs: ## Show Docker compose logs
	@docker-compose logs -f

ps: ## Show running containers
	@docker-compose ps

# Maintenance
prune: ## Remove all unused Docker resources
	@echo "Warning: This will remove all unused Docker resources"
	@read -p "Continue? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker system prune -af; \
	fi

update-sdk: ## Update to latest .NET SDK image
	@echo "Pulling latest .NET SDK image..."
	@docker pull mcr.microsoft.com/dotnet/sdk:8.0
	@echo "Rebuilding test image..."
	@docker-compose build --no-cache test

# Info targets
version: check-docker ## Show .NET version in Docker
	@docker-compose run --rm shell dotnet --version

info: check-docker ## Show .NET SDK info
	@docker-compose run --rm shell dotnet --info

list-tests: check-docker ## List all available tests
	@docker-compose run --rm shell dotnet test --list-tests
