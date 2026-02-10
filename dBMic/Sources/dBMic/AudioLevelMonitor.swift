import AVFoundation
import Accelerate
import Combine
import CoreAudio
import dBMicCore

/// Monitors the system audio input device and publishes real-time dB levels.
final class AudioLevelMonitor: ObservableObject {

    // MARK: - Published State

    @Published var decibelLevel: Float = -160.0
    @Published var peakLevel: Float = -160.0
    @Published var inputDeviceName: String = "Unknown"
    @Published var isMonitoring: Bool = false
    @Published var permissionGranted: Bool = false
    @Published var lastError: String?

    /// True when audio level is above the silence floor (voice activity detected).
    @Published var isSpeaking: Bool = false

    /// Rolling history of dB levels for the last 60 seconds, sampled ~2x/sec.
    @Published var levelHistory: [Float] = []

    /// Sound check — only phase and verdict are @Published to avoid per-sample copy overhead.
    @Published var soundCheckPhase: SoundCheckState.Phase = .idle
    @Published var soundCheckVerdict: SoundCheckState.Verdict?
    @Published var soundCheckStartTime: Date?

    // MARK: - Private

    private var audioEngine = AVAudioEngine()
    private var deviceListenerInstalled = false
    private var deviceListListenerInstalled = false
    private var configChangeObserver: NSObjectProtocol?
    private var defaultDeviceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private var deviceListAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    /// Exponential moving average coefficient (0..1). Higher = more responsive, lower = smoother.
    var smoothingFactor: Float = 0.3

    /// dB level above which we consider the user to be speaking (not silence).
    var silenceFloor: Float = -55.0

    /// Peak hold decay rate in dB per update cycle.
    private let peakDecayRate: Float = 0.5
    private var currentSmoothedLevel: Float = -160.0

    /// History sampling: accumulates dB values between history ticks.
    private var historySamples: [Float] = []
    private var historyTimer: Timer?
    private let historyMaxSamples = 120  // 60 seconds at 2 samples/sec

    /// Sound check sample accumulation (non-published to avoid copy+objectWillChange spam).
    private var soundCheckState = SoundCheckState()
    private var soundCheckTimer: DispatchWorkItem?

    /// Throttle: only dispatch to main thread at this interval (~12 Hz).
    private var lastMainDispatchTime: CFAbsoluteTime = 0
    private let mainDispatchInterval: CFAbsoluteTime = 0.08

    /// Device change debounce.
    private var deviceChangeWorkItem: DispatchWorkItem?

    // MARK: - Lifecycle

    init() {
        updateInputDeviceName()
    }

    deinit {
        // Synchronous cleanup only — no async dispatches that capture self
        if isMonitoring {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
            historyTimer?.invalidate()
        }
        soundCheckTimer?.cancel()
        deviceChangeWorkItem?.cancel()
        removeDeviceChangeListener()
    }

    // MARK: - Permission

