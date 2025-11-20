//
//  AudioRecorderService.swift
//

import Foundation
import AVFoundation
import SwiftUI
import Combine

@MainActor
final class AudioRecorderService: NSObject, ObservableObject {

    // MARK: - Published States
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var recordedAudioURL: URL?
    @Published var recordingTime: TimeInterval = 0
    @Published var playbackProgress: Double = 0
    @Published var errorMessage: String?
    @Published var recordingDurationString: String = "00:00"

    // MARK: - Internals
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?

    private var recordingTimer: Timer?
    private var playbackTimer: Timer?

    private let session = AVAudioSession.sharedInstance()
    private var isActive = true

    // MARK: - Init / Deinit
    override init() {
        super.init()
        setupSession()
    }

    deinit {
        isActive = false
        
        // ✅ KORREKT: Direkte Cleanup ohne Actor-Isolation
        recordingTimer?.invalidate()
        playbackTimer?.invalidate()
        
        audioRecorder?.stop()
        audioPlayer?.stop()
        
        audioRecorder?.delegate = nil
        audioPlayer?.delegate = nil
        
        try? session.setActive(false)
        
        print("🔇 AudioService deinitialized")
    }

    // MARK: - Async Cleanup (für normale Verwendung)
    func cleanup() {
        // Timer stoppen
        recordingTimer?.invalidate()
        playbackTimer?.invalidate()
        recordingTimer = nil
        playbackTimer = nil

        // Audio Operationen stoppen
        audioRecorder?.stop()
        audioPlayer?.stop()

        // Delegates auf nil setzen
        audioRecorder?.delegate = nil
        audioPlayer?.delegate = nil

        // Audio Session zurücksetzen
        try? session.setActive(false)
        
        // UI States zurücksetzen
        isRecording = false
        isPlaying = false
        playbackProgress = 0
        recordingTime = 0
        recordingDurationString = "00:00"
        errorMessage = nil
    }

    // MARK: - Session Setup
    private func setupSession() {
        guard isActive else { return }
        
        do {
            #if targetEnvironment(simulator)
                try session.setCategory(.playAndRecord, mode: .default)
            #else
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            #endif
            try session.setActive(true)
        } catch {
            print("❌ Audio Session Setup failed: \(error)")
        }
    }

    // MARK: - Permission
    func requestPermission() async -> Bool {
        await withCheckedContinuation { cont in
            session.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
    }

    // MARK: - Start Recording
    func startRecording() async {
        cleanup()

        guard await requestPermission() else {
            errorMessage = "Mikrofon-Berechtigung verweigert."
            return
        }

        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            errorMessage = "Audio Session konnte nicht aktiviert werden."
            return
        }

        let filename = getDocumentsDirectory().appendingPathComponent("voice-\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: filename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()

            guard audioRecorder?.record() == true else {
                errorMessage = "Aufnahme konnte nicht gestartet werden."
                return
            }

            recordedAudioURL = filename
            isRecording = true
            recordingTime = 0
            recordingDurationString = "00:00"
            errorMessage = nil

            startRecordingTimer()

        } catch {
            errorMessage = "Recorder Fehler: \(error.localizedDescription)"
        }
    }

    // MARK: - Stop Recording
    func stopRecording() {
        audioRecorder?.stop()
        stopRecordingTimer()

        isRecording = false
        recordingDurationString = formatTime(recordingTime)
    }

    // MARK: - Play Existing Audio (file URL)
    func playAudioFromURL(_ url: URL) async {
        cleanupPlayback()

        do {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 10.0
            let urlSession = URLSession(configuration: config)
            
            let (data, response) = try await urlSession.data(from: url)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw NSError(domain: "Download", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
            }

            guard !data.isEmpty else {
                throw NSError(domain: "Download", code: 2, userInfo: [NSLocalizedDescriptionKey: "Empty audio data"])
            }

            let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("audio-\(UUID().uuidString).m4a")
            try data.write(to: tempFile)

            playLocalFile(tempFile)

        } catch {
            errorMessage = "Audio Download fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    // MARK: - Play local file
    private func playLocalFile(_ url: URL) {
        cleanupPlayback()

        do {
            try session.setCategory(.playback, mode: .default)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            isPlaying = true
            playbackProgress = 0
            errorMessage = nil

            startPlaybackTimer()
        } catch {
            errorMessage = "Audio konnte nicht abgespielt werden: \(error.localizedDescription)"
        }
    }

    // MARK: - Stop Playback
    func stopPlayback() {
        audioPlayer?.stop()
        stopPlaybackTimer()
        isPlaying = false
        playbackProgress = 0
    }

    private func cleanupPlayback() {
        stopPlaybackTimer()
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        playbackProgress = 0
    }

    // MARK: - Timer Handling
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.recordingTime += 0.1
            self.recordingDurationString = self.formatTime(self.recordingTime)
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let player = self.audioPlayer else { return }
            self.playbackProgress = player.duration > 0 ? (player.currentTime / player.duration) : 0
        }
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    // MARK: - Audio Level Monitoring
    func getCurrentAudioLevel() -> Float {
        guard isRecording else { return -160.0 }
        
        audioRecorder?.updateMeters()
        let level = audioRecorder?.averagePower(forChannel: 0) ?? -160.0
        
        let minLevel: Float = -60.0
        let maxLevel: Float = 0.0
        
        if level < minLevel {
            return 0.0
        } else if level > maxLevel {
            return 1.0
        } else {
            return (level - minLevel) / (maxLevel - minLevel)
        }
    }

    // MARK: - File Utilities
    func getAudioFileSize() -> Int? {
        guard let url = recordedAudioURL else { return nil }
        
        do {
            let resources = try url.resourceValues(forKeys: [.fileSizeKey])
            return resources.fileSize
        } catch {
            return nil
        }
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let min = Int(time) / 60
        let sec = Int(time) % 60
        return String(format: "%02d:%02d", min, sec)
    }
}

// MARK: - Delegates
extension AudioRecorderService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        stopRecordingTimer()
        isRecording = false
        
        if !flag {
            errorMessage = "Aufnahme wurde unerwartet beendet"
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        stopRecordingTimer()
        isRecording = false
        errorMessage = "Aufnahme-Fehler: \(error?.localizedDescription ?? "Unbekannt")"
    }
}

extension AudioRecorderService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopPlayback()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        stopPlayback()
        errorMessage = "Wiedergabe-Fehler: \(error?.localizedDescription ?? "Unbekannt")"
    }
}
