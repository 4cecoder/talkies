# AGENTS.md - Coding Guidelines for Talkies

## Build, Lint & Test Commands

### Frontend (Next.js/TypeScript)
- **Development**: `cd frontend && npm run dev`
- **Build**: `cd frontend && npm run build`
- **Lint**: `cd frontend && npm run lint`
- **Single test**: `cd frontend && npm test -- [test-file]`

### macOS (Swift/SwiftUI)
- **Debug build**: `cd mac && swift build`
- **Release build**: `cd mac && swift build -c release`
- **Test**: `cd mac && swift test`
- **Single test**: `cd mac && swift test --filter [TestClass].[testMethod]`

### Windows (.NET WPF)
- **Build**: `cd windows/Talkies.Windows && uv run dotnet build`
- **Test**: `cd windows/Talkies.Windows && uv run dotnet test`
- **Single test**: `cd windows/Talkies.Windows && uv run dotnet test --filter [FullyQualifiedName]`

### Python (CLI tools)
- **Test**: `cd archive && uv run pytest`
- **Single test**: `cd archive && uv run pytest tests/test_[name].py`
- **With coverage**: `cd archive && uv run pytest --cov=src`

### Mobile (Flutter/Dart)
- **Test**: `cd mobile && flutter test`
- **Single test**: `cd mobile && flutter test test/[test_file].dart`

## Code Style Guidelines

### TypeScript/React (Frontend)
- Use `forwardRef` for components that need ref forwarding
- Type all props with interfaces, use union types for variants
- Use `cn()` utility from `@/app/lib/utils` for conditional classes
- Include accessibility attributes (`aria-*`, `role`)
- Use `React.forwardRef` with `displayName` for debugging
- Prefer functional components with hooks
- Use `const` assertions for literal objects
- Follow Next.js App Router conventions

### Swift (macOS)
- Use `@MainActor` for UI-related code
- Prefer `Combine` for reactive programming
- Use `OSAllocatedUnfairLock` for thread-safe properties
- Follow Swift 6 concurrency model with `nonisolated`
- Use `#if os(macOS)` for platform-specific code
- Prefer `struct` over `class` when possible
- Use `Task { @MainActor in ... }` for main thread updates
- Handle errors with `do/catch` blocks
- Use `guard` statements for early returns

### C# (.NET Windows)
- Use interfaces for service contracts (`IAudioRecorder`, etc.)
- Include XML documentation comments (`/// <summary>`)
- Use `using` statements for resource management
- Follow MVVM pattern with ViewModels
- Use nullable reference types (`?`)
- Prefer `init` properties for immutable data
- Use `event EventHandler<T>` for events
- Handle exceptions gracefully in UI callbacks
- Use `StringComparison.OrdinalIgnoreCase` for case-insensitive string operations

### Python (CLI)
- Use type hints for all function parameters and return values
- Include docstrings for all public functions and classes
- Use `pathlib.Path` instead of string paths
- Use `click` for CLI argument parsing
- Follow logging best practices with appropriate levels
- Use `contextlib` for resource management
- Prefer f-strings for string formatting
- Use `dataclasses` or `pydantic` for structured data
- Handle exceptions with specific exception types

### Flutter/Dart (Mobile)
- Use `const` constructors when possible
- Follow BLoC or Provider pattern for state management
- Use `async/await` for asynchronous operations
- Include proper error handling with try/catch
- Use `Key` classes for widget identification in tests
- Follow material design guidelines
- Use `const` for immutable values

## General Principles
- **Use uv for everything** - Wrap dotnet/npm commands with `uv run` where applicable
- Follow existing patterns in each platform directory
- Include proper error handling and logging
- Write tests for new functionality
- Use platform-appropriate dependency injection
- Follow security best practices (no secrets in code)
- Use descriptive variable and function names
- Add comments for complex logic only when necessary</content>
<parameter name="filePath">/home/fource/talkies/AGENTS.md