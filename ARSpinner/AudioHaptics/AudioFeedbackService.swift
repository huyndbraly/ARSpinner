import Foundation
import AVFoundation

/// Protocol defining audio feedback for spinner bearing acoustics and contact transients.
@MainActor
protocol AudioFeedbackProviding: AnyObject {
    var isMuted: Bool { get set }
    var volume: Float { get set }
    func updateBearingSound(angularVelocity: Float)
    func playContactSound()
    func pause()
    func resume()
    func stop()
}

/// High-performance procedural mechanical audio engine synthesizing fidget spinner bearing acoustics.
/// Operates via AVAudioEngine with real-time pitch and volume modulation mapped to rotational RPM.
@MainActor
final class AudioFeedbackService: AudioFeedbackProviding {
    
    // MARK: - Properties
    
    var isMuted: Bool = true {
        didSet {
            if isMuted {
                silenceEngine()
            }
        }
    }
    
    var volume: Float = 0.8 {
        didSet {
            volume = max(0.0, min(1.0, volume))
            applySmoothedParameters()
        }
    }
    
    // MARK: - Audio Engine Components
    
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let timePitchUnit = AVAudioUnitTimePitch()
    
    private var bearingLoopBuffer: AVAudioPCMBuffer?
    
    private var isEngineRunning: Bool = false
    private var isLoopPlaying: Bool = false
    
    // MARK: - Smoothed Telemetry State
    
    private var currentRPM: Float = 0.0
    private var targetRPM: Float = 0.0
    private var currentGain: Float = 0.0
    private var currentPitchCents: Float = 0.0
    private var currentPlaybackRate: Float = 1.0
    
    private var smoothingTimer: Timer?
    
    // MARK: - Initialization
    
    init() {
        setupAudioSession()
        generateProceduralBuffers()
        setupAudioGraph()
    }
    
    deinit {
        smoothingTimer?.invalidate()
    }
    
