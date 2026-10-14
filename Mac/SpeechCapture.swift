import AVFoundation
import Combine
import Foundation
import Speech

@MainActor
final class SpeechCapture: ObservableObject {
    @Published private(set) var transcript = ""
    @Published private(set) var isRecording = false

    private let engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var stopContinuation: CheckedContinuation<String, Never>?

    func start() async throws {
        guard !isRecording else { return }
        guard let recognizer, recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            throw SpeechError.onDeviceUnavailable
        }

        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else { throw SpeechError.speechDenied }
        let micGranted = await requestMicrophonePermission()
        guard micGranted else { throw SpeechError.microphoneDenied }

        transcript = ""
        let newRequest = SFSpeechAudioBufferRecognitionRequest()
        newRequest.shouldReportPartialResults = true
        newRequest.requiresOnDeviceRecognition = true
        request = newRequest

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak newRequest] buffer, _ in
            newRequest?.append(buffer)
        }
        engine.prepare()
        try engine.start()
        isRecording = true

        task = recognizer.recognitionTask(with: newRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal { self.finishStopping(with: self.transcript) }
                }
                if error != nil { self.finishStopping(with: self.transcript) }
            }
        }
    }

    func stop() async -> String {
        guard isRecording else { return transcript }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        request?.endAudio()
        return await withCheckedContinuation { continuation in
            stopContinuation = continuation
            task?.finish()
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(2))
                guard let self else { return }
                self.finishStopping(with: self.transcript)
            }
        }
    }

    private func finishStopping(with finalText: String) {
        guard let continuation = stopContinuation else {
            if task != nil && !isRecording {
                task?.cancel()
                task = nil
                request = nil
            }
            return
        }
        stopContinuation = nil
        transcript = finalText
        isRecording = false
        task?.cancel()
        task = nil
        request = nil
        continuation.resume(returning: finalText)
    }

    private func requestMicrophonePermission() async -> Bool {
        if #available(macOS 14.0, *) {
            return await AVCaptureDevice.requestAccess(for: .audio)
        }
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { continuation.resume(returning: $0) }
        }
    }
}

private enum SpeechError: LocalizedError {
    case onDeviceUnavailable, speechDenied, microphoneDenied
    var errorDescription: String? {
        switch self {
        case .onDeviceUnavailable: return "On-device English speech recognition is unavailable on this Mac."
        case .speechDenied: return "Allow Speech Recognition in System Settings."
        case .microphoneDenied: return "Allow microphone access in System Settings."
        }
    }
}
