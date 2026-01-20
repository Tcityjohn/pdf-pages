import Foundation
import Speech
import AVFoundation
import Flutter

/// Handles speech recognition using iOS Speech framework
/// Communicates with Flutter via MethodChannel
class SpeechRecognitionHandler: NSObject {
    private let channel: FlutterMethodChannel

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "com.pdfpages.speech", binaryMessenger: messenger)
        super.init()

        channel.setMethodCallHandler { [weak self] (call, result) in
            self?.handleMethodCall(call, result: result)
        }
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestPermission":
            requestPermission(result: result)
        case "isAvailable":
            checkAvailability(result: result)
        case "startListening":
            startListening(result: result)
        case "stopListening":
            stopListening(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func requestPermission(result: @escaping FlutterResult) {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    // Also request microphone permission
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        DispatchQueue.main.async {
                            result(granted)
                        }
                    }
                case .denied, .restricted, .notDetermined:
                    result(false)
                @unknown default:
                    result(false)
                }
            }
        }
    }

    private func checkAvailability(result: @escaping FlutterResult) {
        let isAvailable = speechRecognizer?.isAvailable ?? false
        result(isAvailable)
    }

    private func startListening(result: @escaping FlutterResult) {
        // Check if already running
        if audioEngine.isRunning {
            result(true)
            return
        }

        // Cancel any previous task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            result(false)
            return
        }

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            result(false)
            return
        }

        // Configure for live transcription
        recognitionRequest.shouldReportPartialResults = true

        // Use on-device recognition if available (iOS 13+)
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = speechRecognizer?.supportsOnDeviceRecognition ?? false
        }

        // Get input node
        let inputNode = audioEngine.inputNode

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] recognitionResult, error in
            guard let self = self else { return }

            if let recognitionResult = recognitionResult {
                let transcription = recognitionResult.bestTranscription.formattedString
                self.channel.invokeMethod("onTranscription", arguments: transcription)
            }

            if error != nil || recognitionResult?.isFinal == true {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)

                self.recognitionRequest = nil
                self.recognitionTask = nil

                self.channel.invokeMethod("onStateChange", arguments: "idle")
            }
        }

        // Configure audio input
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            channel.invokeMethod("onStateChange", arguments: "listening")
            result(true)
        } catch {
            channel.invokeMethod("onError", arguments: error.localizedDescription)
            result(false)
        }
    }

    private func stopListening(result: @escaping FlutterResult) {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
        }

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        channel.invokeMethod("onStateChange", arguments: "idle")
        result(nil)
    }
}
