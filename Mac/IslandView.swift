import SwiftUI

struct IslandView: View {
    @EnvironmentObject private var model: MacAgentModel

    private var expanded: Bool { model.phase != .idle }
    private var avatarMood: AvatarMood {
        switch model.phase {
        case .idle: return .idle
        case .listening: return .listening
        case .processing: return .thinking
        case .paused: return .waiting
        case .answering: return .answering
        }
    }
    private var label: String {
        switch model.phase {
        case .idle: return "Ready"
        case .listening: return "Listening"
        case .processing: return "Thinking locally"
        case .paused: return "Approval required"
        case .answering: return "Island Agent"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                DotBuddyAvatar(mood: avatarMood)
                    .frame(width: 32, height: 32)
                    .scaleEffect(model.phase == .listening ? 1.08 : 1)
                    .animation(.spring(response: 0.32, dampingFraction: 0.62), value: model.phase == .listening)
                Text(label).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                Spacer(minLength: 0)
                if model.phase == .listening { Circle().fill(.red).frame(width: 7, height: 7) }
            }

            if expanded {
                if !model.transcript.isEmpty {
                    Text(model.transcript).font(.system(size: 11)).foregroundStyle(.white.opacity(0.62)).lineLimit(2)
                }
                if !model.answer.isEmpty {
                    Text(model.answer).font(.system(size: 12)).foregroundStyle(.white).lineLimit(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if model.phase == .paused {
                    Text("Review and approve this action on your iPhone.")
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.75))
                } else if model.phase == .processing {
                    Text("Ollama is running locally on this Mac…")
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.75))
                } else if model.phase == .listening {
                    Text("I’m listening. Let go of ⌥ + ⌘ when you’re done.")
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.75))
                }
                if let error = model.errorMessage {
                    Text(error).font(.system(size: 10)).foregroundStyle(.red).lineLimit(2)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .frame(width: expanded ? 380 : 154, height: expanded ? 158 : 48, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: expanded ? 30 : 24, style: .continuous)
                .fill(.black)
                .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        }
        .frame(width: 430, height: 200, alignment: .top)
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: expanded)
    }
}
