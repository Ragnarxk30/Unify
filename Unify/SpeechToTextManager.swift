import Foundation
import Speech
import AVFoundation
import Combine

final class SpeechToTextManager: ObservableObject {
    @Published var recognizedText = ""
    @Published var isRecording = false
    @Published var hasPermission = false
    @Published var errorMessage: String?
    @Published var permissionsChecked = false
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    init() {
        // Speech Recognizer erstellen
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
        
        // Berechtigungen asynchron prüfen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.checkPermissions()
        }
    }
    
    // MARK: - Berechtigungen prüfen
    private func checkPermissions() {
        guard SFSpeechRecognizer.authorizationStatus() != .notDetermined else {
            // Berechtigungen anfordern
            requestPermissions()
            return
        }
        
        updatePermissionStatus()
    }
    
    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch authStatus {
                case .authorized:
                    // Mikrofon-Berechtigung prüfen
                    AVAudioSession.sharedInstance().requestRecordPermission { microphoneAllowed in
                        DispatchQueue.main.async {
                            self.hasPermission = microphoneAllowed
                            self.permissionsChecked = true
                            if !microphoneAllowed {
                                self.errorMessage = "Mikrofon-Zugriff wurde verweigert. Bitte erlaube Mikrofon-Zugriff in den Einstellungen."
                            }
                        }
                    }
                    
                case .denied:
                    self.hasPermission = false
                    self.permissionsChecked = true
                    self.errorMessage = "Spracherkennung wurde verweigert. Bitte erlaube Spracherkennung in den Einstellungen."
                    
                case .restricted:
                    self.hasPermission = false
                    self.permissionsChecked = true
                    self.errorMessage = "Spracherkennung ist auf diesem Gerät eingeschränkt."
                    
                case .notDetermined:
                    self.hasPermission = false
                    self.permissionsChecked = true
                    
                @unknown default:
                    self.hasPermission = false
                    self.permissionsChecked = true
                }
            }
        }
    }
    
    private func updatePermissionStatus() {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let isSpeechAuthorized = speechStatus == .authorized
        
        // Prüfe Mikrofon-Berechtigung
        AVAudioSession.sharedInstance().requestRecordPermission { microphoneAllowed in
            DispatchQueue.main.async {
                self.hasPermission = isSpeechAuthorized && microphoneAllowed
                self.permissionsChecked = true
                
                if !self.hasPermission {
                    if !isSpeechAuthorized {
                        self.errorMessage = "Spracherkennung nicht berechtigt"
                    } else if !microphoneAllowed {
                        self.errorMessage = "Mikrofon nicht berechtigt"
                    }
                }
            }
        }
    }
    
    // MARK: - Aufnahme starten
    func startRecording() {
        guard hasPermission else {
            errorMessage = "Berechtigungen für Spracherkennung fehlen"
            return
        }
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "Spracherkennung nicht verfügbar"
            return
        }
        
        // Sicherstellen dass keine Aufnahme läuft
        stopRecording()
        
        // Recognized Text zurücksetzen
        recognizedText = ""
        
        do {
            // Audio Session konfigurieren
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Recognition Request erstellen
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                errorMessage = "Spracherkennungs-Request konnte nicht erstellt werden"
                return
            }
            
            recognitionRequest.shouldReportPartialResults = true
            
            // Recognition Task starten
            recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                DispatchQueue.main.async {
                    if let result = result {
                        self?.recognizedText = result.bestTranscription.formattedString
                    }
                    
                    if let error = error {
                        print("Spracherkennungs-Fehler: \(error.localizedDescription)")
                        self?.stopRecording()
                    } else if result?.isFinal == true {
                        self?.stopRecording()
                    }
                }
            }
            
            // Audio Input konfigurieren
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, when in
                recognitionRequest.append(buffer)
            }
            
            // Audio Engine starten
            audioEngine.prepare()
            try audioEngine.start()
            
            isRecording = true
            errorMessage = nil
            
        } catch {
            errorMessage = "Fehler beim Starten der Spracherkennung: \(error.localizedDescription)"
            stopRecording()
        }
    }
    
    // MARK: - Aufnahme stoppen
    func stopRecording() {
        // Audio Engine stoppen
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // Recognition beenden
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Audio Session zurücksetzen
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Fehler beim Zurücksetzen der Audio Session: \(error)")
        }
        
        isRecording = false
    }
    
    // MARK: - Text übernehmen
    func commitText() -> String {
        let text = recognizedText
        recognizedText = ""
        return text
    }
    
    deinit {
        stopRecording()
    }
}