    // MARK: - Audio Setup
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            AppLogger.general.warning("AVAudioSession setup error: \(error.localizedDescription)")
        }
    }
    
    /// Synthesizes seamless procedural audio buffers directly into memory without external audio assets.
    private func generateProceduralBuffers() {
        let sampleRate: Double = 44100.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            return
        }
        
        // 1. Generate 2.0-second seamless bearing whir loop
        let loopDuration: Double = 2.0
        let frameCount = AVAudioFrameCount(sampleRate * loopDuration)
        guard let loopBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        loopBuffer.frameLength = frameCount
        
        guard let left = loopBuffer.floatChannelData?[0],
              let right = loopBuffer.floatChannelData?[1] else { return }
        
        var filterStateL: Float = 0.0
        var filterStateR: Float = 0.0
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            
            // Filtered pink-like noise simulating metal ball bearing raceway friction
            let whiteL = Float.random(in: -1.0...1.0)
            let whiteR = Float.random(in: -1.0...1.0)
            filterStateL = 0.88 * filterStateL + 0.12 * whiteL
            filterStateR = 0.88 * filterStateR + 0.12 * whiteR
            let frictionNoiseL = filterStateL * 0.35
            let frictionNoiseR = filterStateR * 0.35
            
            // Mechanical resonant humming (fundamental ~90Hz and steel ball harmonics)
            let hum1 = Float(sin(2.0 * Double.pi * 92.0 * t)) * 0.18
            let hum2 = Float(sin(2.0 * Double.pi * 184.0 * t)) * 0.12
            let hum3 = Float(sin(2.0 * Double.pi * 368.0 * t)) * 0.06
            let mechanicalWhir = hum1 + hum2 + hum3
            
            // Subtle cyclic ball passage flutter (~18 Hz)
            let flutter = 0.75 + 0.25 * Float(sin(2.0 * Double.pi * 18.5 * t))
            
            var sampleL = (frictionNoiseL + mechanicalWhir) * flutter
            var sampleR = (frictionNoiseR + mechanicalWhir) * flutter
            
            // Smooth crossfade over 2000 samples at ends for zero click on loop
            let crossFadeLength = 2000
            if i < crossFadeLength {
                let fade = Float(i) / Float(crossFadeLength)
                sampleL *= fade
                sampleR *= fade
            } else if i > Int(frameCount) - crossFadeLength {
                let fade = Float(Int(frameCount) - i) / Float(crossFadeLength)
                sampleL *= fade
                sampleR *= fade
            }
            
            left[i] = sampleL * 0.40
            right[i] = sampleR * 0.40
        }
        self.bearingLoopBuffer = loopBuffer
    }
    
    private func setupAudioGraph() {
        engine.attach(playerNode)
        engine.attach(timePitchUnit)
        
        guard let format = bearingLoopBuffer?.format else { return }
        
        engine.connect(playerNode, to: timePitchUnit, format: format)
        engine.connect(timePitchUnit, to: engine.mainMixerNode, format: format)
        
        timePitchUnit.pitch = 0.0
        timePitchUnit.rate = 1.0
        playerNode.volume = 0.0
        
        startEngineIfNeeded()
    }
    
    private func startEngineIfNeeded() {
        guard !isEngineRunning else { return }
        do {
            try engine.start()
            isEngineRunning = true
        } catch {
            AppLogger.general.warning("AVAudioEngine start error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Dynamic Telemetry Updates
    
    func updateBearingSound(angularVelocity: Float) {
        guard !isMuted else { return }
        let rpm = abs(VectorMath.radPerSecToRPM(angularVelocity))
        if rpm < 5.0 {
            targetRPM = 0.0
            currentRPM = 0.0
            silenceEngine()
        } else {
            targetRPM = rpm
            startSmoothingTimerIfNeeded()
        }
    }
    
    /// Contact click feedback removed per user request (haptic touch feedback is preserved).
    func playContactSound() {
        // Intentionally no-op to eliminate artificial click/tap noise
    }
    
    // MARK: - Periodic Smoothing Loop (Active only during audible rotation)
    
    private func startSmoothingTimerIfNeeded() {
        guard smoothingTimer == nil, !isMuted else { return }
        smoothingTimer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.applySmoothedParameters()
            }
        }
    }
    
    private func stopSmoothingTimer() {
        smoothingTimer?.invalidate()
        smoothingTimer = nil
    }
    
    private func applySmoothedParameters() {
        guard !isMuted else {
            silenceEngine()
            return
        }
        
        // Exponential moving average for smooth transitions without zipper clicks
        let alpha: Float = 0.18
        currentRPM = currentRPM + alpha * (targetRPM - currentRPM)
        
        if currentRPM < 15.0 {
            // Below audible threshold: smoothly ramp to silence
            currentGain = max(0.0, currentGain - 0.08)
            playerNode.volume = currentGain * volume
            if currentGain <= 0.001 {
                if isLoopPlaying {
                    playerNode.pause()
                    isLoopPlaying = false
                }
                if targetRPM < 15.0 {
                    stopSmoothingTimer()
                }
            }
            return
        }
        
        startEngineIfNeeded()
        
        if !isLoopPlaying, let buffer = bearingLoopBuffer {
            playerNode.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
            playerNode.play()
            isLoopPlaying = true
        }
        
        // Map RPM to physical acoustics:
        // Expanded RPM range: 15 to 3,000 RPM (Supercharged Turbo Bearing Acoustics)
        let normRPM = min(1.0, max(0.0, (currentRPM - 15.0) / 2985.0))
        
        // Target gain: expands dynamically with speed
        let targetGain = 0.15 + 0.85 * sqrt(normRPM)
        currentGain = currentGain + alpha * (targetGain - currentGain)
        playerNode.volume = currentGain * volume
        
        // Target pitch: deep mechanical rumble (-800 cents) at 50 RPM climbing to sharp supersonic ceramic whir (+1800 cents) at 3,000 RPM
        let targetPitchCents = -800.0 + (2600.0 * normRPM)
        currentPitchCents = currentPitchCents + alpha * (targetPitchCents - currentPitchCents)
        timePitchUnit.pitch = currentPitchCents
        
        // Target playback rate: 0.65x at low speeds to 2.5x at top speed (3,000 RPM)
        let targetRate = 0.65 + (1.85 * normRPM)
        currentPlaybackRate = currentPlaybackRate + alpha * (targetRate - currentPlaybackRate)
        timePitchUnit.rate = currentPlaybackRate
    }
    
    // MARK: - Control Actions
    
    private func silenceEngine() {
        targetRPM = 0.0
        currentRPM = 0.0
        currentGain = 0.0
        playerNode.volume = 0.0
        if isLoopPlaying {
            playerNode.pause()
            isLoopPlaying = false
        }
        stopSmoothingTimer()
    }
    
    func pause() {
        silenceEngine()
        if engine.isRunning {
            engine.pause()
            isEngineRunning = false
        }
    }
    
    func resume() {
        startEngineIfNeeded()
    }
    
    func stop() {
        silenceEngine()
    }
}
