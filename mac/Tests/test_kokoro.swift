#!/usr/bin/env swift

import Foundation
import KokoroSwift
import MLX
import MLXUtilsLibrary

print("🧪 Testing Kokoro TTS Initialization")
print("=====================================\n")

// Test 1: Check if MLX Metal library can be loaded
print("Test 1: MLX Metal Library")
print("-" * 40)
do {
    print("Attempting to create MLX stream...")
    let stream = MLX.Stream.default
    print("✅ MLX stream created successfully")
} catch {
    print("❌ Failed to create MLX stream: \(error)")
}

// Test 2: Check model path
print("\nTest 2: Model Path")
print("-" * 40)
let modelPath = URL(fileURLWithPath: "Resources/Kokoro/model")
print("Model path: \(modelPath.path)")
print("Exists: \(FileManager.default.fileExists(atPath: modelPath.path))")

if FileManager.default.fileExists(atPath: modelPath.path) {
    do {
        let contents = try FileManager.default.contentsOfDirectory(atPath: modelPath.path)
        print("Contents: \(contents)")
    } catch {
        print("❌ Error reading directory: \(error)")
    }
}

// Test 3: Try to initialize KokoroTTS
print("\nTest 3: KokoroTTS Initialization")
print("-" * 40)
do {
    print("Attempting to initialize KokoroTTS...")
    let tts = KokoroTTS(modelPath: modelPath, g2p: .misaki)
    print("✅ KokoroTTS initialized successfully")

    // Test 4: Load voices
    print("\nTest 4: Voice Loading")
    print("-" * 40)
    let voicesDir = modelPath.appendingPathComponent("voices")
    print("Voices directory: \(voicesDir.path)")

    if FileManager.default.fileExists(atPath: voicesDir.path) {
        let voiceFiles = try FileManager.default.contentsOfDirectory(at: voicesDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "npz" }

        print("Found \(voiceFiles.count) voice files:")
        for voiceFile in voiceFiles {
            print("  - \(voiceFile.lastPathComponent)")
        }

        if let firstVoice = voiceFiles.first {
            print("\nAttempting to load first voice: \(firstVoice.lastPathComponent)")
            if let voiceData = NpyzReader.read(fileFromPath: firstVoice, isPacked: true),
               let voiceArray = voiceData["voice"] {
                print("✅ Voice loaded successfully")
                print("   Shape: \(voiceArray.shape)")
            } else {
                print("❌ Failed to load voice data")
            }
        }
    } else {
        print("❌ Voices directory does not exist")
    }

} catch {
    print("❌ Failed to initialize KokoroTTS: \(error)")
    print("Error details: \(error.localizedDescription)")
}

print("\n=====================================")
print("🧪 Test Complete")
