import Combine
import Foundation

@MainActor
final class MacAgentModel: ObservableObject {
    static let shared = MacAgentModel()

    enum Phase { case idle, listening, processing, paused, answering }
    @Published var phase: Phase = .idle
    @Published var transcript = ""
    @Published var answer = ""
    @Published var errorMessage: String?

    private let speech = SpeechCapture()
    private let ollama = OllamaClient()
    private var hotkeyDown = false
    private var turnTask: Task<Void, Never>?

    func beginHotkey() {
        guard !hotkeyDown else { return }
        hotkeyDown = true
        errorMessage = nil
        answer = ""
        transcript = ""
        phase = .listening
        Task {
            do {
                try await speech.start()
                // The user may release the hotkey while permission dialogs are open.
                if !hotkeyDown {
                    let lateTranscript = await speech.stop()
                    await submit(lateTranscript)
                    return
                }
                while hotkeyDown && speech.isRecording {
                    transcript = speech.transcript
                    try? await Task.sleep(for: .milliseconds(100))
                }
            } catch {
                errorMessage = error.localizedDescription
                phase = .idle
            }
        }
    }

    func endHotkey() {
        guard !hotkeyDown else { return }
        hotkeyDown = false
        Task {
            let finalPrompt = await speech.stop()
            await submit(finalPrompt)
        }
    }

    private func submit(_ rawPrompt: String) {
        let finalPrompt = rawPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        transcript = finalPrompt
        guard !finalPrompt.isEmpty else { phase = .idle; return }
        phase = .processing
        turnTask?.cancel()
        turnTask = Task { await run(prompt: finalPrompt) }
    }

    private func run(prompt: String) async {
        do {
            try await ollama.respond(to: prompt, onText: { [weak self] fragment in
                guard let self else { return }
                self.answer += fragment
                self.phase = .answering
            }, onApproval: { [weak self] description in
                guard let self else { throw TaskStoreError.signedOut }
                self.phase = .paused
                self.answer = "Waiting for phone approval…"
                let taskID = try await FirestoreTaskStore.shared.createApprovalTask(actionDescription: description)
                let status = try await FirestoreTaskStore.shared.waitForResolution(taskID: taskID)
                return status == .approved
            })
            phase = .answering
        } catch {
            errorMessage = error.localizedDescription
            answer = error.localizedDescription
            phase = .answering
        }
    }
}
