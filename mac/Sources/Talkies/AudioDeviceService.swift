import Foundation
import AVFoundation

/// Represents an audio input device
struct AudioDeviceInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let isDefault: Bool

    static func == (lhs: AudioDeviceInfo, rhs: AudioDeviceInfo) -> Bool {
        lhs.id == rhs.id
    }
}

/// Service for managing audio input devices
@MainActor
class AudioDeviceService: ObservableObject {
    @Published var availableDevices: [AudioDeviceInfo] = []
    @Published var selectedDeviceID: String? {
        didSet {
            if let deviceID = selectedDeviceID {
                UserDefaults.standard.set(deviceID, forKey: "selectedAudioDeviceID")
            }
        }
    }

    init() {
        loadSavedDevice()
        refreshDevices()
    }

    /// Enumerate all available audio input devices
    func refreshDevices() {
        var devices: [AudioDeviceInfo] = []

        #if os(macOS)
        // Get discovery session for audio devices
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .builtInMicrophone],
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
    func getSelectedDevice() -> AudioDeviceInfo? {
        guard let deviceID = selectedDeviceID else { return nil }
        return availableDevices.first(where: { $0.id == deviceID })
    }

    /// Get the default audio input device
    func getDefaultDevice() -> AudioDeviceInfo? {
        return availableDevices.first(where: { $0.isDefault })
    }

    /// Get AVCaptureDevice for the selected device ID
    func getAVCaptureDevice(for deviceID: String?) -> AVCaptureDevice? {
        guard let deviceID = deviceID else { return nil }

        #if os(macOS)
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .builtInMicrophone],
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
