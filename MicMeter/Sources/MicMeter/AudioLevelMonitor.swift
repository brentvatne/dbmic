import AVFoundation
import Accelerate
import Combine
import CoreAudio

/// Monitors the system audio input device and publishes real-time dB levels.
final class AudioLevelMonitor: ObservableObject {

    // MARK: - Published State

    @Published var decibelLevel: Float = -160.0
    @Published var peakLevel: Float = -160.0
    @Published var inputDeviceName: String = "Unknown"
    @Published var isMonitoring: Bool = false
    @Published var permissionGranted: Bool = false

    // MARK: - Private

    private var audioEngine = AVAudioEngine()
    private var deviceListenerInstalled = false
    private var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    /// Exponential moving average coefficient (0..1). Higher = more responsive, lower = smoother.
    var smoothingFactor: Float = 0.3

    /// Peak hold decay rate in dB per update cycle.
    private let peakDecayRate: Float = 0.5
    private var currentSmoothedLevel: Float = -160.0

    // MARK: - Lifecycle

    init() {
        updateInputDeviceName()
    }

    deinit {
        stopMonitoring()
        removeDeviceChangeListener()
    }

    // MARK: - Permission

    func requestPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            DispatchQueue.main.async {
                self.permissionGranted = true
                completion(true)
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    self.permissionGranted = granted
                    completion(granted)
                }
            }
        default:
            DispatchQueue.main.async {
                self.permissionGranted = false
                completion(false)
            }
        }
    }

    // MARK: - Monitoring

    func startMonitoring() {
        guard !isMonitoring else { return }

        audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        guard format.sampleRate > 0, format.channelCount > 0 else {
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }

        do {
            try audioEngine.start()
            DispatchQueue.main.async {
                self.isMonitoring = true
            }
            installDeviceChangeListener()
            updateInputDeviceName()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        DispatchQueue.main.async {
            self.isMonitoring = false
            self.decibelLevel = -160.0
            self.peakLevel = -160.0
            self.currentSmoothedLevel = -160.0
        }
    }

    func restartMonitoring() {
        stopMonitoring()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.startMonitoring()
        }
    }

    // MARK: - Audio Processing

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = UInt(buffer.frameLength)
        guard frameLength > 0 else { return }

        // Compute RMS using Accelerate framework
        var rms: Float = 0
        vDSP_rmsqv(channelData, 1, &rms, frameLength)

        // Convert to decibels (dBFS)
        let dB = 20.0 * log10(max(rms, Float.leastNormalMagnitude))

        // Clamp to reasonable range
        let clampedDB = max(min(dB, 0.0), -160.0)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Exponential moving average for smoothing
            if self.currentSmoothedLevel <= -160.0 {
                self.currentSmoothedLevel = clampedDB
            } else {
                self.currentSmoothedLevel = self.smoothingFactor * clampedDB
                    + (1.0 - self.smoothingFactor) * self.currentSmoothedLevel
            }
            self.decibelLevel = self.currentSmoothedLevel

            // Peak hold with decay
            if clampedDB > self.peakLevel {
                self.peakLevel = clampedDB
            } else {
                self.peakLevel = max(self.peakLevel - self.peakDecayRate, clampedDB)
            }
        }
    }

    // MARK: - Device Management

    private func updateInputDeviceName() {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil,
            &size,
            &deviceID
        )

        guard status == noErr else {
            DispatchQueue.main.async { self.inputDeviceName = "No Input" }
            return
        }

        // Get device name
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)

        let nameStatus = AudioObjectGetPropertyData(
            deviceID,
            &nameAddress,
            0, nil,
            &nameSize,
            &name
        )

        let deviceName = nameStatus == noErr ? name as String : "Unknown Device"
        DispatchQueue.main.async {
            self.inputDeviceName = deviceName
        }
    }

    private func installDeviceChangeListener() {
        guard !deviceListenerInstalled else { return }

        let status = AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            deviceChangeCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )

        if status == noErr {
            deviceListenerInstalled = true
        }
    }

    private func removeDeviceChangeListener() {
        guard deviceListenerInstalled else { return }

        AudioObjectRemovePropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            deviceChangeCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
        deviceListenerInstalled = false
    }
}

// Core Audio C-function callback for device changes
private func deviceChangeCallback(
    objectID: AudioObjectID,
    numberAddresses: UInt32,
    addresses: UnsafePointer<AudioObjectPropertyAddress>,
    clientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let clientData = clientData else { return noErr }
    let monitor = Unmanaged<AudioLevelMonitor>.fromOpaque(clientData).takeUnretainedValue()

    DispatchQueue.main.async {
        monitor.updateInputDeviceName()
        monitor.restartMonitoring()
    }

    return noErr
}
