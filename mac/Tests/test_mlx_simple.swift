#!/usr/bin/env swift

// Simple test to check if MLX can initialize
// This isolates the Metal library loading issue

import Foundation

print("🧪 Simple MLX Metal Library Test")
print("=================================\n")

// Try to load MLX
print("Attempting to import and use MLX...")

do {
    // This will trigger MLX to load its Metal library
    print("Creating default stream...")

    // We can't actually run this without the MLX module being available,
    // but we can test if the library files exist

    let possiblePaths = [
        ".build/arm64-apple-macosx/debug",
        ".build/debug",
        "/usr/local/lib",
        "./lib"
    ]

    print("\nSearching for MLX libraries:")
    for path in possiblePaths {
        if FileManager.default.fileExists(atPath: path) {
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: path)
                let mlxLibs = contents.filter { $0.contains("mlx") || $0.contains("MLX") }
                if !mlxLibs.isEmpty {
                    print("✓ Found in \(path):")
                    for lib in mlxLibs {
                        print("  - \(lib)")
                    }
                }
            } catch {
                print("✗ Error reading \(path): \(error)")
            }
        }
    }

    // Check for metallib files
    print("\nSearching for .metallib files:")
    let findProcess = Process()
    findProcess.executableURL = URL(fileURLWithPath: "/usr/bin/find")
    findProcess.arguments = [".build", "-name", "*.metallib", "-o", "-name", "default.metallib"]

    let pipe = Pipe()
    findProcess.standardOutput = pipe

    try findProcess.run()
    findProcess.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: data, encoding: .utf8), !output.isEmpty {
        print(output)
    } else {
        print("❌ No .metallib files found - this is the problem!")
        print("\nThe Metal shader library (default.metallib) is missing.")
        print("This is required for MLX to work and can only be built with Xcode.")
    }

} catch {
    print("❌ Error: \(error)")
}

print("\n=================================")
