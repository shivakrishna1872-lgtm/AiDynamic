import SwiftUI

struct MacControlView: View {
    @StateObject private var auth = AuthSession.shared
    @StateObject private var agent = MacAgentModel.shared

    var body: some View {
        Group {
            if auth.uid == nil {
                AuthenticationView(session: auth)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Island Agent", systemImage: "sparkles")
                        .font(.title2.bold())
                    Text("Hold ⌥ + ⌘, speak, then release to send your prompt to local Ollama.")
                    Text("Install a tool-capable model: ollama pull llama3.1")
                        .font(.callout.monospaced()).foregroundStyle(.secondary)
                    Text("Actions are limited to notes in this app’s private Notes folder and always require phone approval.")
                        .foregroundStyle(.secondary)
                    if let message = agent.errorMessage {
                        Text(message).font(.callout).foregroundStyle(.red)
                    }
                    Button("Sign Out", role: .destructive) {
                        do { try auth.signOut() }
                        catch { auth.errorMessage = error.localizedDescription }
                    }
                }
                .padding(24)
            }
        }
        .frame(minWidth: 380, minHeight: 230)
        .task { auth.start() }
    }
}
