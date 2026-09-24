import Foundation
import AVFoundation

/// Represents an audio input device
public struct AudioDeviceInfo: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let isDefault: Bool

    public static func == (lhs: AudioDeviceInfo, rhs: AudioDeviceInfo) -> Bool {
        lhs.id == rhs.id
    }
}

/// Service for managing audio input devices
@MainActor
public class AudioDeviceService: ObservableObject {
    @Published public var availableDevices: [AudioDeviceInfo] = []
    @Published public var selectedDeviceID: String? {
        didSet {
            if let deviceID = selectedDeviceID {
                UserDefaults.standard.set(deviceID, forKey: "selectedAudioDeviceID")
            }
        }
    }

    public init() {
        loadSavedDevice()
        refreshDevices()
    }

    /// Enumerate all available audio input devices
    public func refreshDevices() {
        var devices: [AudioDeviceInfo] = []

        #if os(macOS)
        // Get discovery session for audio devices
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        )

        // Get default device ID
        let defaultDevice = AVCaptureDevice.default(for: .audio)
        let defaultID = defaultDevice?.uniqueID

        // Enumerate all audio devices
        for device in discoverySession.devices {
            let deviceInfo = AudioDeviceInfo(
                id: device.uniqueID,
                name: device.localizedName,
                isDefault: device.uniqueID == defaultID
            )
            devices.append(deviceInfo)
        }
        #endif

        availableDevices = devices

        // If no device is selected or selected device is no longer available, select default
        if selectedDeviceID == nil || !devices.contains(where: { $0.id == selectedDeviceID }) {
            selectedDeviceID = devices.first(where: { $0.isDefault })?.id ?? devices.first?.id
        }
    }

    /// Get the currently selected device
    public func getSelectedDevice() -> AudioDeviceInfo? {
        guard let deviceID = selectedDeviceID else { return nil }
        return availableDevices.first(where: { $0.id == deviceID })
    }

    /// Get the default audio input device
    public func getDefaultDevice() -> AudioDeviceInfo? {
        return availableDevices.first(where: { $0.isDefault })
    }

    /// Get AVCaptureDevice for the selected device ID
    public func getAVCaptureDevice(for deviceID: String?) -> AVCaptureDevice? {
        guard let deviceID = deviceID else { return nil }

        #if os(macOS)
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        )

        return discoverySession.devices.first(where: { $0.uniqueID == deviceID })
        #else
        return nil
        #endif
    }

    /// Load previously saved device from UserDefaults
    private func loadSavedDevice() {
        selectedDeviceID = UserDefaults.standard.string(forKey: "selectedAudioDeviceID")
    }
}