    func requestPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            DispatchQueue.main.async { [weak self] in
                self?.permissionGranted = true
                completion(true)
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async { [weak self] in
                    self?.permissionGranted = granted
                    completion(granted)
                }
            }
        default:
            DispatchQueue.main.async { [weak self] in
                self?.permissionGranted = false
                completion(false)
            }
        }
    }

    // MARK: - Monitoring

    func startMonitoring() {
        guard !isMonitoring else { return }

        audioEngine = AVAudioEngine()

        // Guard against no input device — accessing inputNode throws an ObjC exception
        // (not catchable in Swift) on Macs with no built-in mic and no connected device.
        guard hasAudioInputDevice() else {
            lastError = "No audio input device found"
            inputDeviceName = "No Input"
            return
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        guard format.sampleRate > 0, format.channelCount > 0 else {
            lastError = "Invalid audio format"
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }

        do {
            try audioEngine.start()
            // Set state synchronously — avoids race where restartMonitoring()
            // calls stop before the async block sets isMonitoring = true
            isMonitoring = true
            lastError = nil
            startHistoryTimer()
            installDeviceChangeListener()
            updateInputDeviceName()
        } catch {
            // Clean up the tap we just installed
            inputNode.removeTap(onBus: 0)
            lastError = "Failed to start audio: \(error.localizedDescription)"
        }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        historyTimer?.invalidate()
        historyTimer = nil
        // Set state synchronously to match startMonitoring
        isMonitoring = false
        isSpeaking = false
        decibelLevel = -160.0
        peakLevel = -160.0
        currentSmoothedLevel = -160.0
    }

    func resetPeak() {
        peakLevel = -160.0
    }

    func restartMonitoring() {
        stopMonitoring()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
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

        // Feed sound check samples directly (no @Published overhead)
        if soundCheckState.phase == .recording {
            soundCheckState.addSample(clampedDB, silenceFloor: silenceFloor)
        }

        // Throttle main-thread dispatches to ~12 Hz
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastMainDispatchTime >= mainDispatchInterval else { return }
        lastMainDispatchTime = now

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

            // Voice activity detection
            self.isSpeaking = self.currentSmoothedLevel > self.silenceFloor

            // Accumulate samples for history
            self.historySamples.append(self.currentSmoothedLevel)
        }
    }

    // MARK: - History

    private func startHistoryTimer() {
        historyTimer?.invalidate()
        historyTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tickHistory()
        }
        historyTimer?.tolerance = 0.05
    }

    private func tickHistory() {
        guard !historySamples.isEmpty else {
            levelHistory.append(currentSmoothedLevel)
            trimHistory()
            return
        }
        // Average the accumulated samples for this tick
        let avg = historySamples.reduce(0, +) / Float(historySamples.count)
        historySamples.removeAll()
        levelHistory.append(avg)
        trimHistory()
    }

    private func trimHistory() {
        if levelHistory.count > historyMaxSamples {
            levelHistory.removeFirst(levelHistory.count - historyMaxSamples)
        }
    }

    // MARK: - Sound Check

    func startSoundCheck() {
        soundCheckTimer?.cancel()

        soundCheckState = SoundCheckState()
        soundCheckState.start()

        // Publish lightweight state only
        soundCheckPhase = .recording
        soundCheckVerdict = nil
        soundCheckStartTime = soundCheckState.startTime

        let workItem = DispatchWorkItem { [weak self] in
            self?.finishSoundCheck()
        }
        soundCheckTimer = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + soundCheckState.duration, execute: workItem)
    }

    private func finishSoundCheck() {
        guard soundCheckState.phase == .recording else { return }
        soundCheckState.finish()
        soundCheckPhase = .done
        soundCheckVerdict = soundCheckState.verdict
    }

    func resetSoundCheck() {
        soundCheckTimer?.cancel()
        soundCheckState = SoundCheckState()
        soundCheckPhase = .idle
        soundCheckVerdict = nil
        soundCheckStartTime = nil
    }

    // MARK: - Device Management

    /// Check if any audio input device is available before accessing inputNode.
    private func hasAudioInputDevice() -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &deviceID
        )
        return status == noErr && deviceID != 0
    }

    func updateInputDeviceName() {
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
            DispatchQueue.main.async { [weak self] in
                self?.inputDeviceName = "No Input"
            }
            return
        }

        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let namePtr = UnsafeMutablePointer<CFString?>.allocate(capacity: 1)
        namePtr.initialize(to: nil)
        defer { namePtr.deinitialize(count: 1); namePtr.deallocate() }
        var nameSize = UInt32(MemoryLayout<CFString?>.size)

        let nameStatus = AudioObjectGetPropertyData(
            deviceID,
            &nameAddress,
            0, nil,
            &nameSize,
            namePtr
        )

        let rawName = nameStatus == noErr
            ? namePtr.pointee as String? ?? "Unknown Device"
            : "Unknown Device"
        let displayName = "System (\(rawName))"
        DispatchQueue.main.async { [weak self] in
            self?.inputDeviceName = displayName
        }
    }

    private func installDeviceChangeListener() {
        let ptr = Unmanaged.passUnretained(self).toOpaque()

        // Listen for default input device changes
        if !deviceListenerInstalled {
            let status = AudioObjectAddPropertyListener(
                AudioObjectID(kAudioObjectSystemObject),
                &defaultDeviceAddress,
                deviceChangeCallback,
                ptr
            )
            if status == noErr { deviceListenerInstalled = true }
        }

        // Listen for device connect/disconnect
        if !deviceListListenerInstalled {
            let status = AudioObjectAddPropertyListener(
                AudioObjectID(kAudioObjectSystemObject),
                &deviceListAddress,
                deviceChangeCallback,
                ptr
            )
            if status == noErr { deviceListListenerInstalled = true }
        }

        // Listen for audio engine configuration changes (route/format changes)
        if configChangeObserver == nil {
            configChangeObserver = NotificationCenter.default.addObserver(
                forName: .AVAudioEngineConfigurationChange,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                self?.handleDeviceChange()
            }
        }
    }

    private func removeDeviceChangeListener() {
        let ptr = Unmanaged.passUnretained(self).toOpaque()

        if deviceListenerInstalled {
            AudioObjectRemovePropertyListener(
                AudioObjectID(kAudioObjectSystemObject),
                &defaultDeviceAddress,
                deviceChangeCallback,
                ptr
            )
            deviceListenerInstalled = false
        }

        if deviceListListenerInstalled {
            AudioObjectRemovePropertyListener(
                AudioObjectID(kAudioObjectSystemObject),
                &deviceListAddress,
                deviceChangeCallback,
                ptr
            )
            deviceListListenerInstalled = false
        }

        if let observer = configChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            configChangeObserver = nil
        }
    }

    /// Called from device change callback. Debounces rapid notifications from CoreAudio.
    fileprivate func handleDeviceChange() {
        deviceChangeWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.updateInputDeviceName()
            // Reset sound check if in progress — mixed-device samples are useless
            if self.soundCheckState.phase == .recording {
                self.resetSoundCheck()
            }
            self.restartMonitoring()
        }
        deviceChangeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
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
    monitor.handleDeviceChange()
    return noErr
}
